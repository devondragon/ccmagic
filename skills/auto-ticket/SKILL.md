---
name: auto-ticket
description: Autonomous end-to-end ticket driver. Runs the full work → review → PR-feedback → finish cycle unattended, merging when the work is clean and CI is green, or parking the ticket (needs-human) with a clear note when a decision genuinely requires a human. Detects the tracker (Linear, GitHub Issues, JIRA) and ticket from the argument or current branch.
user-invocable: true
allowed-tools: Read(*), Edit(*), Bash(git:*, gh:*), Glob(*), Grep(*), Task(*), TodoWrite(*), Skill(*)
argument-hint: "[TICKET-ID] (detects from the current branch if omitted)"
model: sonnet
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

## Step 0: Resolve tracker, ticket, and config

1. **Resolve the tracker** using the exact same cascade as `/ccmagic:work-ticket` Step 0 (settings → arg/branch shape → MCP probe → CLI probe → branch hint). This runs unattended, so if the cascade is genuinely ambiguous (would otherwise prompt), pick the highest-confidence candidate and record the choice in the run summary; if **none** is available, stop and tell the user (this is a setup error, not a parkable ticket).
2. **Resolve the ticket ID** from the argument, or parse it from the current branch (strip `feature/`, `bugfix/`, `hotfix/`, `chore/` prefixes) — same logic as `/ccmagic:finish-ticket` Step 1. If neither yields a ticket ID, stop and ask the user for one.
3. **Load config** from `.claude/ccmagic.local.md`: `needs_human_state`, `needs_human_label` (default `needs-human`), `max_feedback_passes` (default `3`), plus the usual `tracker` / `ticket_url_base` / `github_repo`. See contract §5.
4. **Fetch the ticket** to confirm it exists (per the tracker's lookup in `work-ticket`/`review-ticket`). If not found, stop (Sacred Rule).
5. **Build the grounding block** (contract §2) with the resolved values. Prepend it to every sub-skill invocation below. `/ccmagic:auto-ticket` always drives sub-skills with `autonomous: true`, regardless of the `autonomous:` config default.

Create a TodoWrite entry per stage (work → review → feedback loop → finish → summary) so progress is visible during a long unattended run.

---

## Step 1: Work the ticket

Invoke `/ccmagic:work-ticket {TICKET-ID}` with the grounding block prepended.

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

Invoke `/ccmagic:review-ticket {TICKET-ID}` with the grounding block prepended. Then act on the verdict:

- `clean` → continue to Step 4.
- `needs-human` → **route-and-stop** (stage = `review-ticket`).
- `fixable-findings` → run a **bounded fix loop** (max **2** passes):
  1. Apply the CRITICAL findings (and any listed fixable missing-AC items) from the report — edit the code directly.
  2. Commit and push via `/ccmagic:push` with the grounding block. If push returns `needs-human`, **route-and-stop**.
  3. Re-invoke `/ccmagic:review-ticket`.
  4. `clean` → continue to Step 4. `fixable-findings` again and passes remain → repeat. Passes exhausted still not clean, or `needs-human` → **route-and-stop** (reason: the outstanding findings).

Only CRITICAL findings and closable missing-AC items gate here. Out-of-scope changes are flagged in the PR (review-ticket already posts them) and do not block.

---

## Step 4: PR-feedback loop

Loop up to `max_feedback_passes` (default 3). Each pass:

**4a. Apply feedback.** Invoke `/ccmagic:pr-feedback {PR_NUMBER}` with the grounding block. Autonomous `pr-feedback` applies address-now fixes, replies to declined/question threads, files a follow-up ticket per defer/out-of-scope item, and pushes. Collect its handshake counts and `follow_ups`.
  - `needs-human` (e.g. a genuine reviewer tie) → **route-and-stop** (stage = `pr-feedback`).

**4b. Validate locally before trusting CI.** Run `/ccmagic:validate`. If it fails, fix the regressions (bounded: **2** attempts, editing + re-validating), then commit/push via `/ccmagic:push`. If it still fails after the attempts → **route-and-stop** (reason: "local validation fails: {summary}"). Doing this locally keeps CI + bot-review round-trips rare.

**4c. Wait for CI and new reviews.** Before this pass's push, record the highest PR review-comment id as a high-water mark. After pushing:
  - Poll CI until it settles — no check is `pending`/`in_progress`:
    ```bash
    gh pr checks {PR_NUMBER}
    ```
    Poll on a modest interval (≈60s) up to a cap (≈30 min). If CI never settles within the cap → **route-and-stop** (reason: "CI did not complete within the timeout").
  - Then re-fetch review comments (`gh api repos/{owner}/{repo}/pulls/{PR_NUMBER}/comments`) and PR reviews. New reviewer comments (id above the high-water mark, not authored by the PR author — e.g. Copilot/Claude bot reviews) are **new actionable threads** for the next pass.

**4d. Recompute "clean".** The pass is **clean** when **both** hold:
  - zero unresolved actionable reviewer threads (nothing new and nothing still open from before), **and**
  - CI is green (every required check passed).

**4e. Decide.**
  - **clean** → break out of the loop; continue to Step 5.
  - a `needs-human` item surfaced → **route-and-stop**.
  - **pass cap hit and still not clean** → **route-and-stop** (reason: "still not clean after {max_feedback_passes} feedback passes: {what remains}").

---

## Step 5: Finish the ticket

Invoke `/ccmagic:finish-ticket` with the grounding block. Its Step 3 sanity check is the **merge gate**: it merges only if the PR is mergeable, CI is green, and there are no unaddressed change-requests.

- `done` → the PR merged and the ticket moved to Done. Continue to Step 6 with outcome **merged**.
- `needs-human` → the gate wasn't satisfied. It did **not** merge → **route-and-stop** (stage = `finish-ticket`, reason: its blockers).

---

## Step 6: Post the run summary

Whatever the outcome, record it on the PR and the ticket so the unattended run leaves an audit trail.

```markdown
## 🤖 Autonomous run summary — {TICKET-ID}

**Outcome:** {✅ Merged into `{base}` | 🅿️ Parked — needs human}
**PR:** {pr_url}

### What ran
- Classified as **{class}**, branched, implemented, opened the PR.
- Review: {clean first pass | N CRITICAL findings fixed and re-reviewed}.
- PR feedback: {P} pass(es) — applied {A}, declined {D}, deferred {F}.
- Finish: {merged with {squash|merge commit} | gate not satisfied}.

### Key autonomous decisions
- {classification + reasoning}
- {any minor implementation choices made instead of asking}
- {out-of-scope changes flagged, if any}

### Follow-ups filed
- {ticket ids + one-liners, or "none"}

### If parked
**Waiting on:** {the reason}. Nothing was merged. Resolve it, then re-run `/ccmagic:auto-ticket {TICKET-ID}`.
```

- **Merged** → post the summary as a PR comment and a ticket comment, then report the final status to the user.
- **Parked** → the summary is folded into the parked-comment posted by route-and-stop (contract §4); don't double-post.

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
| Ticket ID can't be resolved | Stop and ask the user for one. |
| Ticket not found | Stop (Sacred Rule). |
| A sub-skill emits no handshake (crash/tool error) | Treat as `needs-human` → route-and-stop with reason "{skill} produced no handshake". |
| `work-ticket` → `needs-human` | route-and-stop (stage `work-ticket`). |
| `review-ticket` → `needs-human`, or `fixable-findings` unresolved after the bounded loop | route-and-stop (stage `review-ticket`). |
| `pr-feedback` → `needs-human` (genuine reviewer tie) | route-and-stop (stage `pr-feedback`). |
| Local `/ccmagic:validate` can't be made green within the bounded attempts | route-and-stop (reason: validation failures). |
| CI never settles within the poll cap | route-and-stop (reason: CI timeout). |
| Feedback-pass cap hit still not clean | route-and-stop (reason: remaining threads / red CI). |
| `finish-ticket` merge gate not satisfied | It returns `needs-human` and does not merge → route-and-stop (stage `finish-ticket`). |
| `route-and-stop` can't move state (no matching state) | Apply `needs_human_label`, leave state unchanged, still post the comment (contract §4). |

---

## Notes

- **Backlog selector (future).** This skill is deliberately single-ticket: give it a ticket, it drives that ticket. A future backlog-triage/selector skill can call `/ccmagic:auto-ticket {ID}` once per chosen ticket; nothing here assumes it is the top of the stack. Do not build the selector here.
- **Cyrus / headless.** With `autonomous: true` in `.claude/ccmagic.local.md` and a Linear-triggered invocation, the whole cycle runs with no TTY. Because every gate resolves to merge-or-park and nothing prompts, the run is safe to launch from Cyrus's Dockerized worker.
- **Additivity.** This skill only ever invokes sub-skills in autonomous mode; it never alters their interactive paths.
