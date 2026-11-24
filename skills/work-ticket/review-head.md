# Review covers the PR head (RV-178)

A review covers a pull request only while the PR head is the commit the review read. A merge gate that binds the review to a commit rejects a report on any other head (Reeve parks it as `review-not-clean`, RV-1), and a person reading the report is misled the same way. Any push to the PR branch after the review moves the head past it: a fix of a review finding, a fix for PR feedback, a merge of the base branch, a rebase. `/ccmagic:auto-ticket` enforces this in its Step 4e and 4f; `/ccmagic:work-ticket`, `/ccmagic:pr-feedback`, and `/ccmagic:finish-ticket` follow this file when they run on their own.

**When it applies.** Standalone runs, interactive or autonomous. With `orchestrator:` in the grounding block, skip this file: the orchestrator reviews every pushed head itself and never finishes on a stale review. Never on a fix pass.

## The check

Run it before the skill finishes or hands off, at the point its SKILL.md names, as separate Bash calls:

1. Read the PR head: `gh pr view {PR_NUMBER} --json headRefOid --jq .headRefOid` (the full 40-character SHA as GitHub reports it, never the local `git rev-parse HEAD`, which can differ from what the PR holds).
2. Find the commit the last review read, `reviewed_head`:
   - a `/ccmagic:review-ticket` report in autonomous mode: the `head:` line of its handshake. On the PR, that is the newest comment whose first line is `# Ticket-Grounded Review:` (`gh pr view {PR_NUMBER} --json comments`), and the `head:` line in the fenced block that ends it;
   - an interactive review: the output of `git rev-parse HEAD` run right before the review started (review-ticket's Step 4 runs it with the diff; for `/ccmagic:review`, run it yourself first);
   - a review of uncommitted changes read no commit. It covers the first pushed head only when that push committed exactly the changes it read; any edit after the review (a fix of one of its findings included) leaves the head unreviewed.
3. When `reviewed_head` equals the PR head, the review covers it: go on.
4. Otherwise, review the PR head again:
   - Make the checkout the PR head first: `git pull --ff-only` on the PR branch when `git rev-parse HEAD` differs from the PR head, with a clean working tree. A pull that cannot fast-forward is a stop (autonomous: `needs-human`, `reason: local branch has diverged from PR #{n}`).
   - Run `/ccmagic:review-ticket` (with the autonomous grounding block in autonomous mode). When an earlier review exists, add `review_pass: {n}` (one more than the reviews so far in this run) and a `previous_findings:` section: the earlier report's findings, and one line per commit since it from `git log --format='- %h %s' {reviewed_head}..HEAD`, so the reviewer posts a delta report and reads each new commit's changes as new code.
   - Read the PR head again (step 1) and confirm that the new report's `head:` (interactively, the `git rev-parse HEAD` the review read) equals it.
   - Handle its findings as the skill handles its first review's (`/ccmagic:finish-ticket` fixes nothing, so in autonomous mode a review that is not clean stops it). A fix you push moves the head again, so repeat from step 1.
5. Bound the repeats by `max_review_fix_passes` (default 3, from `ccm-context`'s `config`): that many reviews after the first, then stop.

## When the check fails

- **Autonomous:** never finish, merge, or hand off on a stale review. A failed read of the PR head, a report whose `head:` is missing or differs from the PR head, findings with no review left under the bound, or a `needs-human` review → `needs-human` with `reason: review covers {reviewed_head, 7 characters, or "no commit"} but PR #{n} head is {head, 7 characters}: {what stopped it}`. A top-level run does its own route-and-stop as its SKILL.md says.
- **Interactive:** say which commit the last review read and what the PR head is, and offer two options: review the PR head now (step 4), or go on with the stale review, which the PR body or the final message then names (`Review covers {sha7}, not the PR head {sha7}.`). Never pick the second yourself.
