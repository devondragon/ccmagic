# Keep the PR description true after a later push (3.32.0)

`/ccmagic:pr` writes the description when the PR opens, from the commits on the branch then. A later push can make a line of it false or add a change it does not mention, and nothing rewrites it. On reeve-dashboard PR #165 the description still said the `stepper-review.test.tsx` failures "are left for a follow-up" after commit 703e37e fixed them in that PR.

**Who runs it.** `/ccmagic:auto-ticket` runs it after the last push of its feedback loop (its Step 4g) and before a park's note (contract §4 step 5). `/ccmagic:pr` runs it in place of creating a PR when the branch already has an open one. Never on a fix pass: a fix pass runs no `gh pr` command. A park before auto-ticket's Step 2 takes `{PR_NUMBER}` from the `pr` field of Step 0's `ccm-context` output, and has no check to run when that is null.

**Other failures** are the caller's list of tests the ticket could not make pass because the fix is out of its scope (work-ticket Step 6, *A criterion that needs an out-of-scope change*). In auto-ticket they are the `follow_ups:` items that start with `other failures: `, from the work step or a fix pass. Standalone, they are the ones the work just reported. The list may be empty.

## The check

Run each command as its own Bash call.

1. **Read the PR**: `gh pr view {PR_NUMBER} --json body,headRefOid,baseRefName`. `body` is the description as it stands, `headRefOid` the PR head, and `baseRefName` the base branch, `{base}` below. Take the base from here, never from `ccm-context`'s `base_branch`, which is the repository's default branch and can differ from the PR's base.
2. **List the commits since the description was last written**, up to the PR head from item 1, never the local `HEAD`, which can differ from what the PR holds. Fetch both first with `git fetch origin {base} {headRefName}` (`headRefName` from `gh pr view {PR_NUMBER} --json headRefName` when you do not have it). `{from}` is the PR head when the description was last written (auto-ticket's `described_head`), or `origin/{base}` when that is not known, such as on a PR an earlier run opened:
   ```bash
   git log --first-parent --no-merges --name-only --format='- %h %s' {from}..{headRefOid}
   ```
   `--first-parent --no-merges` leaves out a merge of the base and the commits it brought in, which are not the PR's change. A merge whose conflicts a fix pass resolved can still change the PR's own files. When the run made one, take the files the PR itself changes, `git diff --name-only origin/{base}...{headRefOid}`, and read only the files of `git diff --name-only {merge}^1 {merge}` that are also in that list; every other file the merge lists came from the base.
   No commits and no other failures: the description is current; stop here.
3. **Compare.** For each commit, decide whether it makes a statement in the description false, or adds a change the description does not mention. Examples of each:
   - A line says something is left for a follow-up, out of scope, unchanged, or not tested, and the commit changes it: a follow-up no longer needed, a test the description says was left alone.
   - The commit changes a file outside the ticket's scope, or touches a test, and no line of the description mentions it.
   - A count or list in the description (files, tests, endpoints) no longer matches.

   A commit that only refines a change the description already names (a review fix inside a described file, a renamed variable) needs no edit. Then check each other failure: when no line of the description names its test, it needs one line. When nothing needs an edit, the description is current; stop here.
4. **Read the body again right before the edit**, with `gh pr view {PR_NUMBER} --json body`. When it differs from the body item 1 read (someone edited it meanwhile), redo item 3 on the new body once and read again. When it changed a second time, skip the edit and report `PR description may be stale: changed during the check`.
5. **Edit the lines that need it, and only those.** Correct each false line in place, and add one line per unmentioned change to the list of changes the description already has (its `## Changes` section, or the nearest equivalent; append a `## Changes after review` section only when it has none), naming the commit: `` - 703e37e: `test/web/stepper-review.test.tsx` waits for the title, so the full suite passes. `` For other failures, add one line: `` - Other failures, out of this ticket's scope and not fixed here: `<test name>` in `<file>`, ... `` Do not rewrite, reorder, or reword any other line. Leave alone every line another tool reads: `Closes #N` and `Fixes` lines, the ticket link, the autonomous classification line, and the `## OpenSpec` section. Write new lines in US English with no em or en dash.
   ```bash
   gh pr edit {PR_NUMBER} --body-file - <<'CCM_PR_BODY_EOF'
   {the whole description with the edited lines}
   CCM_PR_BODY_EOF
   ```
   Write the description's lines and the closing `CCM_PR_BODY_EOF` line at the start of the line, without the indentation shown here. Pass the body on stdin through the quoted heredoc, never as `--body "..."` or a temp file, for the reasons `/ccmagic:pr` gives for `gh pr create`. On GitLab, pass it on stdin the same way: `glab mr update {n} --description-file - <<'CCM_PR_BODY_EOF'`. On Bitbucket, the API or the web page.
6. **Record it.** When the check found the description current or edited it, the PR head read in item 1 is the new `described_head`, so a later run of the check reads only the commits after it. Report the result in one line: `PR description: current`, `PR description: updated for {sha7, ...}` (`other failures` when only that line was added), or one of the stale lines below.

## When the check fails

A failed read, a failed edit, or a host with no edit command is never a park and never stops the run. Leave the description as it is and report one line, which auto-ticket puts under "Key autonomous decisions" in its run summary or parked note: `PR description may be stale: {first error line}` when a read failed (there is no commit to name), and `PR description may be stale after {sha7 of the oldest commit that needed an edit}: {first error line}` when the edit failed.
