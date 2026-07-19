# Auto-ticket field-run hardening — design

**Date:** 2026-07-18
**Status:** Approved — pending implementation
**Target version:** 3.4.0

## Background

Two retrospectives of real-world `/ccmagic:auto-ticket` runs surfaced concrete weaknesses:

- **Run A (parked):** the safety property held — the run parked instead of merging a latent one-year-cache bug — but the review-fix loop reasoned about *instances*, not *defect classes*. Pass 1 point-fixed one non-fingerprinted `/js` reference (a Thymeleaf `th:src`) while a second instance of the same class (an ES-module import reachable from 8 modules) survived to pass 2. It was only caught because `max_review_fix_passes: 2` left a pass to spend. The pass-1 reviewer also issued an unscoped all-clear ("All 40 other references use `@{...}`") from a template-only grep, and the work step wrote the safety premise ("every /js asset is fingerprinted") into a code comment while the repo violated it.
- **Run B (stalled):** the run silently hung at the Step 4c CI wait — the exact "third stalled outcome" the contract promises never happens. Structural cause: Step 4c says "poll every 60s up to 30 min," but the orchestrator's toolset has no executable wait mechanism (foreground sleep is blocked in the harness; no Monitor/ScheduleWakeup). Collateral: the Step 6 run summary was never posted. Separately, finish-ticket's `--delete-branch` failed noisily in a worktree-per-ticket checkout.

This design fixes both failure classes plus approved polish items. Everything is additive or autonomous-path-only, per the contract's additivity invariant — no interactive gate changes.

## Changes

### 1. Executable CI wait (critical — fixes the Run B stall)

**Files:** `skills/auto-ticket/SKILL.md` (Step 4c + error-handling table), `skills/auto-ticket/autonomous-contract.md` (§5), `docs/auto-ticket-per-step-subagents-design.md` (new section).

Replace the unexecutable "poll every `ci_poll_interval_seconds`" instruction with a bounded blocking watch:

- Compute the watch budget: `CYCLES = ceil(ci_timeout_minutes / 10)` (default 30 min → 3 invocations).
- Loop: invoke `gh pr checks {PR_NUMBER} --watch --interval {ci_poll_interval_seconds}` as a **single Bash call with the maximum tool timeout (600000 ms)**. `--watch` blocks until no check is pending, so each call either returns "settled" or is cut off by the tool timeout. A non-zero exit with completed checks in the output is still "settled" — settled-with-failures — and proceeds to the next step rather than re-invoking the watch.
- On tool timeout: it consumed a full 10 minutes by construction — count it. Fewer than `CYCLES` cut-off calls so far → re-invoke the watch; `CYCLES` reached → **route-and-stop** (reason: CI timeout) exactly as today. The count is tracked in working notes, not shell variables — shell state does not persist between Bash calls.
- **No-checks guard:** if `gh pr checks` reports no checks at all (exit immediately / "no checks reported"), re-check up to 3 times — this covers the registration race just after a push — then treat as "no CI configured → settled" and record that in the run summary. The finish-ticket merge gate re-verifies `statusCheckRollup` before merging, so it remains the backstop.

Contract §5: update the `ci_poll_interval_seconds` description to "interval passed to `gh pr checks --watch`". SKILL.md Step 4c and the error-handling row are rewritten to match; no config keys are added or removed.

Design doc: add a short "CI wait mechanism" section to `docs/auto-ticket-per-step-subagents-design.md` documenting the mechanism and why (the previously undesigned async step).

### 2. Idempotent run summary

**Files:** `skills/auto-ticket/SKILL.md` (Step 6).

- Add a `**Run:** {run_id}` line to the run-summary template.
- Before posting, fetch existing PR comments and skip posting if a `🤖 Autonomous run summary` comment carrying this `run_id` already exists (same idempotency check for the ticket comment on the mcp transport).
- The orchestrator remains the single writer; fixing Change 1 is what guarantees Step 6 is reached.

### 3. Systemic-finding enumeration + scoped all-clears (fixes Run A whack-a-mole)

**Files:** `skills/review/finding-schema.md`, `skills/review/agent-instructions.md`, `skills/review-ticket/SKILL.md`, `skills/auto-ticket/SKILL.md` (Step 3).

- **Finding schema:** add an optional `systemic:` field. When an issue is an instance of a repeatable pattern, the agent states the defect *class* and enumerates **every** instance found, searching across *all reference mechanisms that could carry the pattern* (e.g. template attributes, raw attributes, ES-module imports, CSS `@import`/`url()`, manifests, service workers, config files — whichever fit the class), not just the mechanism of the first hit.
- **Scoped all-clear rule** (review agent instructions + review-ticket): any "no other instances" claim must state its search scope and the mechanisms covered, or be downgraded to "no other {mechanism} instances found". Unscoped universal claims are more dangerous than silence in an autonomous loop that acts on verdicts.
- **auto-ticket Step 3 fix loop:** a `systemic`-tagged finding is fixed **as a class** — apply the fix to every enumerated instance, then re-run the enumeration search to catch stragglers, before re-review. Never point-fix only the reported line.

### 4. Invariant self-check

**Files:** `skills/work-ticket/SKILL.md` (Step 6).

Add to scope validation (applies in both interactive and autonomous modes): identify any invariant the change's correctness or safety depends on — *especially one the change itself asserts in comments, docs, or the PR body* — and verify it holds repo-wide with a search before shipping. A violated invariant is a gap: close it, or (autonomous) `needs-human`. Rationale: catching a self-inflicted premise violation at the work stage costs one grep; catching it at review costs fix-loop passes or a park.

### 5. Worktree-aware branch cleanup

**Files:** `skills/finish-ticket/SKILL.md` (Step 6 + error-handling table).

- Detect a linked-worktree checkout before merging: `git rev-parse --path-format=absolute --git-dir` ≠ `git rev-parse --path-format=absolute --git-common-dir` (unnormalized paths falsely report `worktree` from a primary checkout's subdirectory, since `--git-dir` prints absolute and `--git-common-dir` prints relative).
- In a worktree: merge **without** `--delete-branch`; best-effort delete the remote branch (`git push origin --delete {headRefName}`, ignore failure); leave the local worktree and branch in place; mention it in the final report ("Worktree: left in place at {path}"). No warnings, no errors — this is a normal solo-dev setup, not a failure.
- New error-handling row: `--delete-branch` fails for any local-checkout reason → verify the merge succeeded, clean up the remote branch, report gracefully.
- Second error-handling row: conflict resolution's git checkout failing with "is already used by worktree at" → run the same conflict-resolution commands from that worktree path instead, then re-attempt the merge — not an error.

### 6. Delta re-reviews

**Files:** `skills/auto-ticket/autonomous-contract.md` (§2), `skills/auto-ticket/SKILL.md` (Step 3), `skills/review-ticket/SKILL.md` (autonomous mode).

- Grounding block gains an optional `review_pass: {n}` line; auto-ticket sets it when re-invoking review-ticket in the Step 3 fix loop.
- On those re-invocations, the grounding block also gains a `previous_findings:` section — the findings auto-ticket just applied in the fix loop (id/title + file) — so the fresh review subagent (a new context, with no memory of the prior pass) knows exactly what to verify as fixed.
- When `review_pass` ≥ 2, review-ticket posts a **delta report**: each `previous_findings:` entry verified and reported fixed/not-fixed as one-liners, net-new findings in full, the previous report referenced rather than repeated (fetched via `gh pr view --json comments` if needed). The handshake/verdict semantics are unchanged.
- review-ticket posts its report (full or delta) as a PR comment via `gh pr comment` on every pass, so each pass leaves a retrievable artifact for the next one to reference — conditional on a PR existing (a standalone pre-PR review has no PR to comment on and skips posting), and this report post subsumes the Step 7 out-of-scope comment rather than duplicating it.

### 7. Risk-ordering scoping note

**Files:** `skills/work-ticket/SKILL.md` (Step 5, Complex Feature guidance).

When narrowing a broad ticket into a shippable slice: prefer shipping the lower-risk slice first, and when the retained slice introduces a new latent-failure mode (aggressive caching policy, destructive migration, auth changes), flag that explicitly in the PR body.

### 8. Agent `tools:` allowlists

**Files:** `agents/auto-*.md` (all six).

Standardize on explicit `tools:` allowlists so each agent's capability boundary is glanceable, and enforce boundaries the prose currently only requests:

| Agent | Allowlist | Notes |
|-------|-----------|-------|
| `auto-work` | Read, Write, Edit, Bash, Glob, Grep, Task, TodoWrite | Broad — implements code. |
| `auto-review` | Read, Write, Bash, Glob, Grep, Task, TodoWrite | **No Edit** — must not mutate code. Write is permitted solely for `context/review-stats.json` (state this in the body). |
| `auto-feedback` | Read, Write, Edit, Bash, Glob, Grep, Task, TodoWrite | Applies fixes, replies, pushes. Task retained — the pr-feedback procedure declares `Task(*)` itself. |
| `auto-validate` | Read, Bash, Glob, Grep, Task | Unchanged. |
| `auto-finish` | Read, Edit, Bash, Glob, Grep | Edit for trivial conflict resolution; no Task (as today). |
| `auto-push` | Read, Bash, Glob, Grep, Write | Unchanged. |

Preloaded `skills:` lists are unchanged. The `disallowedTools: Skill` intent (never re-invoke skills) moves into the allowlists (Skill simply absent) — keep the body instruction "do not re-invoke as a skill".

### 9. `max_review_fix_passes` default 2 → 3

**Files:** `skills/auto-ticket/autonomous-contract.md` (§5), `skills/auto-ticket/SKILL.md` (Step 0 + Step 3), `docs/ccmagic.local.md.example`.

Run A only caught the second instance because a pass remained. Change 3 addresses the root cause; the bump is deliberate headroom so a systemic class never merges for lack of one pass.

### Housekeeping

- Bump plugin version to **3.4.0** in `.claude-plugin/plugin.json` (and marketplace.json if it carries a version).
- README: touch the auto-ticket section where behavior is described (CI wait, review-fix loop, defaults).

## Non-goals

- **No relocation of the CI wait into finish-ticket** — Step 4c's new-bot-review detection (high-water-mark `H`) requires CI/reviews to settle *inside* the feedback loop.
- **No Monitor/ScheduleWakeup grant** — harness-specific and unproven inside a forked subagent.
- **No contract/SKILL token trim** in this pass.
- **No interactive-path behavior changes** — additivity invariant holds.
- **No backlog selector** — out of scope as before.

## Acceptance criteria

1. Step 4c contains no instruction that requires an unavailable wait primitive; the watch loop is expressible with `Bash(gh:*)` alone, with no cross-call shell state.
2. A re-run of Run B's shape (push → CI wait → finish) reaches Step 6 and posts exactly one summary per `run_id`, even if Step 6 executes twice.
3. A finding of the Run A shape (pattern with multiple reference mechanisms) forces enumeration across mechanisms in the report, and the Step 3 loop fixes the full class before re-review.
4. finish-ticket in a linked worktree merges cleanly, deletes the remote branch, and exits without error while the worktree remains.
5. Every `agents/auto-*.md` has an explicit `tools:` allowlist matching the table above; `auto-review` has no Edit.
6. All defaults/docs (`contract §5`, SKILL.md, ccmagic.local.md.example, README) agree on `max_review_fix_passes: 3` and the new CI-wait semantics.
