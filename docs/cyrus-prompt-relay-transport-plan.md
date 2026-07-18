# Implementation plan: prompt-relay transport

Executes `docs/cyrus-prompt-relay-transport-design.md` (the design doc — authoritative spec; every task below references it as "the design doc"). Seven sequential tasks, each independently committable. Written 2026-07-18.

## Global Constraints

These bind every task. Copy verbatim into reviews.

1. **Vocabulary:** the transport is named `prompt-relay` everywhere in `skills/` (including `autonomous-contract.md`). The word "Cyrus" must NOT appear in any file under `skills/` — it is allowed only in `README.md`, files under `docs/`, and `CHANGELOG.md`. (A pointer to the path `docs/cyrus-deployment.md` from a skill file is allowed — that's a filename, not product coupling.)
2. **No new config keys.** Detection is content-presence (constraint 3). `docs/ccmagic.local.md.example` is not modified.
3. **Detection rule (exact, define once in contract §7, reference elsewhere):** transport = `prompt-relay` when ALL of: (a) the tracker resolves to `linear`; (b) no `mcp__*Linear*__*` tool is present in the session; (c) ticket content (title + description) was explicitly provided in the invocation arguments or grounding block. Otherwise transport = `mcp` and behavior is unchanged. The check runs *before* any "none available → stop" branch.
4. **Grounding block extension (exact):** a `transport: {mcp | prompt-relay}` line; and, under prompt-relay only, the ticket content appended to the block as:

   ```
   ticket_content:
   ~~~
   {title}

   {description}
   ~~~
   ```

   Tilde fencing is deliberate — issue bodies may contain backtick fences.
5. **Op semantics under prompt-relay (from design §4.3):** `fetch_ticket` reads from args/grounding, absent → setup error, stop (never guess, never park). `set_state(In Progress)` → no-op (harness already did it). `set_state(In Review | Done | needs_human)` → no-op + an intent line `Requested state: {X}` carried into the final message; never a failure or park trigger. `comment(ticket, …)` → **skip** (no accumulation machinery; the PR carries the detailed audit trail via `gh`; the orchestrator's single Step 6 summary is the only Linear-facing message). `link_pr` → PR URL in the final summary (Linear's GitHub integration auto-links via the issue-id branch name anyway). `file_followup` → no API; record as short descriptions in `follow_ups:` and list under "Follow-ups to file" in the final summary.
6. **Final-message contract:** under prompt-relay the orchestrator's Step 6 summary (or parked note) is emitted as its own final top-level output, ending with a delimited block opened by the exact line `=== FINAL MESSAGE TO RELAY (reproduce verbatim) ===` and closed by `=== END FINAL MESSAGE ===`.
7. **Additive only.** With a Linear MCP present (or any other tracker), every skill behaves byte-for-byte as today. GitHub/JIRA paths and all `gh` PR/merge/CI behavior are untouched.
8. **House style:** match each SKILL.md's existing voice and structure; keep every SKILL.md under 500 lines; commit messages follow `{TYPE}({scope}): {description}` (imperative, ≤72 chars, no ticket ID — this repo doesn't use one).
9. **Verification (the "tests" for these markdown changes):** each task runs the structural greps named in its brief and reports the command + output as evidence. At minimum every task touching `skills/`: `grep -ri cyrus skills/` must return nothing except (allowed) `docs/cyrus-deployment.md` path references, and `wc -l` on each touched SKILL.md must be ≤ 500.

## Task 1: Contract — grounding schema, park fallback, §7 prompt-relay ops

**File:** `skills/auto-ticket/autonomous-contract.md` (currently 129 lines). Read it fully first; read the design doc §2, §4.

1. **§2 (grounding block):** add `transport: {mcp | prompt-relay}` to the fenced block (after the `tracker:` line). After the fence, add a short paragraph: under prompt-relay the block also carries the ticket content per Global Constraint 4 (show the exact `ticket_content:` form with `~~~` fencing and state why tildes). Note that sub-skills in prompt-relay read the ticket from this block instead of MCP.
2. **§4 (route-and-stop):** extend with a prompt-relay variant — step 2 (the Linear state move) is **skipped** (no API; the harness/human owns state; never a failure); the parked-comment template still goes to the PR via `gh pr comment`, and is additionally emitted as the orchestrator's final top-level output per the §7 final-message contract, so the relay delivers it to the tracker. Add `Requested state: {needs_human_state}` as an intent line in that output.
3. **New §7 "Prompt-relay transport"** (before §6 renumbering is NOT wanted — append after §6 and keep the existing §6 "Invariants" numbering as-is; the new section is `## 7. Prompt-relay transport`): define (a) what the transport is (headless harness injects the ticket into the prompt and relays the session's output back to the tracker as a comment — no tracker MCP in the environment); (b) the detection rule verbatim (Global Constraint 3); (c) an ops table with the exact semantics of Global Constraint 5; (d) the final-message contract verbatim (Global Constraint 6) including the note that the harness may paraphrase — the delimited block plus the deployment-side "repeat verbatim" instruction are the mitigation; (e) one line: this transport adds no config keys and changes nothing when an MCP is present.
4. **Verification:** `grep -n "transport" skills/auto-ticket/autonomous-contract.md` shows §2 + §7 anchors; `grep -ri cyrus skills/` clean; file stays coherent when read end-to-end.

**Commit:** `feat(auto-ticket): add prompt-relay transport contract (§7, grounding, park)`

## Task 2: auto-ticket orchestrator — detection, grounding, Step 6 relay, stale note

**File:** `skills/auto-ticket/SKILL.md` (currently 223 lines). Read it fully first; read the design doc §4.1–§4.5 and contract §7 (as amended by Task 1).

1. **Step 0.1 (tracker cascade):** after the cascade sentence, add transport resolution: default `transport: mcp`; apply the contract §7 detection rule (reference it — do not restate the full rule) *before* the "if none is available, stop" branch, so a prompt-relay run resolves `tracker: linear`, `transport: prompt-relay` instead of stopping.
2. **Step 0.4 (fetch):** add: under prompt-relay there is no MCP fetch — confirm the ticket content is present in the invocation arguments; if absent, stop with a setup-error message (per contract §7 `fetch_ticket`; this is the Sacred Rule — the caller should have injected it).
3. **Step 0.5 (grounding block):** note the block now carries `transport:` and, under prompt-relay, the `ticket_content:` section (contract §2), so every per-step agent receives the content.
4. **Step 6:** add a prompt-relay branch: do **not** attempt a ticket comment. Merged → still post the summary as a PR comment via `gh`, then emit the summary as this skill's own final top-level output ending with the delimited final-message block (contract §7), including intent line `Requested state: Done` and any "Follow-ups to file" list. Parked → route-and-stop already produces the parked note; emit it the same way (single top-level final message). One sentence on *why*: only the top-level output is relayed to the tracker; per-step subagent output stays internal.
5. **Error handling table:** add row — "Prompt-relay: ticket content missing from invocation | Stop and say so (setup error, not a parkable ticket)."
6. **Notes → the stale Cyrus/headless note (currently at :222):** replace with accurate text: headless harnesses that inject the ticket and relay output (no tracker MCP in the environment) are supported via the prompt-relay transport (contract §7); deployment prerequisites and the required prompt template live in `docs/cyrus-deployment.md`. Do not use the word "Cyrus" outside that path reference.
7. **Verification:** `grep -n "prompt-relay" skills/auto-ticket/SKILL.md` hits Steps 0/6, error table, Notes; `grep -rin cyrus skills/` shows only the `docs/cyrus-deployment.md` path reference; `wc -l` ≤ 500.

**Commit:** `feat(auto-ticket): resolve prompt-relay transport and relay final summary`

## Task 3: work-ticket — detection, fetch-from-grounding, skip assign, In-Review intent

**File:** `skills/work-ticket/SKILL.md` (currently 344 lines). Read it fully first; read contract §7 (as amended by Task 1).

1. **Step 0b (cascade, items 1–6):** insert a new item before "None available: stop": if the contract §7 detection rule matches (reference it), resolve `tracker: linear` with `transport: prompt-relay` — do not stop. Update the "Record the resolved tracker" line (:45) to also record the transport.
2. **Step 1 → ### Linear:** add: under prompt-relay, read `title`/`description` (and state if present) from the grounding block's `ticket_content:` — no MCP call. If the section is absent → stop with the setup-error message (contract §7 `fetch_ticket`); the existing "If not found" stop text stays for the MCP path.
3. **Step 2:** add one line: under prompt-relay, skip this step entirely — the harness already assigned the ticket and moved it to In Progress on assignment.
4. **Step 8 (:246–252):** add a prompt-relay branch to the Linear section: no attachment/comment API — record the intent line `Requested state: In Review` (surfaced through the handshake/summary; the PR URL travels in the run summary, and the tracker's GitHub integration auto-links the PR via the branch name). Never a failure; the existing "If this step fails" warning applies only to the MCP path.
5. **Autonomous mode / handshake:** one clarifying line where `done` is defined (:319): under prompt-relay, "moved to In Review" means the intent line was emitted (the harness owns the actual move).
6. **Error table (:333):** amend the "No tracker available" row: unless the prompt-relay detection rule matched (contract §7).
7. **Verification:** `grep -n "prompt-relay" skills/work-ticket/SKILL.md` hits Steps 0b/1/2/8, autonomous section, error table; `grep -ri cyrus skills/` clean; `wc -l` ≤ 500.

**Commit:** `feat(work-ticket): prompt-relay transport branches`

## Task 4: review-ticket + finish-ticket — fetch-from-grounding, state intents, comment skip

**Files:** `skills/review-ticket/SKILL.md` (245 lines), `skills/finish-ticket/SKILL.md` (418 lines). Read both fully first; read contract §7.

review-ticket:
1. **Step 0 (cascade, :28–33):** same insertion as work-ticket Task 3.1 (detection rule before the "none found → stop").
2. **Step 1 → ### Linear (:48–50):** under prompt-relay, take `title`/`description` from the grounding block's `ticket_content:`; parse acceptance criteria out of that text exactly as for an MCP fetch (bullets, checkboxes, "Acceptance Criteria" headers). Absent → setup-error stop. Note: ticket *comments* are not available under prompt-relay — the AC sources are title + description only.
3. **Error table (:238):** same "unless prompt-relay matched" amendment.

finish-ticket:
4. **Step 0b (:36–45):** same detection insertion; record transport.
5. **Step 2 → ### Linear (:87–89):** under prompt-relay, ticket fields come from the grounding block; there is no team-state list to fetch — state targets are relay intents, so skip state-name matching (note this here, referenced by Step 7).
6. **Step 7 → ### Linear (:310–314):** under prompt-relay: do not post the closing comment to the ticket (contract §7 `comment` — the orchestrator's single summary carries it) and do not transition state; instead ensure the closing summary content and the intent line `Requested state: Done` are in this skill's final output/handshake so the orchestrator's Step 6 message includes them. **Merging via `gh` is unchanged** — say so explicitly.
7. **Handshake (:389):** one line: under prompt-relay, `done` = merged + Done-intent emitted (the harness/tracker automation owns the actual move).
8. **Error table (:405):** same "unless prompt-relay matched" amendment.
9. **Verification:** `grep -n "prompt-relay"` in both files hits every listed site; `grep -ri cyrus skills/` clean; both `wc -l` ≤ 500 (finish-ticket has ~80 lines of headroom — keep additions tight).

**Commit:** `feat(tracker): prompt-relay branches for review-ticket and finish-ticket`

## Task 5: pr-feedback + doctor — follow-up collection, transport awareness

**Files:** `skills/pr-feedback/SKILL.md` (273 lines), `skills/doctor/SKILL.md` (155 lines). Read both fully first; read contract §7.

pr-feedback:
1. **Autonomous mode → "Tracker for follow-ups" (:232) and the defer/out-of-scope rule (:240):** under prompt-relay there is no ticket-creation API. Instead of filing, record each deferred/out-of-scope item as a short description in `follow_ups:` (the contract §3 handshake already allows "ticket ids **or short descriptions**"), and say in the thread reply that a follow-up was requested for a human to file. The orchestrator lists these under "Follow-ups to file" in its final summary.
2. **Verification:** `grep -n "prompt-relay" skills/pr-feedback/SKILL.md` hits the follow-up rule.

doctor:
3. **Section 3 (tracker probes, :47–66):** add a short note after the Linear checklist: a missing Linear MCP is not always a defect — headless harness runs use the prompt-relay transport (ticket injected into the prompt, output relayed back; see `skills/auto-ticket/autonomous-contract.md` §7 and `docs/cyrus-deployment.md`). Doctor cannot detect that environment from a laptop; it should mention the transport instead of flatly reporting "Linear unavailable" as broken.
4. **Verification:** `grep -n "prompt-relay" skills/doctor/SKILL.md` hits the note; `grep -ri cyrus skills/` shows only `docs/cyrus-deployment.md` path references; both files ≤ 500 lines.

**Commit:** `feat(tracker): prompt-relay follow-up collection and doctor awareness`

## Task 6: Deployment docs — docs/cyrus-deployment.md + README pointer

**Files:** new `docs/cyrus-deployment.md`; `README.md` (edit). Read the design doc fully first (especially §2, §4.2, §6, §7) and README's "Autonomous mode" section (:153–211) and "Tracker support" (:226).

1. **Create `docs/cyrus-deployment.md`** (~60–90 lines) covering, in this order:
   - What it is: running `/ccmagic:auto-ticket` inside Cyrus (cyrusagents/cyrus) — Linear-triggered, Dockerized, **no Linear MCP in-container**; ccmagic's generic prompt-relay transport (contract §7) carries the Linear side.
   - Prerequisites: (a) Linear's GitHub integration with auto-close automation enabled on the team (moves the issue to Done when the linked PR merges — the agent only ever emits state *intents*); (b) `gh` authenticated in the container (verified on a live instance 2026-07-18: `GH_TOKEN` env); (c) the repo checkout includes ccmagic and any `.claude/ccmagic.local.md` (no prompt-relay-specific keys exist — detection is automatic).
   - **The prompt-template contract (the load-bearing part):** the Cyrus repo prompt must (1) invoke `/ccmagic:auto-ticket {TICKET-ID}` **with the issue title and description included in the message** — content that isn't passed into the skill invocation never reaches it (`context: fork`); (2) instruct the session to reproduce the skill's returned `=== FINAL MESSAGE TO RELAY ===` block **verbatim** as its final message. Provide a copy-pasteable template block.
   - What lands where: PR = detailed near-real-time audit trail (comments, review, CI); Linear = one consolidated final summary (or parked note) with `Requested state:` intent lines and a "Follow-ups to file" list for a human.
   - Parking: state is not moved (no API); the parked note is the unmistakable signal — a human (or Cyrus lifecycle) moves the issue.
   - Testing before trusting it: laptop simulation (`claude -p`, Linear MCP unconfigured, crafted prompt embedding a fake ticket + the invocation) exercises detection/fetch/no-ops/final-message; then one throwaway Linear ticket on the live instance — the open item it verifies is whether the relay delivers the final block verbatim (design §6 R1).
2. **README:** add a short subsection at the end of "Autonomous mode" (after "Per-step subagents and models", before "## Configuration"): `### Headless / prompt-relay (Cyrus)` — 4–6 lines: no tracker MCP needed when a harness injects the ticket and relays output; detection is automatic (no config); one consolidated summary reaches the tracker; link to `docs/cyrus-deployment.md`. Also add one line to "Tracker support" noting Linear works over two transports (MCP, prompt-relay).
3. **Verification:** README renders sanely (heading levels consistent); `grep -n "cyrus-deployment" README.md skills/auto-ticket/SKILL.md skills/doctor/SKILL.md` — all pointers resolve to the new file's actual path.

**Commit:** `docs: Cyrus deployment guide for the prompt-relay transport`

## Task 7: Version bump + changelog + design-doc status

**Files:** `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `CHANGELOG.md`, `docs/cyrus-prompt-relay-transport-design.md` (status line only). Read CHANGELOG's 3.2.0 entry first for format.

1. `plugin.json` and `marketplace.json` (:15): `3.2.0` → `3.3.0`.
2. **CHANGELOG:** new `## [3.3.0] — 2026-07` above 3.2.0. **Added:** prompt-relay transport (one paragraph: headless harnesses e.g. Cyrus; content-presence detection with zero new config; contract §7 ops — fetch-from-grounding, state intents, single consolidated final summary, follow-ups listed for human filing; park without a state move; `docs/cyrus-deployment.md`). **Changed:** grounding block now carries `transport:` and (prompt-relay) `ticket_content:`; corrected the stale auto-ticket note that claimed the cycle worked from Cyrus's container via MCP.
3. **Design doc:** change the Status line to note it is implemented in v3.3.0 (keep the rest).
4. **Verification:** `jq . .claude-plugin/plugin.json .claude-plugin/marketplace.json` parses; `grep -n "3.3.0" .claude-plugin/*.json CHANGELOG.md` shows all three.

**Commit:** `chore: bump to 3.3.0; changelog for prompt-relay transport`
