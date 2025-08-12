# Pull Request Command

Create a well-structured pull request from the current branch to the appropriate target branch based on your configured branching strategy.

## Reading Branching Configuration

```bash
# Load branching configuration
if [ -f "context/branching.md" ]; then
    echo "📖 Loading branching configuration..."
    # Parse strategy and base branch from branching.md
else
    echo "⚠️ No branching configuration found. Using defaults (main branch)."
fi
```

## PR Target Branch Determination

Based on your configured strategy in `context/branching.md`:
- **Strategy A (Hierarchical)**: Task branches → Feature branches → Base branch
- **Strategy B (Direct)**: Task branches → Base branch
- **Strategy C (Single Feature)**: Feature branches → Base branch

## PR Creation Process

1. **Pre-flight Checks**: Ensure branch is ready for PR
2. **Determine Target Branch**: Based on branching strategy
3. **Generate Description**: Create detailed PR description from commits and changes
4. **Add Metadata**: Labels, reviewers, and project boards
5. **Create PR**: Submit to GitHub/GitLab/Bitbucket

## Pre-flight Checks

Run these checks before creating PR:
1. All changes committed (`git status`)
2. Branch is up-to-date with target branch (`git fetch && git merge-base`)
3. Tests pass (run `/ccmagic:test`)
4. Code is linted (check for lint command)
5. No merge conflicts with target branch

## PR Description Generation

### Automatic Description Building

1. **Extract from Commits**:
   ```bash
   git log main..HEAD --oneline
   ```

2. **Analyze Changed Files**:
   ```bash
   git diff main...HEAD --name-status
   ```

3. **Check for Breaking Changes**:
   - API changes
   - Database migrations
   - Config changes
   - Dependency updates

### PR Template Structure

```markdown
## Summary
[Brief description of what this PR accomplishes]

## Changes
- [Major change 1]
- [Major change 2]
- [List key modifications]

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Code refactoring

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] Test coverage maintained or improved

## Screenshots (if applicable)
[Add screenshots for UI changes]

## Related Issues
Closes #[issue number]
Related to #[issue number]

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No new warnings generated
- [ ] Tests added for new features
- [ ] All tests passing locally

## Additional Notes
[Any additional context or notes for reviewers]
```

## Platform-Specific Commands

### Determining Target Branch
```bash
# Determine target branch based on current branch and strategy
CURRENT_BRANCH=$(git branch --show-current)

if [[ "$STRATEGY" == *"A"* ]]; then
    # Hierarchical: task→feature or feature→base
    if [[ "$CURRENT_BRANCH" == task/* ]]; then
        # Extract feature from task branch or context
        TARGET_BRANCH="feature/[feature-id]"
    else
        TARGET_BRANCH="$BASE_BRANCH"
    fi
elif [[ "$STRATEGY" == *"B"* ]]; then
    # Direct: always to base branch
    TARGET_BRANCH="$BASE_BRANCH"
elif [[ "$STRATEGY" == *"C"* ]]; then
    # Single feature: feature→base
    TARGET_BRANCH="$BASE_BRANCH"
fi
```

### GitHub
```bash
# Using GitHub CLI (gh)
gh pr create \
  --title "[TASK-XXX] Feature description" \
  --body "$(cat pr-description.md)" \
  --base "$TARGET_BRANCH" \
  --assignee @me \
  --label "enhancement,needs-review"

# Add reviewers if team members are configured
gh pr create --reviewer teammate1,teammate2
```

### GitLab
```bash
# Using GitLab CLI (glab)
glab mr create \
  --title "[TASK-XXX] Feature description" \
  --description "$(cat pr-description.md)" \
  --target-branch "$TARGET_BRANCH" \
  --assign-to @me
```

### Bitbucket
```bash
# Using Bitbucket CLI or API
# Create PR via API call with appropriate credentials
```

## Smart Features

### 1. Auto-detect Platform
Check git remote to determine platform:
```bash
git remote -v | grep origin
```

### 2. Conventional Commits
If project uses conventional commits, parse them:
- `feat:` → New Feature label
- `fix:` → Bug Fix label
- `docs:` → Documentation label
- `perf:` → Performance label

### 3. Task/Issue Linking
Extract task IDs from branch name or commits:
- Branch: `feature/TASK-123-user-auth`
- Commit: `[TASK-123] Add login functionality`

### 4. Draft PR Option
Create as draft if:
- WIP commits present
- Tests failing
- User specifies draft mode

## Post-Creation Actions

1. **Output PR URL** for user reference
2. **Set PR status** in task tracking
3. **Notify team** if configured
4. **Update local tracking**:
   ```bash
   git branch --set-upstream-to=origin/$(git branch --show-current)
   ```

## Integration with Other Commands

- Automatically run `/test.md` before creating PR
- Use `/review.md` output to enhance PR description
- Update `/status.md` after PR creation

## Execution

Begin PR creation process immediately. If gh/glab CLI is not installed, provide manual instructions for creating PR via web interface with the generated description.