# Base sync: merging the base into the run's branch

`/ccmagic:auto-ticket` keeps the run's branch up to date with its base by merging `origin/{base}` into it with `bin/ccm-base-sync`: a merge, never a rebase or a force push, since the branch may already back an open PR. SKILL.md Step 0 runs the `sync` mode of `ccm-base-sync` before config is loaded, and Step 4c sends a `conflicting` CI result here. This file holds the two conflict procedures and the run record entries.

Why (2026-11-21, Reeve dispatching to Cyrus): a Cyrus session reused a ticket's worktree made hours earlier. On cclens CCL-20 the checkout predated the commit that added `.claude/ccmagic.local.md` with `merge_owner: reeve`, so the run used the default `merge_owner: self`, tried `gh pr merge`, and parked on the hook's refusal although the PR was clean. On CCL-39 the branch was two commits behind main and the PR conflicted with it; the run parked at the CI wait, and its run record showed every step `done`, so Reeve could not tell the park was a merge conflict.

The script's merge is mechanical: it either merges cleanly or leaves the tree exactly as it was (`sync`), or leaves the conflicts in the tree for a fix pass (`begin`). Resolving a conflict is a code change, so the work step makes it, as a fix pass; this skill still never edits a file. Run every `ccm-base-sync` call as its own Bash call, by the `${CLAUDE_PLUGIN_ROOT}/bin/` path (the bare name only when the path form is not found or is denied).

## Resolving a conflict (R1 to R3)

Both procedures below use these three items. `{base}` is the base branch, and `{sha7}` the first seven characters of the `base_sha` the script reports.

- **R1. Start the merge:** `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-base-sync" begin --base {base}`. `conflicting` (exit 0) leaves the merge in progress with its `conflicts` listed: go to R2. `merged` means the base now merges cleanly and the script committed the merge: record the entry below and skip R2 and R3. `up-to-date` means there is nothing to merge: skip R2 and R3. Any other status changed nothing: **route-and-stop** with the entry `{"step": "base-sync", "status": "needs-human", "reason": "merge conflict with origin/{base} not resolved: {the script's reason}"}`.
- **R2. Conflict fix pass.** Run a fix pass on the work step via `run_step`, as SKILL.md Step 3 item 2 runs one, including the fix-pass git check: `fix_pass: {n}` from the run-wide counter (it does not count against `max_review_fix_passes`), `fix_source: conflict`, and a `findings_to_fix:` section with one line per conflicted path, `conflict: {path} | origin/{base} at {sha7}`. The work step resolves them by `skills/work-ticket/base-conflict.md` and leaves the result uncommitted. When it returns `needs-human`, when the git check fails, or when `applied_findings:` leaves out a `conflict: {path}` item, first run `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-base-sync" abort`, so no half-merged tree is left behind, then **route-and-stop**. A `needs-human` from the step carries its own reason, which starts `merge conflict with origin/{base}`; for the other two, append `{"step": "conflict-fix-check", "status": "needs-human", "reason": "merge conflict with origin/{base} not resolved: fix pass {n} (conflict) {what went wrong}"}`. Say in the parked note that the resolution attempt was discarded with the `abort` mode of `ccm-base-sync`.
- **R3. Commit the merge:** `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-base-sync" conclude`. It refuses a merge it did not begin, a conflicted file that still has a conflict marker line (`unresolved`), and a file the fix pass added, then commits the merge with git's message. `merged`: record the entry below. Anything else: run the `abort` mode of `ccm-base-sync`, then **route-and-stop** with `{"step": "base-sync", "status": "needs-human", "reason": "merge conflict with origin/{base} not resolved: {the script's reason}"}`.

Each procedure runs R1 to R3 at most once in a run.

## Conflict at the start of the run (Step 0b)

Only when Step 0's `sync` returned `conflicting`. The script aborted that merge, so the checkout is as it was, and Step 0 loaded config with `--config-ref origin/{base}`. After Step 0 item 5 (the grounding block exists, so a fix pass can run), run R1 to R3. Then continue to Step 1. The merge commit is local; the work step pushes it with the work. The work step and Step 4b validate the merged code like any other change.

## Conflict at the CI wait (Step 4c)

When `ccm-ci-status` returns `conflicting` and this run has not merged its base at Step 4c yet:

1. Run `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-base-sync" sync --base {BASE_BRANCH} --push`.
   - `merged` (pushed): record the entry below and go to item 2.
   - `conflicting` (the merge was aborted): run R1 to R3. Then run the validate step via `run_step` exactly as Step 4b does, with its fix attempts, their `/ccmagic:push`, and its route-and-stops. Then run `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-base-sync" push`: `pushed` or `up-to-date` goes to item 2; `push-failed` is a **route-and-stop** with the `ci-wait` entry below.
   - `up-to-date`: the branch already contains `origin/{BASE_BRANCH}`, so the conflict GitHub reports is not one a merge here can fix. **Route-and-stop** with the `ci-wait` entry.
   - Any other status (`dirty`, `fetch-failed`, `error`, `push-failed`): **route-and-stop** with the `ci-wait` entry, its reason ending `; merging origin/{BASE_BRANCH} failed: {the script's reason}`.
2. Wait for CI again with the same command and wait key `{run_id}-pass{n}-sync`, and act on its final status as Step 4c says, except that `conflicting` now always ends the run: **route-and-stop** with the `ci-wait` entry. Then read the review threads against `H` and go on to 4d. The merge moved the PR head past `reviewed_head`, so 4e sends the pass to the 4f re-review; its `previous_findings:` lists the merge commit with the other commits since the reviewed head, and the conflict fix pass's `applied_findings:` when R2 ran.

With `merge_owner: reeve` nothing else changes: the run still hands off only from Step 5, after green CI and a clean review of the merged head, and `ccm-finish-guard` still requires a validate after the conflict fix pass, which item 1 runs.

The `ci-wait` entry is `{"step": "ci-wait", "status": "needs-human", "reason": "PR has merge conflicts with its base, so CI cannot run: {ccm-ci-status reason}"}`, with the endings above. Its step name contains none of `validate`, `review`, or `feedback`, so Reeve maps the park to `merge-conflict`.

## Run record entries

Every merge of the base this run makes adds one entry to the run record's `steps`, in order, with status `done`: `{"step": "base-sync", "status": "done", "reason": "{the script's reason}"}`, for example `merged origin/main at 1a2b3c4 into feature/CCL-39-x (2 commits behind)`. A Step 0 `sync` that returned `conflicting` adds one with the script's reason (the merge was aborted), ahead of Step 0b's entries, and one that could not run (`dirty`, `fetch-failed`, `error`) adds one with the reason `not synced: {the script's reason}`; `up-to-date` and `not-applicable` add none. These entries are `done`, so no reader takes one for a verdict the run went past, and `ccm-finish-guard` counts a `base-sync` entry as neither validate nor a code change. A park on these paths adds the needs-human entry named above (contract §4).
