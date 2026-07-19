# Auto-ticket Field-Run Hardening — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the nine approved changes from `docs/auto-ticket-field-hardening-design.md` — executable CI wait, idempotent run summary, systemic-finding enumeration, invariant self-check, worktree-aware cleanup, delta re-reviews, risk-ordering note, agent tool allowlists, and the `max_review_fix_passes` bump.

**Architecture:** All changes are markdown edits to skill instructions, the shared autonomous contract, agent frontmatter, and docs. No code, no runnable tests — each task's verification is exact `grep` checks proving the edit landed and no stale text remains. Tasks are ordered so tasks touching the same file regions (auto-ticket Step 3 is touched by Tasks 3, 4, 7) run sequentially.

**Tech Stack:** Markdown skill files (Claude Code plugin format), YAML frontmatter, git.

## Global Constraints

- Everything is **additive or autonomous-path-only** — never change an interactive gate's behavior (contract §6 additivity invariant).
- Skill files must stay **under 500 lines** (`.claude/CLAUDE.md` rule).
- Commit format: `{TYPE}({scope}): {description}` — imperative, ≤72 chars, no ticket ID (this repo uses none). One commit per task.
- Work happens on branch `feature/auto-ticket-field-hardening` (already created; design doc committed as `ceb3f65`).
- The design doc `docs/auto-ticket-field-hardening-design.md` is the spec. If an instruction here conflicts with the current file content (drift), re-read the file and adapt the edit to preserve the design intent — do not force a stale `old_string`.

---

### Task 1: Executable CI wait

**Files:**
- Modify: `skills/auto-ticket/SKILL.md` (Step 4c, ~lines 124–130; error-handling table ~line 218)
- Modify: `skills/auto-ticket/autonomous-contract.md` (§5 table, ~line 131)
- Modify: `docs/auto-ticket-per-step-subagents-design.md` (append new section after "## Behavior changes")

**Interfaces:**
- Produces: the phrase "bounded blocking watch" and the `gh pr checks {PR_NUMBER} --watch --interval {ci_poll_interval_seconds}` command — Task 9 greps for these.

- [ ] **Step 1: Rewrite Step 4c's poll bullet in `skills/auto-ticket/SKILL.md`**

Replace this text:

```markdown
  - Poll CI until it settles — no check is `pending`/`in_progress`:
    ```bash
    gh pr checks {PR_NUMBER}
    ```
    Poll on `ci_poll_interval_seconds` (default ≈60s) up to `ci_timeout_minutes` (default ≈30 min). If CI never settles within the cap → **route-and-stop** (reason: "CI did not complete within the timeout").
```

with:

```markdown
  - **Wait for CI to settle** — no check `pending`/`in_progress` — using a **bounded blocking watch**. (A sleep-based poll loop is not executable in this context: the orchestrator has no wait primitive. The blocking watch below is.)
    1. Compute the watch budget: `CYCLES = ceil(ci_timeout_minutes / 10)` (default 30 min → 3 watch invocations).
    2. Run the watch as a single Bash call **with the maximum tool timeout (600000 ms)**:
       ```bash
       gh pr checks {PR_NUMBER} --watch --interval {ci_poll_interval_seconds}
       ```
       `--watch` blocks until no check is pending, so each call either returns with CI settled or is cut off by the 10-minute tool timeout.
    3. If the call was cut off by the tool timeout, it consumed a full 10 minutes by construction — count it. Fewer than `CYCLES` cut-off calls so far → re-invoke the watch (step 2). `CYCLES` reached → **route-and-stop** (reason: "CI did not complete within the timeout"). Track the count in your own working notes — never in shell variables, which do not persist between Bash calls.
    4. **No-checks guard:** if `gh pr checks` reports no checks at all (immediate exit / "no checks reported"), re-check up to 3 times — checks can register a few seconds after a push. Still none → treat CI as settled ("no CI configured"), record that in the run summary, and rely on finish-ticket's merge-gate `statusCheckRollup` re-verification as the backstop.
```

- [ ] **Step 2: Update the error-handling row in the same file**

Replace:

```markdown
| CI never settles within the poll cap | route-and-stop (reason: CI timeout). |
```

with:

```markdown
| CI never settles within `ci_timeout_minutes` (watch loop cap) | route-and-stop (reason: CI timeout). |
```

- [ ] **Step 3: Update contract §5 in `skills/auto-ticket/autonomous-contract.md`**

Replace:

```markdown
| `ci_poll_interval_seconds` | int | `60` | Interval between CI status polls (orchestrator Step 4c). |
```

with:

```markdown
| `ci_poll_interval_seconds` | int | `60` | Interval passed to `gh pr checks --watch` during the CI wait (orchestrator Step 4c). |
```

- [ ] **Step 4: Append a "CI wait mechanism" section to `docs/auto-ticket-per-step-subagents-design.md`**

Read the file first; insert this section between "## Behavior changes" and "## Risks to validate during implementation" (adapt placement if those headings moved):

```markdown
## CI wait mechanism (added after field-run B, 2026-07)

The one long-latency step in the run — Step 4c's "wait for CI" — was originally specced as a 60s poll loop, which is not executable: the orchestrator runs as a forked subagent whose toolset (`Read, Edit, Bash(git/gh), Glob, Grep, Task, TodoWrite, Skill`) has no wait primitive, and foreground sleep is blocked in the harness. In field-run B the fork returned control and the run silently stalled — the "third outcome" contract §6 promises never happens.

The mechanism is now a **bounded blocking watch**: `gh pr checks {PR} --watch --interval {ci_poll_interval_seconds}` invoked as a single Bash call at the maximum tool timeout (600000 ms), re-invoked up to ⌈`ci_timeout_minutes`/10⌉ times — each cut-off call consumed its full 10-minute cap by construction, so an invocation count tracks elapsed time without cross-call shell state (which does not persist between Bash calls) — then route-and-stop on timeout. `--watch` blocks inside one Bash call, which *is* executable in a forked subagent, portable to headless/Cyrus deployments (needs only `gh`), and stays inside the already-allowed `Bash(gh:*)` surface. A no-checks guard (re-check up to 3×, then treat as "no CI configured") covers the check-registration race just after a push; finish-ticket's merge gate re-verifies `statusCheckRollup` as the backstop.

The wait deliberately stays in Step 4c (not finish-ticket): the feedback loop's new-bot-review detection (high-water-mark `H`) needs CI and reviews to have settled *inside* the loop.
```

- [ ] **Step 5: Verify**

Run: `grep -rn "Poll on \`ci_poll_interval_seconds\`\|Poll CI until" skills/` — Expected: no matches.
Run: `grep -c "watch --interval" skills/auto-ticket/SKILL.md` — Expected: `1` (or more).
Run: `grep -c "CI wait mechanism" docs/auto-ticket-per-step-subagents-design.md` — Expected: `1`.

- [ ] **Step 6: Commit**

```bash
git add skills/auto-ticket/SKILL.md skills/auto-ticket/autonomous-contract.md docs/auto-ticket-per-step-subagents-design.md
git commit -m "fix(auto-ticket): make Step 4c CI wait executable via gh pr checks --watch"
```

*Amended during execution: elapsed tracking switched from `date +%s` to an invocation counter — shell state does not persist across Bash calls.*

---

### Task 2: Idempotent run summary

**Files:**
- Modify: `skills/auto-ticket/SKILL.md` (Step 6 template ~line 156, posting rules ~line 181)

- [ ] **Step 1: Add the run_id line to the summary template**

In the Step 6 template, replace:

```markdown
**Outcome:** {✅ Merged into `{base}` | 🅿️ Parked — needs human}
**PR:** {pr_url}
```

with:

```markdown
**Outcome:** {✅ Merged into `{base}` | 🅿️ Parked — needs human}
**PR:** {pr_url}
**Run:** {run_id}
```

- [ ] **Step 2: Add the idempotency guard before the posting bullets**

Immediately before the line starting `- **Merged (mcp transport)** →`, insert:

```markdown
**Idempotency guard:** before posting to any surface, list its existing comments (`gh pr view {PR_NUMBER} --json comments --jq '.comments[].body'` for the PR; the tracker's comment list for the ticket) and **skip that surface** if a `🤖 Autonomous run summary` comment carrying this `run_id` already exists. Re-running Step 6 within the same run — after a resume or retry — must never double-post. (A fresh invocation mints a new `run_id` and posts its own summary; that is intentional — each run leaves its own audit trail.)
```

- [ ] **Step 3: Verify**

Run: `grep -c "Run:.*{run_id}" skills/auto-ticket/SKILL.md` — Expected: `1`.
Run: `grep -c "Idempotency guard" skills/auto-ticket/SKILL.md` — Expected: `1`.

- [ ] **Step 4: Commit**

```bash
git add skills/auto-ticket/SKILL.md
git commit -m "feat(auto-ticket): idempotent Step 6 run summary keyed by run_id"
```

*Amended during execution: guard claim scoped to same-run re-execution — a fresh invocation mints a new run_id by design.*

---

### Task 3: Systemic-finding enumeration + scoped all-clears

**Files:**
- Modify: `skills/review/finding-schema.md` (schema block + explanation)
- Modify: `skills/review/agent-instructions.md` (read first; add rules to the agent prompt instructions)
- Modify: `skills/review-ticket/SKILL.md` (end of Step 4)
- Modify: `skills/auto-ticket/SKILL.md` (Step 3 fix-loop item 1, ~line 100)

**Interfaces:**
- Produces: the `systemic:` schema field name and the phrase "scoped all-clear" — Tasks 7 and 9 reference them.

- [ ] **Step 1: Add the `systemic` field to `skills/review/finding-schema.md`**

In the schema's fenced output-format block, append this line directly after the `- fixable:` line (currently the last field):

```markdown
- systemic: <optional — present only when the issue is an instance of a repeatable pattern: name the defect class, then enumerate EVERY instance found, searching across all reference mechanisms that could carry the pattern (template attributes, raw attributes, ES-module imports, CSS @import/url(), manifests, service workers, config files — whichever apply). Omit for one-off issues.>
```

Then, after the paragraph explaining `specialist`/`fixable` ("The `specialist` field enables… batched for user decision."), append:

```markdown
The `systemic` field prevents whack-a-mole fix loops — a point-fix to the reported line while sibling instances survive to the next review pass. When an issue is one instance of a pattern, the **enumeration is the finding**, not the first hit: search every mechanism that could carry the pattern, not just the syntax the first instance used. And scope your all-clears: a "no other instances" claim MUST state its search scope and the mechanisms covered, or be downgraded to "no other {mechanism} instances found". An unscoped universal claim is more dangerous than silence in an autonomous loop that acts on verdicts.
```

- [ ] **Step 2: Add the same two rules to `skills/review/agent-instructions.md`**

Read the file. Find the section instructing agents on how to report findings (where the finding schema is referenced) and append this block in the same style as neighboring instructions:

```markdown
**Systemic findings.** When a finding is an instance of a repeatable pattern, enumerate all instances across every reference mechanism that could carry the pattern (template attributes, raw attributes, ES-module imports, CSS @import/url(), manifests, service workers, config files) and fill the `systemic:` schema field with the class name + enumeration. Never report just the first instance of a pattern.

**Scoped all-clears.** Any "no other instances" / "this is the only one" claim must state its search scope and the mechanisms covered — otherwise downgrade it to "no other {mechanism} instances found".
```

- [ ] **Step 3: Add the rules to `skills/review-ticket/SKILL.md`**

At the end of Step 4 ("Run ticket-scope drift analysis"), after the "Hold this analysis…" line, append:

```markdown
**Systemic findings.** When any finding — drift or code-quality — is an instance of a repeatable pattern, enumerate all instances across every reference mechanism that could carry the pattern (template attributes, raw attributes, ES-module imports, CSS `@import`/`url()`, manifests, service workers, config), not just the syntax of the first hit, and tag the finding `systemic:` per the review finding schema. Any "no other instances" claim must state its search scope and the mechanisms covered, or be downgraded to "no other {mechanism} instances found".
```

- [ ] **Step 4: Make auto-ticket's fix loop fix systemic findings as a class**

In `skills/auto-ticket/SKILL.md` Step 3, replace:

```markdown
  1. Apply the CRITICAL findings (and any listed fixable missing-AC items) from the report — edit the code directly.
```

with:

```markdown
  1. Apply the CRITICAL findings (and any listed fixable missing-AC items) from the report — edit the code directly. A `systemic:`-tagged finding is fixed **as a class**: apply the fix to every enumerated instance, then re-run the enumeration search yourself to catch stragglers — never point-fix only the reported line.
```

- [ ] **Step 5: Verify**

Run: `grep -rln "systemic" skills/review/finding-schema.md skills/review/agent-instructions.md skills/review-ticket/SKILL.md skills/auto-ticket/SKILL.md` — Expected: all four paths listed.
Run: `grep -c "no other {mechanism} instances found" skills/review/finding-schema.md skills/review/agent-instructions.md skills/review-ticket/SKILL.md` — Expected: `1` per file.

- [ ] **Step 6: Commit**

```bash
git add skills/review/finding-schema.md skills/review/agent-instructions.md skills/review-ticket/SKILL.md skills/auto-ticket/SKILL.md
git commit -m "feat(review): systemic-finding enumeration and scoped all-clear rules"
```

---

### Task 4: Bump `max_review_fix_passes` default to 3

**Files:**
- Modify: `skills/auto-ticket/autonomous-contract.md` (§5 table)
- Modify: `skills/auto-ticket/SKILL.md` (Step 0 item 3; Step 3 intro)
- Modify: `docs/ccmagic.local.md.example` (lines 59, 94)
- Modify: `README.md` (line 191)

- [ ] **Step 1: Contract §5** — replace `| `max_review_fix_passes` | int | `2` |` with `| `max_review_fix_passes` | int | `3` |` (rest of row unchanged).

- [ ] **Step 2: auto-ticket SKILL.md** — two replacements:
  - Step 0: `` `max_review_fix_passes` (default `2`) `` → `` `max_review_fix_passes` (default `3`) ``
  - Step 3: `(max `max_review_fix_passes` passes, default **2**)` → `(max `max_review_fix_passes` passes, default **3**)`

- [ ] **Step 3: docs/ccmagic.local.md.example** — `# max_review_fix_passes: 2` → `# max_review_fix_passes: 3`, and in the table `| `max_review_fix_passes` | … | `2` |` → `` `3` ``.

- [ ] **Step 4: README.md** — `# max_review_fix_passes: 2     # ticket-review fix loop` → `# max_review_fix_passes: 3     # ticket-review fix loop`.

- [ ] **Step 5: Verify**

Run: `grep -rn "max_review_fix_passes" skills/ docs/ README.md | grep -n "2"` — Expected: no matches showing a default of 2 (a `passes remain` phrase or unrelated 2s are fine — check each hit).

- [ ] **Step 6: Commit**

```bash
git add skills/auto-ticket/autonomous-contract.md skills/auto-ticket/SKILL.md docs/ccmagic.local.md.example README.md
git commit -m "feat(auto-ticket): bump max_review_fix_passes default to 3"
```

---

### Task 5: work-ticket invariant self-check + risk-ordering note

**Files:**
- Modify: `skills/work-ticket/SKILL.md` (Step 5 Complex Feature path ~line 183; Step 6 ~line 217)

- [ ] **Step 1: Add the risk-ordering note to Step 5**

In the Complex Feature path, after the blockquote `> If you want the multi-agent feature workflow…`, append a new paragraph:

```markdown
**Scoping a broad ticket:** when the ticket is too broad to ship whole and you narrow it to a slice (deferring the rest with rationale), prefer shipping the **lower-risk** slice first. If the retained slice introduces a new latent-failure mode — an aggressive caching policy, a destructive migration, an auth change — call that out explicitly in the PR body so reviewers and future readers see the risk you took on.
```

- [ ] **Step 2: Add the invariant self-check to Step 6**

After the line `Read the changed files to confirm the implementation aligns with the ticket.`, insert:

```markdown
**Invariant self-check.** Identify any invariant the change's correctness or safety depends on — *especially one the change itself asserts* in a comment, doc, or the PR body (e.g. "every /js asset is fingerprinted", "all callers hold the lock"). Verify each one actually holds repo-wide with a search across every mechanism that could violate it, before shipping. A violated invariant is a gap like any unmet acceptance criterion: close it, or surface it (autonomous mode: close it or `needs-human` — never ship on a premise the repo violates).
```

- [ ] **Step 3: Verify**

Run: `grep -c "Invariant self-check\|Scoping a broad ticket" skills/work-ticket/SKILL.md` — Expected: `2`.
Run: `wc -l skills/work-ticket/SKILL.md` — Expected: < 500.

- [ ] **Step 4: Commit**

```bash
git add skills/work-ticket/SKILL.md
git commit -m "feat(work-ticket): invariant self-check and risk-ordered scoping guidance"
```

---

### Task 6: finish-ticket worktree-aware branch cleanup

**Files:**
- Modify: `skills/finish-ticket/SKILL.md` (Step 6 "Attempt merge" ~line 253; error-handling table ~line 413; Step 8 report ~line 354)

- [ ] **Step 1: Rewrite "Attempt merge" with worktree detection**

Replace:

````markdown
### Attempt merge

```bash
gh pr merge {pr_number} {--squash | --merge} --delete-branch
```

Use the strategy flag chosen in Step 5 (`--squash` for feature/bugfix/hotfix/chore branches, `--merge` for `release/...`). If `--delete-branch` is not supported by the installed `gh` version, omit it.
````

with:

````markdown
### Attempt merge

First detect whether this checkout is a linked worktree (a worktree-per-ticket setup is normal, not an error):

```bash
[ "$(git rev-parse --path-format=absolute --git-dir)" != "$(git rev-parse --path-format=absolute --git-common-dir)" ] && echo worktree || echo primary
```

**Primary checkout:**

```bash
gh pr merge {pr_number} {--squash | --merge} --delete-branch
```

**Linked worktree** — merge **without** `--delete-branch` (it would fail against the worktree's checked-out branch), delete the remote branch best-effort, and leave the local worktree and branch in place — whoever created the worktree owns its lifecycle:

```bash
gh pr merge {pr_number} {--squash | --merge}
git push origin --delete {headRefName} 2>/dev/null || true
```

Note the worktree in the Step 8 report ("Worktree: left in place at {path}"). No warnings, no errors.

Use the strategy flag chosen in Step 5 (`--squash` for feature/bugfix/hotfix/chore branches, `--merge` for `release/...`). If `--delete-branch` is not supported by the installed `gh` version, omit it.
````

- [ ] **Step 2: Add the error-handling row**

In the Error Handling table, after the row `| Merge fails for other reason | … |`, insert:

```markdown
| `--delete-branch` fails (branch checked out in a worktree, or any local-checkout reason) | Verify the merge succeeded (`gh pr view --json state`), delete the remote branch best-effort (`git push origin --delete {headRefName}`), leave the local checkout alone, and report the outcome gracefully — this is not an error. |
| Conflict resolution: `git checkout {headRefName}` fails with "'{headRefName}' is already used by worktree at '{path}'" | The branch lives in a linked worktree — run the same conflict-resolution commands from that worktree path instead, then re-attempt the merge. Not an error. |
```

- [ ] **Step 3: Add the worktree line to the Step 8 report template**

In the Step 8 `## Ticket closed out` block, after the `Status:` line, add:

```markdown
{If a linked worktree:}
Worktree: left in place at {path}
```

- [ ] **Step 4: Verify**

Run: `grep -c "git-common-dir" skills/finish-ticket/SKILL.md` — Expected: `1`.
Run: `grep -c "left in place" skills/finish-ticket/SKILL.md` — Expected: ≥ `2`.
Run: `wc -l skills/finish-ticket/SKILL.md` — Expected: < 500.

- [ ] **Step 5: Commit**

```bash
git add skills/finish-ticket/SKILL.md
git commit -m "fix(finish-ticket): worktree-aware branch cleanup, no error on linked worktrees"
```

*Amended during execution: detection test normalized with `--path-format=absolute` (relative/absolute output mismatch caused a false positive from subdirectories); conflict-resolution worktree row added; placeholder + phrasing normalized.*

---

### Task 7: Delta re-reviews

**Files:**
- Modify: `skills/auto-ticket/autonomous-contract.md` (§2 grounding block, ~line 34)
- Modify: `skills/auto-ticket/SKILL.md` (Step 3 fix-loop item 3)
- Modify: `skills/review-ticket/SKILL.md` (Autonomous mode → "Behavior at each human-gate")

**Interfaces:**
- Consumes: Task 3's `systemic:` field and scoped-all-clear rule (referenced in the new bullet).
- Produces: the grounding-block line `review_pass: {n}`.

- [ ] **Step 1: Add `review_pass` to the contract §2 grounding block**

In the fenced grounding-block template, after the `max_feedback_passes: {n}` line, add:

```
review_pass: {n — only on Step 3 re-reviews; absent on the first review pass}
```

Then, after the paragraph that begins "Under the **prompt-relay transport** (§7) the block also carries…" (i.e., after the `ticket_content` explanation, before §3), add this sentence as its own paragraph:

```markdown
`review_pass:` appears only when the orchestrator re-invokes `review-ticket` inside its Step 3 fix loop (2 on the first re-review, incrementing). `review-ticket` uses it to switch to a delta report (see its *Autonomous mode*); all other sub-skills ignore it.
```

- [ ] **Step 2: Set `review_pass` in auto-ticket's fix loop**

In `skills/auto-ticket/SKILL.md` Step 3, replace:

```markdown
  3. Re-invoke the review-ticket step via `run_step`.
```

with:

```markdown
  3. Re-invoke the review-ticket step via `run_step`, adding `review_pass: {n}` to the grounding block (2 on the first re-review, incrementing) so the reviewer produces a delta report (contract §2).
```

- [ ] **Step 3: Add the delta-report behavior to review-ticket**

In `skills/review-ticket/SKILL.md`, under *Autonomous mode → Behavior at each human-gate*, after the `- **Step 7 (Drift handling):**` bullet block, add:

```markdown
- **Re-review passes (`review_pass:` ≥ 2 in the grounding block):** post a **delta report** instead of a full fresh one — findings from the previous pass confirmed fixed as one-liners, net-new findings in full (schema unchanged), and a reference/link to the previous report's comment instead of repeating unchanged sections. Verdict and handshake semantics are unchanged, and the systemic-enumeration and scoped-all-clear rules apply in full on every pass.
```

- [ ] **Step 4: Verify**

Run: `grep -rn "review_pass" skills/auto-ticket/autonomous-contract.md skills/auto-ticket/SKILL.md skills/review-ticket/SKILL.md | wc -l` — Expected: ≥ `4`.

- [ ] **Step 5: Commit**

```bash
git add skills/auto-ticket/autonomous-contract.md skills/auto-ticket/SKILL.md skills/review-ticket/SKILL.md
git commit -m "feat(review-ticket): delta reports on re-review passes via review_pass"
```

---

### Task 8: Agent `tools:` allowlists

**Files:**
- Modify: `agents/auto-work.md`, `agents/auto-review.md`, `agents/auto-feedback.md`, `agents/auto-validate.md`, `agents/auto-finish.md`, `agents/auto-push.md` (frontmatter; `auto-review` also gets one body line)

- [ ] **Step 1: Apply the allowlists** (preloaded `skills:` lists unchanged; remove `disallowedTools:` lines where present — the boundary now lives in `tools:`):

| File | Frontmatter change |
|------|--------------------|
| `auto-work.md` | replace `disallowedTools: Skill` with `tools: Read, Write, Edit, Bash, Glob, Grep, Task, TodoWrite` |
| `auto-review.md` | replace `disallowedTools: Skill` with `tools: Read, Write, Bash, Glob, Grep, Task, TodoWrite` |
| `auto-feedback.md` | replace `disallowedTools: Skill` with `tools: Read, Write, Edit, Bash, Glob, Grep, Task, TodoWrite` |
| `auto-validate.md` | already `tools: Read, Bash, Glob, Grep, Task` — verify, no change |
| `auto-finish.md` | replace `disallowedTools: Skill, Task` with `tools: Read, Edit, Bash, Glob, Grep` |
| `auto-push.md` | already `tools: Read, Bash, Glob, Grep, Write` — verify, no change |

- [ ] **Step 2: Add the Write-scope line to `auto-review.md`'s body**

After the sentence ending `Report and verdict only; do not mutate code (the orchestrator applies fixes).`, add to the same paragraph:

```markdown
Your toolset has no Edit for that reason; Write is permitted solely for `context/review-stats.json` — never create or overwrite source files.
```

- [ ] **Step 3: Verify**

Run: `grep -L "^tools:" agents/auto-*.md` — Expected: no output (every file has a `tools:` line).
Run: `grep -rn "disallowedTools" agents/` — Expected: no matches.
Run: `grep -n "Edit" agents/auto-review.md` — Expected: only the body sentence explaining its absence (not in `tools:`).

- [ ] **Step 4: Commit**

```bash
git add agents/
git commit -m "refactor(agents): explicit tools allowlists for all auto-* step agents"
```

---

### Task 9: Housekeeping — version bump, README, final consistency sweep

**Files:**
- Modify: `.claude-plugin/plugin.json` (version)
- Modify: `.claude-plugin/marketplace.json` (only if it carries a version — check)
- Modify: `README.md` (autonomous-mode section, config comments)

- [ ] **Step 1: Bump the version**

In `.claude-plugin/plugin.json`: `"version": "3.3.0"` → `"version": "3.4.0"`. Check `.claude-plugin/marketplace.json` for a version field and bump it identically if present.

- [ ] **Step 2: README touch-ups**

- Line ~194: `# ci_poll_interval_seconds: 60 # how often to poll CI status` → `# ci_poll_interval_seconds: 60 # interval for the gh pr checks --watch CI wait`
- In the Autonomous-mode section (~lines 155–215), find the sentence describing the review/fix cycle and CI, and confirm it doesn't contradict the new mechanics (bounded watch, systemic class-fixes, delta re-reviews). Add one sentence where the feedback loop is described: `Review-fix passes fix systemic findings as a whole class, re-reviews post deltas rather than fresh full reports, and the CI wait is a bounded blocking watch (gh pr checks --watch) — never a sleep loop.` Adapt placement to the existing prose.
- Also update `docs/ccmagic.local.md.example` line ~58: `# ci_poll_interval_seconds: how often to poll CI status.` → `# ci_poll_interval_seconds: interval for the gh pr checks --watch CI wait.` and the table row at ~line 97 similarly.

- [ ] **Step 3: Final consistency sweep (acceptance criteria from the design doc)**

Run each; fix anything that fails before committing:

```bash
grep -rn "default \*\*2\*\*" skills/auto-ticket/            # expect: no matches
grep -rn "Poll CI\|Poll on" skills/                          # expect: no matches
grep -c "watch --interval" skills/auto-ticket/SKILL.md       # expect: ≥1
grep -rln "systemic" skills/review/ skills/review-ticket/ skills/auto-ticket/SKILL.md   # expect: 4+ files
grep -L "^tools:" agents/auto-*.md                           # expect: no output
grep -rn "how often to poll CI" README.md docs/              # expect: no matches
awk 'END{if (NR>=500) print FILENAME" too long: "NR}' skills/*/SKILL.md  # expect: no output
```

- [ ] **Step 4: Commit**

```bash
git add .claude-plugin/ README.md docs/ccmagic.local.md.example
git commit -m "chore: bump to 3.4.0; align README and config docs with hardening changes"
```
