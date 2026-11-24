# Handle merge conflicts (finish-ticket Step 6)

If the merge fails due to conflicts:

1. Report the conflict clearly:
   > "The PR cannot be merged automatically due to conflicts."
2. Fetch and attempt local resolution:
   ```bash
   git fetch origin
   git checkout {headRefName}
   git merge origin/{baseRefName}
   ```
3. Show the conflicting files:
   ```bash
   git diff --name-only --diff-filter=U
   ```
4. Attempt to resolve straightforward conflicts (version bumps, import lists, config values). If the conflict requires business-logic judgment, show it to the user and ask.
5. After resolving:
   ```bash
   git add {resolved files}
   git commit -m "chore: resolve merge conflicts for {TICKET-ID}"
   git push origin {headRefName}
   ```
6. The push moved the PR head past the last review, so no review has read the head you would merge. Before re-attempting the merge:
   - **Standalone:** run Step 3d's review head check again on the new head (`${CLAUDE_PLUGIN_ROOT}/skills/work-ticket/review-head.md`). In autonomous mode a review that is not `clean` on the new head is `needs-human`.
   - **Orchestrated** (`orchestrator:` in the grounding block): the orchestrator's review covered the head before this push, and Step 3d skipped its check for that reason, so the check does not cover this push either. Do not merge and do not hand off: return `needs-human` with `reason: finish pushed a conflict merge {sha7} after the last review; PR #{pr_number} head needs a review before it merges`, so the orchestrator parks rather than merge a head no review has read.
   Then, standalone with a clean review of the new head, re-attempt the PR merge.
7. If conflicts cannot be resolved, stop and tell the user what remains unresolved.
