---
name: merge
user-invocable: true
allowed-tools: Read(*), Bash(git:*), Bash(gh:*), Bash(glab:*), Bash(curl:*), Bash(${CLAUDE_PLUGIN_ROOT}/bin/ccm-merge-gate *), Bash(ccm-merge-gate *), Bash(${CLAUDE_PLUGIN_ROOT}/bin/ccm-ci-status *), Bash(ccm-ci-status *), Glob(*)
description: Safely merge approved PRs with strategy-aware branch handling
argument-hint: "[PR-number] (optional)"
model: sonnet
---

# Merge Command

Safely merge approved pull requests to the appropriate target branch based on your configured branching strategy.

## MCP Tool Availability

This command uses built-in git tools and does not require MCP tools. All functionality is available through:
- Git CLI for merge operations
- GitHub CLI (`gh`) for PR status and merge
- GitLab CLI (`glab`) for MR operations
- Bitbucket API via curl for Bitbucket repos

## Reading Branching Configuration

```bash
# Load branching configuration
if [ -f "context/branching.md" ]; then
    echo "Loading branching configuration..."
    STRATEGY=$(grep "Strategy:" context/branching.md | head -1)
    BASE_BRANCH=$(grep "Primary Branch:" context/branching.md | head -1)
else
    echo "No branching configuration found. Using defaults."
    BASE_BRANCH="main"
fi
```

## Merge Process

1. **Load Configuration**: Read branching strategy and base branch
2. **Verify PR Status**: Ensure PR is approved and checks pass
3. **Update Local**: Sync with remote before merge
4. **Perform Merge**: Execute merge strategy based on configuration
5. **Cleanup**: Delete local and remote branches

> If the PR is tied to a tracker ticket, prefer `/ccmagic:finish-ticket` instead — it adds a tracker-side comment and status update on top of the merge.

## Pre-Merge Verification

### GitHub: run the merge gate

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-merge-gate" [PR-NUMBER]
```

It exits 0 when the PR may merge and prints JSON with `blockers` (not open, conflicting or unknown mergeability, CI not green, a reviewer's latest review is `CHANGES_REQUESTED`), `warnings` (no approving review), and the full CI result under `ci`. Report the blockers and warnings as given; do not re-derive them from `gh pr view`. If `ci.status` is `pending` or `not-registered`, wait with `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-ci-status" [PR-NUMBER] --watch --wait-key merge-[PR-NUMBER]` (repeat while it returns `"call_again": true`), then run the gate again.

If the gate fails, show the blockers and stop. Merge anyway only if the user explicitly says to. When `merge_guard: on` is set, the PreToolUse hook denies the merge command while the gate fails; after the user's explicit choice, prefix the merge command with `CCMAGIC_MERGE_OVERRIDE=1`.

Conflicts are reported by the gate from GitHub's own mergeability check. Do not test for conflicts by running `git merge` in the working checkout.

The `ccm-*` scripts are also on the Bash `PATH` while the plugin is enabled. If the `${CLAUDE_PLUGIN_ROOT}/bin/` path doesn't resolve (for example, the variable wasn't expanded), call them by bare name: `ccm-merge-gate`, `ccm-ci-status`.

### GitLab / Bitbucket

No gate script covers these yet. Check approval, pipeline status, and conflicts with `glab mr view` or the Bitbucket API before merging.

## Merge Strategies

### Strategy-Aware Merging

```bash
# Determine merge approach. ccmagic's documented prefixes are feature/, bugfix/,
# hotfix/, chore/ (all squash-merged into the base branch) and release/
# (merge-committed into the base branch). Anything else falls back to the base.
CURRENT_BRANCH=$(git branch --show-current)
TARGET="$BASE_BRANCH"
```

### 1. Squash and Merge (Recommended for feature/bugfix/hotfix/chore branches)
```bash
# GitHub CLI
gh pr merge --squash --delete-branch
```

### 2. Merge Commit (For preserving history)
```bash
# GitHub CLI
gh pr merge --merge --delete-branch
```

### 3. Rebase and Merge (For linear history)
```bash
# GitHub CLI
gh pr merge --rebase --delete-branch
```

## Automated Merge Flow

```markdown
1. Detect platform (GitHub/GitLab/Bitbucket)
2. Run the merge gate (GitHub) or check approval and pipeline status (GitLab/Bitbucket)
3. Wait for pending CI with `ccm-ci-status --watch`
4. Select merge strategy based on:
   - Project conventions
   - Branch type (feature/hotfix/release)
   - Commit history complexity
5. Execute merge
6. Cleanup local and remote branches
```

## Platform-Specific Commands

### GitHub
```bash
# Merge with GitHub CLI
gh pr merge [PR-NUMBER] \
  --squash \
  --delete-branch \
  --subject "feat(scope): TICKET-ID short description" \
  --body "Detailed description of changes"

# Check merge status
gh pr status
```

### GitLab
```bash
# Merge with GitLab CLI
glab mr merge [MR-ID] \
  --squash \
  --remove-source-branch \
  --message "Merge feature into main"
```

### Bitbucket
```bash
# Use API or web interface
curl -X POST "https://api.bitbucket.org/2.0/repositories/{workspace}/{repo}/pullrequests/{id}/merge" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{"merge_strategy": "squash"}'
```

## Post-Merge Cleanup

### 1. Branch Cleanup
```bash
# Delete local feature branch
git branch -d feature-branch

# Delete remote branch (if not auto-deleted)
git push origin --delete feature-branch

# Prune remote tracking branches
git remote prune origin

# Clean up any leftover branches
git branch --merged | grep -v main | xargs -r git branch -d
```

### 2. Update Local Main
```bash
git checkout main
git pull origin main
```

### 3. Tracker Updates
- If a tracker ticket is associated with this branch, `/ccmagic:finish-ticket` is the recommended way to post the merge back and close the ticket — invoke it after the merge if you haven't already.
- Close related issues if applicable.

### 4. Notify Team
```markdown
## Merge Completed

**Branch**: feature/TICKET-ID-short-description
**PR**: #123
**Commits**: 15 commits squashed
**Changes**: +500 -200 lines

### Summary
[Brief description of what was merged]

### Next Steps
- [ ] Deploy to staging
- [ ] Update documentation
- [ ] Monitor for issues
```

## Rollback Plan

If issues arise post-merge:

### Quick Revert
```bash
# Find merge commit
git log --oneline -10

# Revert the merge
git revert -m 1 [merge-commit-hash]
git push origin main

# Or using GitHub CLI
gh pr view [PR-NUMBER] --json mergeCommit
git revert [merge-commit-sha]
```

### Create Hotfix
```bash
# Branch from main
git checkout -b hotfix/fix-merge-issue
# Make fixes
git push origin hotfix/fix-merge-issue
# Create urgent PR
gh pr create --title "HOTFIX: Fix issue from PR #123"
```

## Integration with Other Commands

- Run `/ccmagic:test` before merge
- Invoke `/ccmagic:finish-ticket` after merge to update the tracker ticket and post the merge comment

## Safety Features

1. **Dry Run Mode**: Preview merge without executing
2. **Backup Creation**: Tag current main before merge
3. **Conflict Detection**: Abort if conflicts found
4. **CI Verification**: `ccm-merge-gate` requires green CI (or a repo with no CI)

## Execution

Begin merge process immediately if PR number is provided or if current branch has an open PR. Always run the merge gate before the merge. Provide clear success/failure feedback.
