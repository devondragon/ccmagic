# Keep the PR description true after a later push (3.32.0)

`/ccmagic:pr` writes the description when the PR opens, from the commits on the branch then. A later push can make a line of it false or add a change it does not mention, and nothing rewrites it. On reeve-dashboard PR #165 the description still said the `stepper-review.test.tsx` failures "are left for a follow-up" after commit 703e37e fixed them in that PR.

**Who runs it.** `/ccmagic:auto-ticket` runs it after the last push of its feedback loop (its Step 4g) and before a park's note (contract §4 step 5). `/ccmagic:pr` runs it in place of creating a PR when the branch already has an open one. Never on a fix pass: a fix pass runs no `gh pr` command.

## The check

Run each command as its own Bash call.

1. **Read the description**: `gh pr view {PR_NUMBER} --json body,headRefOid`. `body` is the description as it stands, `headRefOid` the PR head.
2. **List the commits since the description was last written.** `{from}` is the PR head when the description was last written (auto-ticket's `described_head`), or `origin/{base}` when that is not known, such as on a PR an earlier run opened:
   ```bash
   git log --first-parent --no-merges --name-only --format='- %h %s' {from}..HEAD
   ```
   `--first-parent --no-merges` leaves out a merge of the base and the commits it brought in, which are not the PR's change. A conflict fix pass that changed the PR's own files is the one merge worth reading: when the run made one, also read `git diff --name-only {merge}^1 {merge}` for that merge commit.
   No commits: the description is current; stop here.
3. **Compare.** For each commit, decide whether it makes a statement in the description false, or adds a change the description does not mention. Examples of each:
   - A line says something is left for a follow-up, out of scope, unchanged, or not tested, and the commit changes it: a follow-up no longer needed, a test the description says was left alone.
   - The commit changes a file outside the ticket's scope, or touches a test, and no line of the description mentions it.
   - A count or list in the description (files, tests, endpoints) no longer matches.

   A commit that only refines a change the description already names (a review fix inside a described file, a renamed variable) needs no edit. When no commit needs one, the description is current; stop here.
4. **Edit the lines that need it, and only those.** Correct each false line in place, and add one line per unmentioned change to the list of changes the description already has (its `## Changes` section, or the nearest equivalent; append a `## Changes after review` section only when it has none), naming the commit: `` - 703e37e: `test/web/stepper-review.test.tsx` waits for the title, so the full suite passes. `` Do not rewrite, reorder, or reword any other line. Leave alone every line another tool reads: `Closes #N` and `Fixes` lines, the ticket link, the autonomous classification line, and the `## OpenSpec` section. Write new lines in US English with no em or en dash.
   ```bash
   gh pr edit {PR_NUMBER} --body-file - <<'CCM_PR_BODY_EOF'
   {the whole description with the edited lines}
   CCM_PR_BODY_EOF
   ```
   Write the description's lines and the closing `CCM_PR_BODY_EOF` line at the start of the line, without the indentation shown here. Pass the body on stdin through the quoted heredoc, never as `--body "..."` or a temp file, for the reasons `/ccmagic:pr` gives for `gh pr create`. On GitLab, update the merge request the way `/ccmagic:pr` creates one (`glab mr update {n} --description ...`); on Bitbucket, the API or the web page.
5. **Record it.** When the check found the description current or edited it, the PR head read in item 1 is the new `described_head`, so a later run of the check reads only the commits after it. Report the result in one line: `PR description: current`, `PR description: updated for {sha7, ...}`, or `PR description may be stale after {sha7}: {why}`.

## When the check fails

A failed read, a failed edit, or a host with no edit command is never a park and never stops the run. Leave the description as it is and report `PR description may be stale after {sha7 of the oldest commit that needed an edit, or of the first commit listed when the read failed}: {first error line}`, which auto-ticket puts under "Key autonomous decisions" in its run summary or parked note.
