# Merge Command

Safely merge approved pull requests to the appropriate target branch based on your configured branching strategy.

## Reading Branching Configuration

```bash
# Load branching configuration
if [ -f "context/branching.md" ]; then
    echo "📖 Loading branching configuration..."
    STRATEGY=$(grep "Strategy:" context/branching.md | head -1)
    BASE_BRANCH=$(grep "Primary Branch:" context/branching.md | head -1)
else
    echo "⚠️ No branching configuration found. Using defaults."
    BASE_BRANCH="main"
fi
```

## Merge Process

1. **Load Configuration**: Read branching strategy and base branch
2. **Verify PR Status**: Ensure PR is approved and checks pass
3. **Update Local**: Sync with remote before merge
4. **Perform Merge**: Execute merge strategy based on configuration
5. **Cleanup**: Delete branches and update tracking
6. **Post-merge**: Update task status and documentation

## Pre-Merge Verification

### Required Checks
1. PR is approved by required reviewers
2. All CI/CD checks are passing
3. No merge conflicts exist
4. Branch is up-to-date with target branch

### Verification Commands
```bash
# Check PR status (GitHub)
gh pr view --json state,mergeable,reviews

# Fetch latest changes
git fetch origin

# Verify no conflicts with target branch
git merge --no-commit --no-ff origin/$BASE_BRANCH
git merge --abort  # After checking
```

## Merge Strategies

### Strategy-Aware Merging

```bash
# Determine merge approach based on strategy
CURRENT_BRANCH=$(git branch --show-current)

if [[ "$STRATEGY" == *"A"* ]]; then
    # Hierarchical: Different merge for task vs feature
    if [[ "$CURRENT_BRANCH" == task/* ]]; then
        echo "Merging task to feature branch"
        TARGET="feature/[extracted-feature-id]"
    else
        echo "Merging feature to $BASE_BRANCH"
        TARGET="$BASE_BRANCH"
    fi
elif [[ "$STRATEGY" == *"B"* ]] || [[ "$STRATEGY" == *"C"* ]]; then
    # Direct or Single Feature: Merge to base
    TARGET="$BASE_BRANCH"
fi
```

### 1. Squash and Merge (Recommended for feature branches)
```bash
# GitHub CLI
gh pr merge --squash --delete-branch

# Manual squash
git checkout $TARGET
git pull origin $TARGET
git merge --squash $CURRENT_BRANCH
git commit -m "[TASK-XXX] Feature: Description of changes"
git push origin $TARGET
```

### 2. Merge Commit (For preserving history)
```bash
# GitHub CLI
gh pr merge --merge --delete-branch

# Manual merge
git checkout $TARGET
git pull origin $TARGET
git merge --no-ff $CURRENT_BRANCH
git push origin $TARGET
```

### 3. Rebase and Merge (For linear history)
```bash
# GitHub CLI
gh pr merge --rebase --delete-branch

# Manual rebase
git checkout $CURRENT_BRANCH
git rebase $TARGET
git checkout $TARGET
git merge $CURRENT_BRANCH
git push origin $TARGET
```

## Automated Merge Flow

```markdown
1. Detect platform (GitHub/GitLab/Bitbucket)
2. Check PR approval status
3. Run final test suite
4. Select merge strategy based on:
   - Project conventions
   - Branch type (feature/hotfix/release)
   - Commit history complexity
5. Execute merge
6. Cleanup local and remote branches
7. Update task tracking
```

## Platform-Specific Commands

### GitHub
```bash
# Merge with GitHub CLI
gh pr merge [PR-NUMBER] \
  --squash \
  --delete-branch \
  --subject "[TASK-XXX] Feature description" \
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

### 3. Task Management Updates
- Mark task as completed in tracking system
- Update feature status in `/status.md`
- Archive related documentation
- Close related issues

### 4. Notify Team
```markdown
## Merge Completed ✅

**Branch**: feature/TASK-XXX-description
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

- Run `/test.md` before merge
- Update `/status.md` after merge
- Trigger `/sync.md` for team members
- Archive context with `/context-save.md`

## Safety Features

1. **Dry Run Mode**: Preview merge without executing
2. **Backup Creation**: Tag current main before merge
3. **Conflict Detection**: Abort if conflicts found
4. **Test Verification**: Ensure tests pass before merge

## Execution

Begin merge process immediately if PR number is provided or if current branch has an open PR. Always verify approval status and run tests before actual merge. Provide clear success/failure feedback.