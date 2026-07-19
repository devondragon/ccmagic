---
name: auto-ticket
description: Autonomous end-to-end ticket driver. Runs the full work → review → PR-feedback → finish cycle unattended, merging when the work is clean and CI is green, or parking the ticket (needs-human) with a clear note when a decision genuinely requires a human. Detects the tracker (Linear, GitHub Issues, JIRA) and ticket from the argument or current branch.
user-invocable: true
allowed-tools: Read(*), Edit(*), Bash(git:*, gh:*), Glob(*), Grep(*), Task(*), TodoWrite(*), Skill(*)
argument-hint: "[TICKET-ID] (detects from the current branch if omitted)"
model: sonnet
context: fork
---

# /auto-ticket — Autonomous Ticket Driver

Drives one ticket through the entire lifecycle **unattended**: `work-ticket → review-ticket → pr-feedback (looped until clean) → finish-ticket`. It invokes each sub-skill in autonomous mode, parses the [status handshake](#the-contract) each returns, and owns the single decision every autonomous run comes down to — **merge**, or **park for a human**.

Designed for solo-dev projects where auto-merge with no human in the loop is intended. The safety property is **not** "avoid merging" — it's that when the work is genuinely uncertain or needs a human decision, the run **parks** the ticket (no merge, moved to a needs-human state, clear note) instead of guessing or stalling.

**On invocation, announce:** "I'll run `{TICKET-ID}` end-to-end unattended — implement, review, address PR feedback in a loop, and either merge it or park it for you with a clear note if it needs a human decision. Nothing merges unless CI is green and the work is clean."

## Sacred Rule: Never Guess Ticket Content

**If the ticket cannot be found, stop immediately and tell the user. Do not infer, guess, or fabricate what the ticket might contain.** The ticket system is the source of truth.

## The contract

This skill and every sub-skill it calls share one contract — the autonomous signal, the grounding block, the status handshake, and the route-and-stop routine. **Read `${CLAUDE_SKILL_DIR}/autonomous-contract.md` first** and follow it exactly. Key points used throughout:

- Sub-skills are invoked in autonomous mode by prepending the **grounding block** (contract §2) to their arguments. Because the block carries `orchestrator: auto-ticket`, sub-skills return their handshake and let **this** skill park — they never park themselves.
- Every sub-skill ends with a **handshake** (contract §3): `status: clean | fixable-findings | needs-human | done`. Parse the last one. A missing handshake = treat as `needs-human`.
- **`route-and-stop`** (contract §4) is the one way this skill ends a run early. Every exit path is either **merged** or **parked-needs-human** — never stalled.

---

## Step execution mode

`auto-ticket` runs **forked** (`context: fork`), so it executes as a subagent and can spawn a child subagent per step. Every step below always runs **forked** to its per-step agent: `run_step(step, grounding)` = spawn the step's per-step agent via the `Task` tool, passing the grounding block as the task prompt, on the step's model (see the registry), and parse the **last** handshake block from the child's returned text.

There is no inline mode — a forked orchestrator cannot invoke the `context: fork` skills that `work-ticket`/`review-ticket`/`validate` reach, so running steps inline in this orchestrator's own context was never actually achievable. Per-step isolation and per-step models are the whole point of this skill.

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

---

## Step 0: Resolve tracker, ticket, and config

1. **Resolve the tracker** using the exact same cascade as `/ccmagic:work-ticket` Step 0 (settings → arg/branch shape → MCP probe → CLI probe → branch hint). This runs unattended, so if the cascade is genuinely ambiguous (would otherwise prompt), pick the highest-confidence candidate and record the choice in the run summary. **Then resolve the transport once for the whole run:** default `transport: mcp`, then apply the contract §7 detection rule (server-availability + load-with-retry) *before* the none-available stop below — a Linear run with an MCP server available (even one still connecting) resolves `transport: mcp`; a headless Linear run with no MCP server at all resolves `transport: prompt-relay` instead of stopping. This single resolved value goes into the grounding block (Step 5); every sub-skill inherits it and does not re-detect. Only if **no** tracker resolves (and it isn't a prompt-relay run) do you stop and tell the user (this is a setup error, not a parkable ticket).
2. **Resolve the ticket ID** from the argument, or parse it from the current branch (strip `feature/`, `bugfix/`, `hotfix/`, `chore/` prefixes) — same logic as `/ccmagic:finish-ticket` Step 1. If neither yields a ticket ID, **exit cleanly** with a one-line message asking the caller to pass one (`/ccmagic:auto-ticket {TICKET-ID}`) — this is a setup error, not a parkable ticket; do not wait for input.
3. **Load config**, resolving each value by precedence — an explicit arg → the project file `.claude/ccmagic.local.md` → the user file `~/.claude/ccmagic.local.md` → the built-in default (see contract §5). Keys: `needs_human_state`, `needs_human_label` (default `needs-human`), `max_feedback_passes` (default `3`), `max_review_fix_passes` (default `3`), `max_validate_attempts` (default `2`), `ci_timeout_minutes` (default `30`), `ci_poll_interval_seconds` (default `60`), plus the usual `tracker` / `ticket_url_base` / `github_repo`, and the per-step model overrides `model_work_ticket`, `model_review_ticket`, `model_pr_feedback`, `model_finish_ticket`, `model_validate`, `model_push` (each defaulting to the registry value).
4. **Fetch the ticket** to confirm it exists (per the tracker's lookup in `work-ticket`/`review-ticket`). If not found, stop (Sacred Rule). Under **prompt-relay** there is no MCP to fetch from — instead confirm the ticket content (title + description) is present in the invocation arguments / grounding block (contract §7 `fetch_ticket`). If it's absent, stop with a setup-error message: this is the Sacred Rule made explicit — the caller should have injected the content, so a missing body is a setup error, never a guess and never a park.
5. **Build the grounding block** (contract §2) with the resolved values. Mint `run_id` first — a short unique id for this run (e.g. `openssl rand -hex 3`, or the last 6 digits of `date +%s`); it keys the Step 6 idempotency guard. The block also carries the `transport:` line, and under prompt-relay the fenced `ticket_content:` section, so every per-step agent receives the ticket body. Prepend it to every sub-skill invocation below. `/ccmagic:auto-ticket` always drives sub-skills with `autonomous: true`, regardless of the `autonomous:` config default.

Create a TodoWrite entry per stage (work → review → feedback loop → finish → summary) so progress is visible during a long unattended run.

---

## Step 1: Work the ticket

> Each step below is executed via `run_step` (see *Step execution mode*): always forked to its per-step agent.

Run the work-ticket step via `run_step` — `/ccmagic:work-ticket {TICKET-ID}` with the grounding block prepended.

- It classifies, branches, implements, self-reviews, validates scope, and opens the PR — all without pausing (see its *Autonomous mode*).
- **Parse the handshake:**
  - `done` → the PR was created and the ticket moved to In Review. Continue to Step 2.
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
  1. Apply the CRITICAL findings (and any listed fixable missing-AC items) from the report — edit the code directly. A `systemic:`-tagged finding is fixed **as a class**: apply the fix to every enumerated instance, then re-run the enumeration search yourself to catch stragglers — never point-fix only the reported line.
  2. Commit and push via `/ccmagic:push` with the grounding block (run this via `run_step`). If push returns `needs-human`, **route-and-stop**.
  3. Re-invoke the review-ticket step via `run_step`, adding `review_pass: {n}` to the grounding block (2 on the first re-review, incrementing) so the reviewer produces a delta report (contract §2), and appending a `previous_findings:` section listing the findings just applied (contract §2) so the fresh review subagent knows what to verify.
  4. `clean` → continue to Step 4. `fixable-findings` again and passes remain → repeat. Passes exhausted still not clean, or `needs-human` → **route-and-stop** (reason: the outstanding findings).

Only CRITICAL findings and closable missing-AC items gate here. Out-of-scope changes are flagged in the PR (review-ticket already posts them) and do not block.

---

## Step 4: PR-feedback loop

Loop up to `max_feedback_passes` (default 3). **At the very start of each pass — before applying any fix and before anything is pushed — record the current highest PR review-comment id as this pass's high-water mark `H`:**

```bash
gh api repos/{owner}/{repo}/pulls/{PR_NUMBER}/comments --jq '[.[].id] | max // 0'
```

Everything this pass pushes is measured against `H`, so bot reviews triggered *by* this pass's push are counted as new (4c). Then:

**4a. Apply feedback.** Run the pr-feedback step via `run_step` — `/ccmagic:pr-feedback {PR_NUMBER}` with the grounding block. Autonomous `pr-feedback` applies address-now fixes, replies to declined/question threads, files a follow-up ticket per defer/out-of-scope item, and pushes. Collect its handshake counts and `follow_ups`.
  - `needs-human` (e.g. a genuine reviewer tie) → **route-and-stop** (stage = `pr-feedback`).

**4b. Validate locally before trusting CI.** Run the validate step via `run_step` — `/ccmagic:validate`. If it fails, fix the regressions (bounded: `max_validate_attempts` attempts, default **2**, editing + re-validating), then commit/push via `/ccmagic:push` (run this via `run_step`). If it still fails after the attempts → **route-and-stop** (reason: "local validation fails: {summary}"). Doing this locally keeps CI + bot-review round-trips rare.

**4c. Wait for CI and new reviews.** This pass's push(es) already happened (in 4a via `pr-feedback`, and possibly again in 4b); `H` was captured before them at the top of the pass. Now that they've landed:
  - **Wait for CI to settle** — no check `pending`/`in_progress` — using a **bounded blocking watch**. (A sleep-based poll loop is not executable in this context: the orchestrator has no wait primitive. The blocking watch below is.)
    1. Compute the watch budget: `CYCLES = ceil(ci_timeout_minutes / 10)` (default 30 min → 3 watch invocations). The budget quantizes up to whole 10-minute cycles — `12` waits up to 20 min, and values under 10 still get one full cycle.
    2. Run the watch as a single Bash call **with the maximum tool timeout (600000 ms)**:
       ```bash
       gh pr checks {PR_NUMBER} --watch --interval {ci_poll_interval_seconds}
       ```
       `--watch` blocks until no check is pending, so each call either returns with CI settled or is cut off by the 10-minute tool timeout. A non-zero exit with output showing completed checks means **settled with failures** — that is a settled state; carry the per-check pass/fail breakdown into 4d and do not re-invoke the watch ("settled" is never shorthand for "green").
    3. If the call was cut off by the tool timeout, it consumed a full 10 minutes by construction — count it. Fewer than `CYCLES` cut-off calls so far → re-invoke the watch (step 2). `CYCLES` reached → **route-and-stop** (reason: "CI did not complete within the timeout"). Track the count in your own working notes — never in shell variables, which do not persist between Bash calls. A call that fails **quickly** with no check output (auth, network, or `gh` error) is not a cut-off and consumes no budget: retry it once, and if it fails again → **route-and-stop** (reason: "cannot read CI status: {error}").
    4. **No-checks guard:** if `gh pr checks` reports no checks at all (immediate exit / "no checks reported"), never conclude from timing — back-to-back re-checks cannot outlast GitHub's post-push registration window. Decide on evidence:
       - **No CI configured** — no workflow files exist (`.github/workflows/` absent or empty) **and** no required status checks are configured on the base branch (probe `gh api repos/{owner}/{repo}/branches/{base}/protection/required_status_checks`; a 404 means none; any other error — e.g. a 403 on a token without admin read — means *unknown*, so decide on the workflow-files evidence alone). Treat CI as settled ("no CI configured") and record that in the run summary.
       - **CI configured but checks not yet registered** — workflow files exist. Look up the run for this head SHA: `gh run list --commit $(git rev-parse HEAD) --limit 1 --json databaseId,status`. If a run appears, block on it with `gh run watch {databaseId}` under the same max tool timeout (a cut-off counts against `CYCLES`), then re-run the step-2 watch to read the check results. If no run appears after a handful of list retries → **route-and-stop** (reason: "CI is configured but no run appeared for {sha}") — park, never a false green.
  - Then re-fetch review comments (`gh api repos/{owner}/{repo}/pulls/{PR_NUMBER}/comments`) and PR reviews. New reviewer comments — **id above `H`**, not authored by the PR author (e.g. Copilot/Claude bot reviews) — are **new actionable threads** for the next pass. Capturing `H` before the push is what lets a bot review posted in response to this push count as new rather than being mistaken for an already-handled thread.

**4d. Recompute "clean".** The pass is **clean** when **both** hold:
  - zero unresolved actionable reviewer threads (nothing new and nothing still open from before), **and**
  - CI is green (every required check passed).

**4e. Decide.**
  - **clean** → break out of the loop; continue to Step 5.
  - a `needs-human` item surfaced → **route-and-stop**.
  - **pass cap hit and still not clean** → **route-and-stop** (reason: "still not clean after {max_feedback_passes} feedback passes: {what remains}").

---

## Step 5: Finish the ticket

Run the finish-ticket step via `run_step` — `/ccmagic:finish-ticket` with the grounding block. Its Step 3 sanity check is the **merge gate**: it merges only if the PR is mergeable, CI is green, and there are no unaddressed change-requests.

- `done` → the PR merged and the ticket moved to Done. Continue to Step 6 with outcome **merged**.
- `needs-human` → the gate wasn't satisfied. It did **not** merge → **route-and-stop** (stage = `finish-ticket`, reason: its blockers).

---

## Step 6: Post the run summary

Whatever the outcome, record it on the PR and the ticket so the unattended run leaves an audit trail.

```markdown
## 🤖 Autonomous run summary — {TICKET-ID}

**Outcome:** {✅ Merged into `{base}` | 🅿️ Parked — needs human}
**PR:** {pr_url}
**Run:** {run_id}
**Requested state:** {Done | needs_human_state} *(prompt-relay only — omit under mcp)*

### What ran
- Classified as **{class}**, branched, implemented, opened the PR.
- Review: {clean first pass | N CRITICAL findings fixed and re-reviewed}.
- PR feedback: {P} pass(es) — applied {A}, declined {D}, deferred {F}.
- Finish: {merged with {squash|merge commit} | gate not satisfied}.

### Key autonomous decisions
- {classification + reasoning}
- {any minor implementation choices made instead of asking}
- {out-of-scope changes flagged, if any}

### Follow-ups {filed | to file (prompt-relay)}
- {ticket ids + one-liners, or "none"}

### If parked
**Waiting on:** {the reason}. Nothing was merged. Resolve it, then re-run `/ccmagic:auto-ticket {TICKET-ID}`.
```

**Idempotency guard:** before posting to any surface, list its existing comments (`gh pr view {PR_NUMBER} --json comments --jq '.comments[].body'` for the PR; the tracker's comment list for the ticket) and **skip that surface** if a `🤖 Autonomous run summary` comment carrying this `run_id` already exists. Re-running Step 6 **within a single orchestrator context** — the same forked run reaching this step more than once — must never double-post. (Any fresh invocation of `/ccmagic:auto-ticket` — including a restart after a crash — mints a new `run_id` in Step 0 and posts its own summary; that is intentional — each run leaves its own audit trail.)

- **Merged (mcp transport)** → post the summary as a PR comment and a ticket comment, then report the final status to the user.
- **Parked (mcp transport)** → the summary is folded into the parked-comment posted by route-and-stop (contract §4); don't double-post.
- **Under prompt-relay (contract §7)** → do **not** attempt a ticket comment (there is no Linear API in the environment).
  - **Merged** → still post the summary as a PR comment via `gh`, then emit that same summary as this skill's **own final top-level output**, ending with the delimited final-message block (the `=== FINAL MESSAGE TO RELAY (reproduce verbatim) ===` / `=== END FINAL MESSAGE ===` wrapper, contract §7). Carry the intent line `Requested state: Done` — sourced from the step handshakes' `requested_state:` fields (contract §3) — and any "Follow-ups to file" list into that summary.
  - **Parked** → route-and-stop has already produced the parked note and posted it to the PR (contract §4, prompt-relay branch); emit that same note as the single top-level final message, wrapped in the same delimiters.
  - *Why this shape:* only the orchestrator's top-level output is relayed to the tracker — per-step subagent output stays internal — so the summary must be **this** skill's final message, not a sub-skill's.

---

## Route-and-stop

The single early-exit routine, defined in `${CLAUDE_SKILL_DIR}/autonomous-contract.md` §4. In short: **do not merge**; move the ticket to `needs_human_state` (fall back to `needs_human_label` if the state doesn't exist); comment the exact reason on the PR **and** the ticket using the parked-comment template; emit a clear final status; exit. Call it — with the failing stage and the sub-skill's `reason` — at every `needs-human`, at the feedback-pass cap, and whenever CI/validation can't be made green within bounds.

Every run ends in exactly one of two states:

| Outcome | Meaning |
|---------|---------|
| **merged** | PR merged, ticket Done, summary posted. |
| **parked-needs-human** | Not merged, ticket in `needs_human_state` (or labeled), reason posted. |

There is no third "stalled" outcome. Never hang waiting for input.

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
| `route-and-stop` can't move state (no matching state) | **mcp:** apply `needs_human_label`, leave state unchanged, still post the comment (contract §4). **prompt-relay:** contract §4's prompt-relay branch applies — no state/label writes; PR comment + relayed parked note. |

---

## Notes

- **Backlog selector (future).** This skill is deliberately single-ticket: give it a ticket, it drives that ticket. A future backlog-triage/selector skill can call `/ccmagic:auto-ticket {ID}` once per chosen ticket; nothing here assumes it is the top of the stack. Do not build the selector here.
- **Headless harnesses.** A headless harness that injects the ticket into the invocation and relays the session's final output back to the tracker — with no tracker MCP in the environment — is supported via the **prompt-relay transport** (contract §7): detection is content-presence, tracker writes collapse to the single relayed final message, and the GitHub/PR half of the cycle runs on `gh` as usual. Deployment prerequisites and the required prompt template live in `docs/cyrus-deployment.md`.
- **Additivity.** This skill only ever invokes sub-skills in autonomous mode; it never alters their interactive paths.
