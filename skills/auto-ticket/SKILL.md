---
name: auto-ticket
description: Autonomous end-to-end ticket driver. Runs the full work → review → PR-feedback → finish cycle unattended, merging when the work is clean and CI is green, or parking the ticket (needs-human) with a clear note when a decision genuinely requires a human. Detects the tracker (Linear, GitHub Issues, JIRA) and ticket from the argument or current branch.
user-invocable: true
allowed-tools: Read(*), Edit(*), Write(*), Bash(git:*, gh:*, timeout:*), Bash(${CLAUDE_SKILL_DIR}/../../bin/ccm-context *), Bash(${CLAUDE_SKILL_DIR}/../../bin/ccm-ci-status *), Bash(${CLAUDE_SKILL_DIR}/../../bin/ccm-pr-threads *), Glob(*), Grep(*), Task(*), TodoWrite(*), Skill(*)
argument-hint: "[TICKET-ID] (detects from the current branch if omitted)"
model: sonnet
context: fork
---

# /auto-ticket — Autonomous Ticket Driver

Drives one ticket through the entire lifecycle **unattended**: `work-ticket → review-ticket → pr-feedback (looped until clean) → finish-ticket`. It invokes each sub-skill in autonomous mode, parses the [status handshake](#the-contract) each returns, and owns the single decision every autonomous run comes down to — **merge**, or **park for a human**.

Designed for solo-dev projects where auto-merge with no human in the loop is intended. The safety property is **not** "avoid merging" — it's that when the work is genuinely uncertain or needs a human decision, the run **parks** the ticket (no merge, moved to a needs-human state, clear note) instead of guessing or stalling. Repos whose merges belong to an external gate set `merge_owner: reeve`; the run then hands off instead of merging.

**On invocation, announce:** "I'll run `{TICKET-ID}` end-to-end unattended — implement, review, address PR feedback in a loop, and either merge it or park it for you with a clear note if it needs a human decision. Nothing merges unless CI is green and the work is clean."

## Sacred Rule: Never Guess Ticket Content

**If the ticket cannot be found, stop immediately and tell the user. Do not infer, guess, or fabricate what the ticket might contain.** The ticket system is the source of truth.

## The contract

This skill and every sub-skill it calls share one contract — the autonomous signal, the grounding block, the status handshake, and the route-and-stop routine. **Read `${CLAUDE_SKILL_DIR}/autonomous-contract.md` first** and follow it exactly. Key points used throughout:

- Sub-skills are invoked in autonomous mode by prepending the **grounding block** (contract §2) to their arguments. Because the block carries `orchestrator: auto-ticket`, sub-skills return their handshake and let **this** skill park — they never park themselves.
- Every sub-skill ends with a **handshake** (contract §3): `status: clean | fixable-findings | needs-human | done`. Parse the last one. A missing handshake = treat as `needs-human`.
- **`route-and-stop`** (contract §4) is the one way this skill ends a run early. Every exit path is **merged**, **handed-off** (only with `merge_owner: reeve`), or **parked-needs-human** — never stalled.

---

## Step execution mode

`auto-ticket` runs **forked** (`context: fork`), so it executes as a subagent and can spawn a child subagent per step. Every step below always runs **forked** to its per-step agent: `run_step(step, grounding)` = spawn the step's per-step agent via the `Task` tool, passing the grounding block as the task prompt, on the step's model (see the registry), and parse the **last** handshake block from the child's returned text.

Call `Task` with `run_in_background: false` for every step, and keep every Bash call in the foreground too. This orchestrator is itself a subagent: if it ends its turn to wait for a background step, it returns to its caller before the step reports, and the run summary (Step 6) is never posted. The per-step agents follow the same rule for anything they launch.

There is no inline mode: a forked orchestrator cannot invoke a `context: fork` skill, and the steps reach forked skills (`validate` itself, and `analyze-impact` from `work-ticket`), so running steps inline in this orchestrator's own context is not achievable. (`review` also ran forked until 3.13.2; it now runs inline.) Per-step isolation and per-step models are the whole point of this skill.

**Every step below runs through `run_step`**, including the `/ccmagic:push` commit-and-push call sites in the Step 3 review-fix loop and Step 4b validate-fix. Nothing else about the flow (route-and-stop, loops, bounds) changes.

### Per-step agent registry

| Step | Agent | Default model | Config override |
|------|-------|---------------|-----------------|
| work-ticket | `auto-work` | `opus` | `model_work_ticket` |
| review-ticket | `auto-review` | `opus` | `model_review_ticket` |
| pr-feedback | `auto-feedback` | `sonnet` | `model_pr_feedback` |
| validate | `auto-validate` | `sonnet` | `model_validate` |
| finish-ticket | `auto-finish` | `sonnet` | `model_finish_ticket` |
| push | `auto-push` | `haiku` | `model_push` |

Model resolution per step: the agent's frontmatter `model:` is the authoritative default; if a `model_<step>` config value is set, pass it as the `Task` per-invocation model override (best-effort). All six steps route through `run_step`, always forked.

A step agent may deliver its report through a `SubagentHandback` tool call, in which case that call's message is the report you receive. Parse the handshake from it the same way. If a step's report has no handshake, apply the contract §3 missing-handshake rule; do not reconstruct one from its prose.

### Tracker reads and writes belong to this skill

Step agents cannot reach tracker MCP tools, so in this run **only this skill reads or writes the tracker** (contract §8): it fetches the ticket once (Step 0) and hands the content to every step in the grounding block; every step reports the tracker changes it needs, and this skill applies them. Never ask a step agent to fetch or update the ticket, and don't let one spawn a helper for it. After every `run_step`, before acting on the verdict:

1. **Record `follow_ups`.** Append every non-empty item of the handshake's `follow_ups:` to the run's follow-up list, noting the step it came from. Nothing on that list is dropped; Step 6 accounts for each item.
2. **Apply `requested_state:`** if the handshake has one:
   - **mcp, Linear or JIRA:** transition the ticket (Linear `save_issue`, JIRA transition via the Atlassian MCP). Match the state name case-insensitively against the team's states. `In Review`: "In Review", then "Review", "Ready for Review". `Done`: "Done", then "Completed", "Closed"; if none exists, apply `needs_human_label`, leave the state, and say so in the summary. `{merge_handoff_state}`: **exact** name only; if it doesn't exist, **route-and-stop** (reason: `merge_owner is reeve but state "{merge_handoff_state}" does not exist on {team}`; nothing was merged on that path). Skip the write if the ticket is already in the target state (Linear's GitHub integration often moves it on merge).
   - **mcp, GitHub Issues:** `In Review` needs no state change. `Done`: confirm the issue closed (`Closes #N` usually does it), else `gh issue close {N}`. `{merge_handoff_state}`: `gh label create "awaiting-merge" 2>/dev/null || true`, then `gh issue edit {N} --add-label "awaiting-merge"`.
   - **prompt-relay:** keep the value; Step 6 emits it as `Requested state:`.

   A failed tracker write (other than the missing hand-off state) is not a park: say what failed in the summary and continue, as `work-ticket` did when it owned the write.

---

## Step 0: Resolve tracker, ticket, and config

1. **Resolve the tracker.** Before anything else in this step, run the `ccm-context` call shown in item 2: the settings and arg/branch shape this cascade starts from come from its output. Then use the exact same cascade as `/ccmagic:work-ticket` Step 0 (settings → arg/branch shape → MCP probe → CLI probe → branch hint). This runs unattended, so if the cascade is genuinely ambiguous (would otherwise prompt), pick the highest-confidence candidate and record the choice in the run summary. **Then resolve the transport once for the whole run:** default `transport: mcp`, then apply the contract §7 detection rule (server-availability + load-with-retry) *before* the none-available stop below — a Linear run with an MCP server available (even one still connecting) resolves `transport: mcp`; a headless Linear run with no MCP server at all resolves `transport: prompt-relay` instead of stopping. This single resolved value goes into the grounding block (Step 5); every sub-skill inherits it and does not re-detect. Only if **no** tracker resolves (and it isn't a prompt-relay run) do you stop and tell the user (this is a setup error, not a parkable ticket).
2. **Resolve the ticket ID and config** with one call, passing the argument when there is one:
   ```bash
   "${CLAUDE_SKILL_DIR}/../../bin/ccm-context" {TICKET-ID}   # argument given
   "${CLAUDE_SKILL_DIR}/../../bin/ccm-context"               # no argument: parse the current branch
   ```
   (Bare `ccm-context` works too; plugin `bin/` is on `PATH`.) Read `ticket_id` from its JSON: the argument (a leading `#` stripped), or the segment after the branch prefix (`feature/ENG-123-slug` gives `ENG-123`, `bugfix/42-slug` gives `42`), the same parse `/ccmagic:finish-ticket` Step 1 uses. Do not re-parse the branch yourself. If `ticket_id` is null, **exit cleanly** with a one-line message asking the caller to pass one (`/ccmagic:auto-ticket {TICKET-ID}`); this is a setup error, not a parkable ticket, so do not wait for input. The same JSON's `tracker_hint`, `gh_available`, and `config.tracker` feed item 1's cascade (settings and arg/branch shape); the MCP probe, CLI probe, and transport detection stay in item 1.
3. **Load config** from the same output's `config` object, which already applies the precedence project `.claude/ccmagic.local.md` over user `~/.claude/ccmagic.local.md` over the built-in defaults (see contract §5). An explicit arg still beats `config`. Do not re-read the config files. Keys: `needs_human_state`, `needs_human_label` (default `needs-human`), `merge_owner` (default `self`), `merge_handoff_state` (default `Awaiting Merge`), `max_feedback_passes` (default `3`), `max_review_fix_passes` (default `3`), `max_validate_attempts` (default `2`), `ci_timeout_minutes` (default `30`), `ci_poll_interval_seconds` (default `60`), plus the usual `tracker` / `ticket_url_base` / `github_repo`, and the per-step model overrides `model_work_ticket`, `model_review_ticket`, `model_pr_feedback`, `model_finish_ticket`, `model_validate`, `model_push`. The model keys have no built-in default in `ccm-context`, so they appear in `config` only when set; when absent, use the registry value.
4. **Fetch the ticket** to confirm it exists (per the tracker's lookup in `work-ticket`/`review-ticket`), and keep its title, description, and acceptance criteria (a separate AC field too, if the tracker has one) exactly as written: the grounding block carries them to every step, and no step fetches the ticket again. If not found, stop (Sacred Rule). Then, on the **mcp** transport, assign the ticket to yourself and move it to In Progress, as `work-ticket` Step 2 describes for each tracker (the step agents no longer do this); if that fails, note it for the summary and continue. Under **prompt-relay** there is no MCP to fetch from — instead confirm the ticket content (title + description) is present in the invocation arguments / grounding block, **or in a `.ccmagic-ticket.md` handoff file in the working directory** — a fork-safe content source for harnesses (like Cyrus) that inject the ticket into a *parent* prompt the forked skill can't see. If you read it from the handoff file, `rm` the file afterward so it is never committed. If it's absent from all of these, stop with a setup-error message: this is the Sacred Rule made explicit — the caller should have injected the content, so a missing body is a setup error, never a guess and never a park.
5. **Build the grounding block** (contract §2) with the resolved values. Mint `run_id` first — a short unique id for this run (e.g. `openssl rand -hex 3`, or the last 6 digits of `date +%s`); it keys the Step 6 idempotency guard. The block also carries the `transport:` line and, on every transport, the fenced `ticket_content:` section (contract §2), so every per-step agent receives the ticket body without fetching it. Prepend it to every sub-skill invocation below. `/ccmagic:auto-ticket` always drives sub-skills with `autonomous: true`, regardless of the `autonomous:` config default.

Create a TodoWrite entry per stage (work → review → feedback loop → finish → summary) so progress is visible during a long unattended run.

---

## Step 1: Work the ticket

> Each step below is executed via `run_step` (see *Step execution mode*): always forked to its per-step agent.

Run the work-ticket step via `run_step` — `/ccmagic:work-ticket {TICKET-ID}` with the grounding block prepended.

- It classifies, branches, implements, self-reviews, validates scope, and opens the PR — all without pausing (see its *Autonomous mode*).
- **Parse the handshake:**
  - `done` → the PR was created, and the handshake carries `requested_state: In Review` and the PR URL in `reason`. The move to In Review happens in the after-step routine above. On **mcp**, also link the PR to the ticket: Linear `create_attachment` with the PR URL (or a `save_comment` if attachments aren't available), GitHub `gh issue comment {N} --body "PR ready for review: {pr_url}"`, JIRA a comment via the Atlassian MCP. Continue to Step 2.
  - `needs-human` → **route-and-stop** with the sub-skill's reason (stage = `work-ticket`).

---

## Step 2: Locate the PR

Resolve the PR the run will operate on:

```bash
gh pr view --json number,url,title,baseRefName,headRefName --jq '{number,url,title,baseRefName,headRefName}'
```

Store `{PR_NUMBER}`, `{PR_URL}`, `{BASE_BRANCH}`. Add `pr:` to the grounding block for the remaining steps. If no PR exists after a `done` from `work-ticket`, that's an inconsistency → **route-and-stop** (reason: "work-ticket reported done but no PR is present").

---

## Step 3: Ticket-grounded review

Run the review-ticket step via `run_step` — `/ccmagic:review-ticket {TICKET-ID}` with the grounding block prepended. Then act on the verdict:

- `clean` → continue to Step 4.
- `needs-human` → **route-and-stop** (stage = `review-ticket`).
- `fixable-findings` → run a **bounded fix loop** (max `max_review_fix_passes` passes, default **3**):
  1. Apply the CRITICAL findings (and any listed fixable missing-AC items) from the report — edit the code directly. A `systemic:`-tagged finding is fixed **as a class**: apply the fix to every enumerated instance, then re-run the enumeration search yourself to catch stragglers — never point-fix only the reported line. A security finding, or one whose correctness depends on an invariant over untrusted input, follows contract §9 before the commit: run the verifier's triggering inputs (the finding's **Reproduction**) against the fix, rerun any fuzzed or enumerated corpus within the scratch-program limits (`timeout 60`, smallest corpus that shows the behavior), and add a property or parameterized test stating the invariant. If the fix still fails any of those inputs, do not push it as fixed: **route-and-stop** (reason: the finding and the first failing input).
  2. Commit and push via `/ccmagic:push` with the grounding block (run this via `run_step`). If push returns `needs-human`, **route-and-stop**.
  3. Re-invoke the review-ticket step via `run_step`, adding `review_pass: {n}` to the grounding block (2 on the first re-review, incrementing) so the reviewer produces a delta report (contract §2), and appending a `previous_findings:` section listing the findings just applied (contract §2), with the invariant test for each one fixed under contract §9, so the fresh review subagent knows what to verify.
  4. `clean` → continue to Step 4. `fixable-findings` again and passes remain → repeat. Passes exhausted still not clean, or `needs-human` → **route-and-stop** (reason: the outstanding findings).

Only CRITICAL findings and closable missing-AC items gate here. Out-of-scope changes are flagged in the PR (review-ticket already posts them) and do not block.

---

## Step 4: PR-feedback loop

Loop up to `max_feedback_passes` (default 3). **At the very start of each pass — before applying any fix and before anything is pushed — record the current highest PR review-comment id as this pass's high-water mark `H`:**

```bash
"${CLAUDE_SKILL_DIR}/../../bin/ccm-pr-threads" {PR_NUMBER}
```

`H` is the `max_review_comment_id` field of the output.

(The `ccm-*` scripts are also on the Bash `PATH` while the plugin is enabled; if the `${CLAUDE_SKILL_DIR}/../../bin/` path doesn't resolve, call them by bare name.)

Everything this pass pushes is measured against `H`, so bot reviews triggered *by* this pass's push are counted as new (4c). Then:

**4a. Apply feedback.** Run the pr-feedback step via `run_step` — `/ccmagic:pr-feedback {PR_NUMBER}` with the grounding block. Autonomous `pr-feedback` applies address-now fixes, replies to declined/question threads, records each defer/out-of-scope item as a short description in `follow_ups` (it files no tickets in an orchestrated run; Step 6 does), and pushes. Collect its handshake counts; its `follow_ups` go on the run's list like every step's.
  - `needs-human` (e.g. a genuine reviewer tie) → **route-and-stop** (stage = `pr-feedback`).

**4b. Validate locally before trusting CI.** Run the validate step via `run_step` — `/ccmagic:validate`. If it fails, fix the regressions (bounded: `max_validate_attempts` attempts, default **2**, editing + re-validating), then commit/push via `/ccmagic:push` (run this via `run_step`). If it still fails after the attempts → **route-and-stop** (reason: "local validation fails: {summary}"). Doing this locally keeps CI + bot-review round-trips rare.

**4c. Wait for CI and new reviews.** This pass's push(es) already happened (in 4a via `pr-feedback`, and possibly again in 4b); `H` was captured before them at the top of the pass. Now that they've landed:
  - **Wait for CI to settle** with one command, repeated only while it says so:
    ```bash
    "${CLAUDE_SKILL_DIR}/../../bin/ccm-ci-status" {PR_NUMBER} --watch --wait-key {run_id}-pass{n}
    ```
    Run it as a single Bash call with the maximum tool timeout (600000 ms). Each call returns within ten minutes. If the output has `"call_again": true`, run the identical command again. The wait-key's deadline file bounds the total wait at `ci_timeout_minutes`, so do not count calls yourself. Act on the final `status`:
    - `green` or `no-ci` → CI is settled and green (record "no CI configured" in the run summary for `no-ci`).
    - `failed` → settled, not green. Carry `reason` and `checks` into 4d.
    - `timeout` → **route-and-stop** (reason: "CI did not complete within the timeout", plus the script's `reason`; a `not-registered` timeout means CI is configured but no run appeared for the head SHA).
    - `unreadable` → **route-and-stop** (reason: "cannot read CI status: {reason}").

    The script handles what this step used to spell out: the fine-grained-PAT 403 fallback to the Actions and commit-status APIs, the "no checks at all" case (no workflows and no required checks means `no-ci`; otherwise it keeps waiting for a run to register), and quick transient `gh` failures. Don't re-derive CI state from `gh pr checks` output.
  - Then read the review threads against `H`:
    ```bash
    "${CLAUDE_SKILL_DIR}/../../bin/ccm-pr-threads" {PR_NUMBER} --since-id {H}
    ```
    `new_comment_count` counts reviewer comments above `H` (for example Copilot or Claude bot reviews posted in response to this pass's push). `open_thread_count` counts threads that aren't handled. A thread is handled when it is resolved, or when its last comment is the author's `ccm-pr-reply` reply with a disposition marker (`fixed` counts only once the cited commit is verified on the branch and touches the thread's file). Autonomous `pr-feedback` replies that way, so the threads it fixed, declined, answered, or deferred don't count. A bare "will fix" reply does. Capturing `H` before the push is what lets a bot review posted in response to this push count as new rather than being mistaken for an already-handled thread. If `truncated` is true, say so in the run summary.

**4d. Recompute "clean".** The pass is **clean** when **both** hold:
  - `open_thread_count` is 0, and
  - the final `ccm-ci-status` status was `green` or `no-ci`.

**4e. Decide.**
  - **clean** → break out of the loop; continue to Step 5.
  - a `needs-human` item surfaced → **route-and-stop**.
  - **pass cap hit and still not clean** → **route-and-stop** (reason: "still not clean after {max_feedback_passes} feedback passes: {what remains}").

---

## Step 5: Finish the ticket

Run the finish-ticket step via `run_step` — `/ccmagic:finish-ticket` with the grounding block. Its Step 3 sanity check is the **merge gate**: it merges only if the PR is mergeable, CI is green, and there are no unaddressed change-requests.

- `done` with `reason` beginning `handed off to reeve` → the PR is open and nothing merged; the handshake carries `requested_state: {merge_handoff_state}`, which the after-step routine applies (a missing state parks the run there). Continue to Step 6 with outcome **handed-off**.
- `done` otherwise → the PR merged; the handshake carries `requested_state: Done`, which the after-step routine applies. Continue to Step 6 with outcome **merged**.
- `needs-human` → the gate wasn't satisfied. It did **not** merge → **route-and-stop** (stage = `finish-ticket`, reason: its blockers).

---

## Step 6: Post the run summary

Whatever the outcome, record it on the PR and the ticket so the unattended run leaves an audit trail.

**Follow-ups first.** Go through the run's follow-up list (every non-empty `follow_ups:` item from every step, including a `clean` review's optional items). For each item decide one of:

- **file it**: on mcp, create a ticket in the same tracker and team (Linear `save_issue` related to `{TICKET-ID}`, `gh issue create`, or the Atlassian MCP) with a title and a description that names the PR and the step that raised it, then list its ID; or
- **don't file it**, with a one-line reason: already a ticket ID (list it as is), a duplicate of another item, fixed later in this run (name the commit or pass), or too minor to track (say why).

Under prompt-relay there is no create API, so list every item under "to file" for a human. Every item appears in the summary's Follow-ups section; "none" is correct only when the list is empty. A parked run does the same before route-and-stop posts its note.

````markdown
## 🤖 Autonomous run summary — {TICKET-ID}

**Outcome:** {✅ Merged into `{base}` | 🔁 Handed off to Reeve, awaiting merge | 🅿️ Parked — needs human}
**PR:** {pr_url}
**Run:** {run_id}
**Requested state:** {Done | merge_handoff_state | needs_human_state} *(prompt-relay only — omit under mcp)*

### What ran
- Classified as **{class}**, branched, implemented, opened the PR.
- Review: {clean first pass | N CRITICAL findings fixed and re-reviewed}.
- PR feedback: {P} pass(es) — applied {A}, declined {D}, deferred {F}.
- Finish: {merged with {squash|merge commit} | handed off to reeve | gate not satisfied}.

### Key autonomous decisions
- {classification + reasoning}
- {any minor implementation choices made instead of asking}
- {out-of-scope changes flagged, if any}

### Follow-ups
- Filed: {ticket id}: {one-liner} (from {step})
- Not filed: {item} (from {step}): {reason}
- To file (prompt-relay): {item} (from {step})
- {or "none" when no step reported a follow-up}

### If parked
**Waiting on:** {the reason}. Nothing was merged. Resolve it, then re-run `/ccmagic:auto-ticket {TICKET-ID}`.

### Run record
```json
{"ccmagic": {"version": 1, "run_id": "{run_id}", "ticket": "{TICKET-ID}", "outcome": "{merged | handed-off | parked}", "classification": "{class}", "merge_owner": "{self | reeve}", "pr": {pr_number or null}, "review_passes": {n}, "feedback_passes": {n}, "ci_attempts": {n}, "findings": {"critical": {n}, "high": {n}}, "steps": [{"step": "work-ticket", "status": "done"}, {"step": "review-ticket", "status": "clean"}, {"step": "validate", "status": "needs-human", "reason": "{one line}"}, {"step": "validate", "status": "done"}, {"step": "finish-ticket", "status": "done", "reason": "handed off to reeve; PR #12 awaiting merge"}], "follow_ups": [{"item": "{short description}", "step": "review-ticket", "ticket": "{id or null}", "reason": "{why not filed, or null}"}]}}
```
````

`steps` lists every sub-skill invocation of this run in order, one entry each, with the handshake `status` it returned; include `reason` whenever the sub-skill emitted one. Repeated review passes are separate entries. `follow_ups` has one entry per item on the run's follow-up list (empty array when there were none): `ticket` is the filed ID or null, and `reason` says why it wasn't filed (null when filed). The block is emitted on every outcome and under every transport. It is the machine-readable record an external gate reads, so its keys are fixed and must not be renamed; `follow_ups` was added in 3.13.0 as an additive key, and readers that don't know it ignore it.

**Idempotency guard:** before posting to any surface, list its existing comments (`gh pr view {PR_NUMBER} --json comments --jq '.comments[].body'` for the PR; the tracker's comment list for the ticket) and **skip that surface** if a `🤖 Autonomous run summary` comment carrying this `run_id` already exists. Re-running Step 6 **within a single orchestrator context** — the same forked run reaching this step more than once — must never double-post. (Any fresh invocation of `/ccmagic:auto-ticket` — including a restart after a crash — mints a new `run_id` in Step 0 and posts its own summary; that is intentional — each run leaves its own audit trail.)

- **Merged or handed-off (mcp transport)** → post the summary as a PR comment and a ticket comment, then report the final status to the user. The ticket comment takes the place of `finish-ticket`'s closing or hand-off comment, which the finish step leaves in its report instead of posting (contract §8); fold its "Summary of changes" into "What ran".
- **Parked (mcp transport)** → the summary is folded into the parked-comment posted by route-and-stop (contract §4); don't double-post.
- **Under prompt-relay (contract §7)** → do **not** attempt a ticket comment (there is no Linear API in the environment).
  - **Merged or handed-off** → still post the summary as a PR comment via `gh`, then emit that same summary as this skill's **own final top-level output**, ending with the delimited final-message block (the `=== FINAL MESSAGE TO RELAY (reproduce verbatim) ===` / `=== END FINAL MESSAGE ===` wrapper, contract §7). Carry the intent line `Requested state: Done` (merged) or `Requested state: {merge_handoff_state}` (handed-off) — sourced from the step handshakes' `requested_state:` fields (contract §3) — and any "Follow-ups to file" list into that summary.
  - **Parked** → route-and-stop has already produced the parked note and posted it to the PR (contract §4, prompt-relay branch); emit that same note as the single top-level final message, wrapped in the same delimiters.
  - *Why this shape:* only the orchestrator's top-level output is relayed to the tracker — per-step subagent output stays internal — so the summary must be **this** skill's final message, not a sub-skill's.

---

## Route-and-stop

The single early-exit routine, defined in `${CLAUDE_SKILL_DIR}/autonomous-contract.md` §4. In short: **do not merge**; move the ticket to `needs_human_state` (fall back to `needs_human_label` if the state doesn't exist); comment the exact reason on the PR **and** the ticket using the parked-comment template; emit a clear final status; exit. Call it — with the failing stage and the sub-skill's `reason` — at every `needs-human`, at the feedback-pass cap, and whenever CI/validation can't be made green within bounds.

Every run ends in exactly one of these states:

| Outcome | Meaning |
|---------|---------|
| **merged** | PR merged, ticket Done, summary posted. |
| **handed-off** | PR open, ticket in `merge_handoff_state`, summary posted. Only with `merge_owner: reeve`. |
| **parked-needs-human** (run record `outcome`: `parked`) | Not merged, ticket in `needs_human_state` (or labeled), reason posted. |

There is no stalled outcome. Never hang waiting for input.

---

## Error handling

| Situation | Action |
|-----------|--------|
| No tracker available / not connected | Stop and tell the user (setup error, not a parkable ticket). |
| Ticket ID can't be resolved | Exit cleanly with a message requesting a ticket ID — don't wait for input (setup error, not a parkable ticket). |
| Ticket not found | Stop (Sacred Rule). |
| Prompt-relay: ticket content missing from invocation | Stop and say so (a prompt-relay setup error, not a parkable ticket). |
| A sub-skill emits no handshake (crash/tool error) | Treat as `needs-human` → route-and-stop with reason "{skill} produced no handshake". |
| `work-ticket` → `needs-human` | route-and-stop (stage `work-ticket`). |
| `review-ticket` → `needs-human`, or `fixable-findings` unresolved after the bounded loop | route-and-stop (stage `review-ticket`). |
| `pr-feedback` → `needs-human` (genuine reviewer tie) | route-and-stop (stage `pr-feedback`). |
| Local `/ccmagic:validate` can't be made green within the bounded attempts | route-and-stop (reason: validation failures). |
| CI never settles within `ci_timeout_minutes` (watch loop cap) | route-and-stop (reason: CI timeout). |
| Feedback-pass cap hit still not clean | route-and-stop (reason: remaining threads / red CI). |
| `finish-ticket` merge gate not satisfied | It returns `needs-human` and does not merge → route-and-stop (stage `finish-ticket`). |
| `requested_state: {merge_handoff_state}` and no state of that exact name exists | route-and-stop (stage `finish-ticket`); nothing was merged on the hand-off path. |
| Any other tracker write fails (In Progress, In Review, Done, PR link, follow-up ticket) | Not a park. Say what failed in the summary and continue; an unfiled follow-up is listed with the error as its reason. |
| A step reports it has no `ticket_content` | Treat as a setup error of this skill: the grounding block must always carry it (Step 0 item 5). Fix the block and re-run the step once; if it still fails, route-and-stop. |
| `route-and-stop` can't move state (no matching state) | **mcp:** apply `needs_human_label`, leave state unchanged, still post the comment (contract §4). **prompt-relay:** contract §4's prompt-relay branch applies — no state/label writes; PR comment + relayed parked note. |

---

## Notes

- **Backlog selector (future).** This skill is deliberately single-ticket: give it a ticket, it drives that ticket. A future backlog-triage/selector skill can call `/ccmagic:auto-ticket {ID}` once per chosen ticket; nothing here assumes it is the top of the stack. Do not build the selector here.
- **Headless harnesses.** A headless harness that injects the ticket into the invocation and relays the session's final output back to the tracker is supported via the **prompt-relay transport** (contract §7): it engages when no Linear MCP is available to the session (with ticket content supplied in the invocation), tracker writes collapse to the single relayed final message, and the GitHub/PR half of the cycle runs on `gh` as usual. Where a hosted Linear MCP *is* present (e.g. Cyrus), runs use the `mcp` transport by default and fall back only during the brief session-start connect window. Deployment prerequisites and the required prompt template live in `docs/cyrus-deployment.md`.
- **Additivity.** This skill only ever invokes sub-skills in autonomous mode; it never alters their interactive paths.
