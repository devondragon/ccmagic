# Design: prompt-relay transport for the headless-Linear (Cyrus) path

**Status:** scoped, reviewed, **decisions locked** — not yet scheduled, no branch, no code. Written 2026-07-18; revised same day after design review + in-container verification on the live Cyrus instance (`server.tr0n.io`, container `cyrus`).
**Trigger:** running `/ccmagic:auto-ticket` (and the lifecycle skills) inside Cyrus, where there is **no Linear MCP** in the container — the ticket flows into the prompt, and the agent's output is relayed back to Linear as activity/comments.

---

## 1. The core reframe: transport, not tracker

ccmagic models one axis today — **which tracker** (Linear / GitHub / JIRA) — and assumes each is reached through a **direct API**: Linear/JIRA via MCP, GitHub via `gh`. Cyrus keeps the tracker (**Linear**) but swaps the **transport**:

| Operation | Normal (today) | Prompt-relay (Cyrus) |
|---|---|---|
| Read ticket | `mcp__*Linear*__get_issue` | injected into the invocation (see §4.2 — it does **not** ride along for free) |
| Branch / worktree | `work-ticket` creates it | Cyrus already created it (worktree per issue, branch from issue id) |
| Initial state → In Progress | `save_issue` | Cyrus already did it on assignment ("started") |
| Write a comment | `save_comment` | the agent's output stream **is** the comment — Cyrus relays activity to Linear |
| State → In Review / Done / needs-human | `save_issue` | **no API** — Cyrus session-lifecycle + Linear's GitHub automation own it |
| PR link on the ticket | attachment via MCP | Linear's GitHub integration auto-links the PR via the issue-id branch name |
| File follow-up ticket | create issue via MCP | **no API** — listed in the final summary for a human |
| PR / git / push / merge / CI | `gh` | **unchanged** — `gh` verified authed in-container (§6) |

**Consequence:** the whole orchestration and the entire GitHub/PR half are unaffected. Only the *Linear side* loses its API — reads come in with the invocation, writes go out as the relayed message. So the fix is a **new transport mode**, branched at ~6 tracker-I/O points, not a new skill (a separate `cyrus-ticket` skill would duplicate orchestration and drift).

**Naming:** the canonical vocabulary is **`prompt-relay`** everywhere — contract section, skill branches, grounding-block field. Cyrus is the motivating deployment and appears only in docs/README as an example. Any future headless harness that pre-injects ticket content (Linear or otherwise) reuses the transport unchanged; nothing product-named lands in the plugin's contract surface.

Refs: [cyrusagents/cyrus](https://github.com/cyrusagents/cyrus), self-hosting write-up ([digitalsanctuary.com](https://www.digitalsanctuary.com/posts/self-hosting-a-linear-driven-claude-code-agent-with-cyrus)).

## 2. Decisions locked

- **Merge policy: full auto-merge.** A Cyrus run drives the entire cycle exactly like laptop `auto-ticket` — merge when CI is green and the work is clean, **park** otherwise. No new merge-gating config; the existing merge/park logic is reused unchanged.
- **State control: Cyrus + Linear own it.** The agent **never** attempts a Linear state transition. Every `set_state` call becomes a no-op that emits an intent line into the relayed output. Ticket → Done on merge is handled by **Linear's GitHub integration automation** (auto-close on linked-PR merge — confirmed enabled on the team); this is a documented deployment prerequisite, not code. "Couldn't move state" is **never** a failure or a park trigger.
- **Detection: content-presence, zero config.** No `environment:`/`tracker_transport:` key, no TTY heuristic. Rule: tracker resolves to `linear` **and** no `mcp__*Linear*__*` tool is present **and** ticket content was explicitly passed in the invocation args/grounding → transport = `prompt-relay`. A laptop run never has injected content, so there are no false positives — a laptop with a briefly-missing MCP has no content and stops exactly as today. This also keeps `.claude/ccmagic.local.md` identical across laptop and container (it's per-repo, checked out in both — an environment key there would have forced prompt-relay onto laptop runs).
- **Writes: relay-only.** No direct Linear API path. Verified in-container (§6): there is **no usable Linear access token in the environment** — only Cyrus's own OAuth client credentials and webhook secret; per-workspace tokens live in Cyrus's internal state. A direct-API path would couple ccmagic to Cyrus internals for marginal gain. The §4.3 operations are op-shaped, so a direct-API implementation could slot in per-op later without restructuring.
- **Progress: single consolidated final message.** Linear gets one Step 6 summary (or parked note); the PR carries the detailed near-real-time audit trail via `gh`. Live per-step progress lines in Linear are deferred (would require verifying/re-plumbing how forked-skill intermediate output is relayed).
- **Shape: extend, don't fork.** Add a prompt-relay transport branch to the existing skills + one shared contract section. No new orchestrator.

## 3. What breaks in the current code

1. **Detection cascade** (`skills/work-ticket/SKILL.md:36-37`) — the MCP probe looks for `mcp__*Linear*__get_issue`; that tool doesn't exist in-container, so the cascade never resolves `linear` and falls through to "none available → stop." Dead on arrival.
2. **Ticket content doesn't cross the fork boundaries.** Cyrus injects the issue into the *top-level* prompt, but `auto-ticket` is `context: fork` (it sees only SKILL.md + its arguments) and then forks every step again — and the grounding block (`autonomous-contract.md` §2) carries tracker/ticket-ID/URL but **no ticket content**. "Already in the prompt" is false two hops deep. Content must be plumbed explicitly (§4.2).
3. **Every `mcp__*Linear*__*` call fails** — fetches (`work-ticket:55`, `review-ticket`, `finish-ticket:89`, `auto-ticket` Step 0.4), state writes (`work-ticket:95,252`; `finish-ticket:312-313`), attachments, and the follow-up-issue creation in `pr-feedback`.
4. **Park routine** (`autonomous-contract.md` §4) leads with "move the ticket to `needs_human_state` via `save_issue`" — no API to do it.
5. **Multi-comment + subagent relay** — the flow posts several discrete comments, but Cyrus relays the *stream*, and post-v3.2.0 only the top-level session's stream reaches Linear (per-step subagent output stays internal). "Post a ticket comment" must collapse to one consolidated top-level message (§4.3, §4.5).
6. **Stale note** — `auto-ticket/SKILL.md:222` claims the cycle is "safe to launch from Cyrus." It silently assumes the Linear MCP works in-container; it doesn't. Fix the note.

## 4. Design

### 4.1 Detect the transport
Add transport resolution to `work-ticket` Step 0b and `auto-ticket` Step 0, *before* the "none available → stop" branch:

> Tracker resolved to `linear` (via config or arg shape) **and** no `mcp__*Linear*__*` tool present **and** ticket content explicitly provided in the invocation args / grounding block → transport = `prompt-relay`. Otherwise the cascade behaves exactly as today.

No new config keys. (Noted for completeness: the container environment does expose `CYRUS_*` variables that could serve as a detection signal, but content-presence is sufficient, harness-agnostic, and self-authorizing — rejected as an unnecessary second path.)

### 4.2 Content plumbing (the load-bearing addition)
The ticket content must travel through both fork boundaries explicitly:

- **Cyrus prompt template contract (documented, not code):** the repo's Cyrus prompt must invoke `/ccmagic:auto-ticket {TICKET-ID}` **with the issue title + description included in the message**, so the main-loop model passes it into the forked skill's arguments. This is the only channel that survives `context: fork`.
- **Grounding block extension** (`autonomous-contract.md` §2): add a `transport: mcp | prompt-relay` field, and — under prompt-relay only — a fenced `ticket_content:` section (title + description) so every per-step agent receives the content. Fence with a delimiter that tolerates backticks in issue bodies (e.g. `~~~` or a labeled heredoc-style marker).
- **`fetch_ticket` semantics:** read from args/grounding. If transport is prompt-relay and content is absent → **setup error, stop and say so** (not a guess, not a park — the caller should have injected it). This *strengthens* the Sacred Rule: content is explicitly provided, never inferred.

### 4.3 One shared operations section (DRY)
Add `## 7. Prompt-relay transport` to `autonomous-contract.md` defining the operations below; each tracker-I/O step in the skills gets a one-line "in prompt-relay transport, see contract §7" pointer instead of a duplicated branch.

| Op | Prompt-relay behavior |
|---|---|
| `fetch_ticket(id)` | From args/grounding per §4.2. Absent → setup error, stop. |
| `set_state(In Progress)` | No-op — Cyrus already moved to "started". |
| `set_state(In Review \| Done \| needs_human)` | No-op at the API level; emit an intent line ("Requested state: Done") in the final message. Cyrus lifecycle / Linear automation owns the move. Never a failure. |
| `comment(ticket, body)` | **Skip.** No accumulation machinery — the PR carries the detailed audit trail via `gh`, and the orchestrator's Step 6 summary is the single Linear-facing message. |
| `link_pr(url)` | Include the PR URL in the final summary. Linear's GitHub integration auto-links via the issue-id branch name anyway. No attachment API. |
| `file_followup(desc)` | No create API — collect follow-ups and list them under "Follow-ups to file" in the final summary for a human. |

### 4.4 Park under prompt-relay (`autonomous-contract.md` §4 extension)
1. Do not merge (unchanged).
2. **Skip** the Linear state move (no API); rely on Cyrus/human. Because park means "not done" and nothing will infer "Blocked," the relayed parked note must be unmistakable.
3. Post the parked template to the **PR** via `gh pr comment` (GitHub side intact) **and** emit it as the top-level Linear-facing message.
4. Exit cleanly.
5. *(Future)* If Cyrus exposes an agent→Linear "awaiting input" / approval element, use it so park surfaces natively.

### 4.5 Subagent / relay handling
- Only the top-level session stream reaches Linear; per-step subagent output stays internal. The **Step 6 run summary (or parked note) must be emitted as the orchestrator's own final top-level output** so it survives the return to the main loop.
- **Verbatim mitigations** (the one link the plugin can't control is the main-loop model paraphrasing the forked skill's return):
  1. The orchestrator ends its returned text with a clearly delimited "FINAL MESSAGE TO RELAY — reproduce verbatim" block.
  2. The documented Cyrus prompt template instructs the session to repeat the skill's returned summary verbatim as its final message.
- Whether Cyrus relays the forked skill's returned text faithfully is the **remaining unknown** (§6 R1) — it's the primary live-test item.

## 5. Files to touch (when built)

- `skills/auto-ticket/autonomous-contract.md` — §2 grounding-block schema (`transport:`, fenced `ticket_content:`); §4 park fallback; new §7 (prompt-relay ops). **No new config keys.**
- `skills/auto-ticket/SKILL.md` — Step 0 transport resolution (content-presence rule); Step 6 summary as delimited top-level final output under prompt-relay; fix the stale note at :222.
- `skills/work-ticket/SKILL.md` — Step 0b detection; Step 1 fetch-from-grounding; Step 2 skip assign/In-Progress; In-Review write → intent line.
- `skills/review-ticket/SKILL.md` — fetch-from-grounding branch.
- `skills/finish-ticket/SKILL.md` — fetch-from-grounding; state transitions → no-op/intent; closing ticket comment → skip (summary covers it); **merge still via `gh`**.
- `skills/pr-feedback/SKILL.md` — follow-up creation → collect & list in output.
- `skills/doctor/SKILL.md` — recognize the prompt-relay transport so it doesn't report "no tracker."
- `README.md` + a short Cyrus deployment doc — prompt template (invoke with issue content; verbatim-repeat instruction) and prerequisites (Linear GitHub auto-close automation enabled; `gh` authed in-container). `docs/ccmagic.local.md.example` needs no change (no new keys).
- Version bump (minor) + `CHANGELOG.md` entry at build time.

## 6. Questions — resolved & remaining

**Resolved (design review + in-container verification, 2026-07-18):**

1. ~~Does the ticket reach Done after auto-merge?~~ **Yes** — Linear's GitHub integration auto-close automation is enabled on the team; it moves the issue on linked-PR merge. Documented as a deployment prerequisite; the summary still carries a "merged — requested state: Done" intent line as belt-and-braces. Confirm end-to-end in the live test.
2. ~~What signal identifies "inside Cyrus"?~~ **Moot** — detection is content-presence (§2, §4.1); no environment signal needed.
3. ~~Is `gh` authed in-container?~~ **Yes, verified** — `gh` present at `/usr/bin/gh`, logged in via `GH_TOKEN`. Also verified: **no per-user Linear access token in the container env** (only Cyrus's OAuth client id/secret + webhook secret), which confirms relay-only as the right write path.
4. ~~Single final summary vs live progress?~~ **Final summary only** (locked, §2).

**Remaining:**

- **R1 (live-test gate):** does Cyrus relay the forked skill's returned summary to Linear faithfully (not paraphrased/truncated)? Mitigations in §4.5; this is what the throwaway-ticket test primarily verifies.
- **R2 (future):** does Cyrus expose an agent→Linear structured signal (awaiting-input / issue-creation) the park + follow-up paths could use natively? Not needed for v1.

## 7. Testing

1. **Structural** — greps + local plugin load-test, as usual.
2. **Laptop headless simulation** (no Cyrus needed): `claude -p` with the Linear MCP unconfigured and a crafted prompt embedding a fake ticket + the auto-ticket invocation. Exercises detection, fetch-from-args, the no-op state ops, comment-skip, and final-message emission — most of the design.
3. **Live gate** — a throwaway Linear ticket on the real Cyrus instance, confirming: transport detected → ticket read from grounding → PR flow → merge on clean / park on needs-human → the relayed final message lands as a Linear comment **verbatim** (R1) → the ticket reaches Done via the Linear automation.

## 8. Effort / risk

- **Effort:** moderate — one shared contract section + grounding-block extension + ~6 skill I/O branches + detection + docs. No new orchestration; reuses the existing merge/park logic.
- **Risk:** low to interactive/MCP paths (purely additive branch, gated on the transport rule — content-presence can't trigger on a laptop). The main residual risk is R1 (relay fidelity of the final summary), mitigated by the delimited-block + prompt-template instructions and gated by the live test. The former top risk (merged ticket stuck In Progress) is retired by the confirmed Linear auto-close automation.
