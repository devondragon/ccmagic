# Merge Conflict Resolution Guide for CCMagic Context Files

## Overview

When working with CCMagic in a team environment, merge conflicts in context files are a natural part of the workflow. This guide explains how to handle these conflicts effectively and maintain context integrity across your team.

## Understanding Context Conflicts

### Why Conflicts Happen

Context conflicts occur when:
- Multiple developers update `working-state.md` simultaneously
- Different features complete and update the same epic status
- Task files are moved by different branches
- Backlog items are added by multiple team members

**This is normal and expected!** Git's merge conflict resolution is the designed mechanism for handling these situations.

## Common Conflict Scenarios

### 1. Working State Conflicts

**Most Common Location**: `context/working-state.md`

**Typical Conflict**:
```markdown
<<<<<<< HEAD
## Current Focus
- **Epic**: 001-mvp
- **Feature**: 001-01-authentication
- **Task**: 001-01-003-password-reset
=======
## Current Focus
- **Epic**: 001-mvp  
- **Feature**: 001-02-payments
- **Task**: 001-02-001-stripe-integration
>>>>>>> feature/payments
```

**Resolution Strategy**:
- If merging to main: Choose the most recently completed work
- If both are active: Keep both sections, renaming one as "Recently Completed"
- Update timestamps to reflect the merge

**Resolved Example**:
```markdown
## Current Focus
- **Epic**: 001-mvp
- **Feature**: Multiple features in progress
- **Tasks**: See individual feature working states

## Recently Completed
- **Feature**: 001-01-authentication
  - **Task**: 001-01-003-password-reset (Completed: [date])
  
## In Progress
- **Feature**: 001-02-payments
  - **Task**: 001-02-001-stripe-integration (Started: [date])
```

### 2. Feature Progress Conflicts

**Location**: `context/features/[feature-id]/working-state.md`

**Typical Conflict**:
```markdown
<<<<<<< HEAD
### Tasks Status
- Completed: 3 / 10
- Progress: 30%
=======
### Tasks Status  
- Completed: 4 / 10
- Progress: 40%
>>>>>>> feature/parallel-work
```

**Resolution Strategy**:
- Take the higher completed count (most up-to-date)
- Verify by checking `tasks/completed/` directory
- Recalculate percentage if needed

### 3. Backlog Additions

**Location**: `context/backlog.md`

**Typical Conflict**:
```markdown
## 🚀 Feature Ideas
<<<<<<< HEAD
- Add dark mode support
- Implement real-time notifications
=======
- Add export functionality
- Create admin dashboard
>>>>>>> feature/planning
```

**Resolution Strategy**:
- Keep all items (merge both lists)
- Remove any duplicates
- Re-sort by priority if your team has a priority system

**Resolved**:
```markdown
## 🚀 Feature Ideas
- Add dark mode support
- Implement real-time notifications
- Add export functionality
- Create admin dashboard
```

### 4. Task File Movement Conflicts

**Scenario**: Same task moved to different directories

**Conflict**: Git shows file deleted in one place, added in another

**Resolution Strategy**:
1. Determine the correct status from commit history
2. Move file to appropriate directory (`current/`, `completed/`, or back to `todo/`)
3. Update the corresponding working-state files

```bash
# Check where the task should be
git log --follow -- "context/features/*/tasks/*/task-001.md"

# Move to correct location
mv context/features/001-01-core/tasks/current/task-001.md \
   context/features/001-01-core/tasks/completed/task-001.md
```

## Step-by-Step Conflict Resolution Process

### 1. Identify Conflicts

```bash
# After merge attempt
git status

# Shows something like:
# Unmerged paths:
#   both modified:   context/working-state.md
#   both modified:   context/backlog.md
```

### 2. Understand Both Sides

```bash
# See what each branch changed
git diff HEAD...feature/other-branch -- context/working-state.md

# Or use a visual tool
git mergetool
```

### 3. Open Conflict Files

Look for conflict markers:
- `<<<<<<< HEAD` - Your current branch's version
- `=======` - Separator
- `>>>>>>> branch-name` - Incoming branch's version

### 4. Apply Resolution Rules

#### For State Files (working-state.md):
- **Preserve all completed work** - Don't lose history
- **Keep most recent current state** - Reflects actual status
- **Merge all blockers** - Don't lose important warnings
- **Update timestamps** - Mark when merged

#### For Task Files:
- **Respect lifecycle** - todo → current → completed (never backwards)
- **One current task per developer** - Multiple devs = multiple current tasks OK
- **Preserve task history** - Completed tasks stay completed

#### For Knowledge Files:
- **Merge all additions** - Knowledge is cumulative
- **Latest version wins for updates** - Most recent understanding
- **Document conflicts as decisions** - Note why you chose one approach

### 5. Clean Up Markers

Remove all conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)

### 6. Validate Context Structure

```bash
# Ensure directory structure is intact
ls -la context/
ls -la context/features/*/tasks/

# Check for orphaned task files
find context -name "*.md" -type f | grep -E "(current|todo|completed)"

# Verify no conflict markers remain
grep -r "<<<<<<< HEAD" context/
```

### 7. Commit the Resolution

```bash
# Add resolved files
git add context/

# Commit with clear message
git commit -m "merge: Resolve context conflicts between [branches]

- Merged working states from authentication and payments features
- Combined backlog items from both branches
- Updated task progress counters"
```

## Prevention Strategies

### 1. Branch Hygiene

- **Feature branches for features**: Keep feature work isolated
- **Task branches for large tasks**: Prevent conflicts within features
- **Regular syncing**: Pull from main frequently

```bash
# Daily sync pattern
git checkout main
git pull origin main
git checkout feature/my-feature
git merge main  # Resolve conflicts early when they're small
```

### 2. Communication Patterns

- **Claim tasks explicitly**: Update working-state.md when starting
- **Quick handoffs**: Use `/ccmagic:handoff quick` for daily switches
- **Team sync meetings**: Review context/ changes in standups

### 3. Context Conventions

**Establish team rules**:
- Only one developer per feature at a time, OR
- Subdivide features into smaller task groups
- Designate a "context owner" for each epic who resolves conflicts

### 4. Smart Commit Messages

Include context changes in commit messages:
```bash
git commit -m "feat(001-01-auth): Complete login functionality

- Task: 001-01-002-login-endpoint
- Status: Moved to completed
- Context: Updated working-state.md"
```

## Conflict Resolution Tools

### Visual Merge Tools

Configure a visual merge tool for complex conflicts:
```bash
# Popular options
git config --global merge.tool vimdiff
git config --global merge.tool meld
git config --global merge.tool vscode

# Use during conflict
git mergetool
```

### VS Code Integration

VS Code provides excellent conflict resolution:
1. Click on conflicted file
2. Use "Accept Current Change", "Accept Incoming", or "Accept Both"
3. Or manually edit to combine both sides

### Diff Tools for Context

```bash
# See context changes between branches
diff -u <(git show main:context/working-state.md) \
        <(git show feature:context/working-state.md)

# Or use git's built-in
git diff main...feature -- context/
```

## Special Cases

### Epic Completion Conflicts

When multiple features complete an epic simultaneously:
1. Mark epic as complete in both branches
2. In merge, combine all completion notes
3. Update epic file with all feature completions

### Spike Conflicts

Research spikes might have conflicting conclusions:
1. Keep both research results
2. Create a "decision record" documenting why one approach was chosen
3. Move alternative approach to `knowledge/alternatives/`

### Emergency Hotfix Conflicts

When hotfixes conflict with feature work:
1. Hotfix changes take precedence
2. Rebase feature work after hotfix
3. Update context to reflect hotfix impact

## Recovery Procedures

### If Context Gets Corrupted

```bash
# Create backup
cp -r context/ context.backup/

# Reset to last known good state
git checkout main -- context/

# Manually re-apply work from backup
# Cherry-pick specific changes
```

### Lost Task Files

```bash
# Find deleted task files in git history
git log --all --full-history -- "**/tasks/**/task-*.md"

# Restore specific task file
git checkout <commit-hash> -- path/to/task-file.md
```

### Rebuilding Working State

If working-state.md is severely corrupted:
1. Check all feature working states
2. Scan task directories
3. Rebuild from current filesystem state

```bash
# Script to audit current state
find context/features -name "*.md" -path "*/current/*" | while read task; do
    echo "Active: $task"
done
```

## Best Practices Summary

### Do's ✅
- Commit context changes with code changes
- Pull from main frequently
- Communicate task claims in working-state.md
- Use handoff documents for context switches
- Preserve history in completed sections
- Document conflict resolutions

### Don'ts ❌
- Don't delete completed task history
- Don't move tasks backwards (completed → todo)
- Don't ignore conflict markers
- Don't resolve blindly without understanding both sides
- Don't work on same task simultaneously without coordination

## Team Workflows

### For Small Teams (2-5 developers)
- One developer per feature
- Merge to main after each task
- Quick daily syncs
- Simple branch protection

### For Larger Teams (5+ developers)
- Feature owners resolve feature conflicts
- Epic owners resolve epic-level conflicts
- Dedicated integration branch
- Regular context synchronization meetings

### For Distributed Teams
- Time-zone based handoffs
- Detailed handoff documents mandatory
- Async conflict resolution via PRs
- Context changes require PR review

## Quick Reference Card

```bash
# Common conflict resolution commands

# Start resolution
git status                          # See conflicted files
git diff --name-only --diff-filter=U # List only conflicted files

# Examine conflicts
git log --merge --oneline          # See commits causing conflict
git diff --ours                    # See our version
git diff --theirs                   # See their version

# Resolve
edit context/working-state.md      # Manual resolution
git add context/working-state.md   # Mark as resolved

# Abort if needed
git merge --abort                   # Cancel merge
git reset --hard HEAD               # Reset to pre-merge state

# Complete
git commit                          # Finish merge
git push                           # Share resolution
```

## Conclusion

Context conflicts are a normal part of team development with CCMagic. By following these patterns and understanding that git's merge mechanism is your friend, teams can work effectively in parallel while maintaining a coherent project context.

Remember: **Conflicts are communication** - they show where team members' work intersects and need coordination.

---

*Last Updated: 2024*
*For CCMagic version: 1.0+*