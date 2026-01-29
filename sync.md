---
allowed-tools: Read(*), Bash(git:*), Glob(*)
description: Synchronize branch with base, handling conflicts intelligently
model: sonnet
---

# Sync Command

Synchronize your current branch with the configured base branch, handling conflicts intelligently and maintaining a clean history.

## MCP Tool Availability

This command uses built-in git tools and does not require MCP tools. All functionality is available through:
- Git CLI for fetch, merge, rebase, and stash operations
- Built-in conflict detection and resolution guidance

## Reading Branching Configuration

```bash
# Load branching configuration
if [ -f "context/branching.md" ]; then
    echo "📖 Loading branching configuration..."
    STRATEGY=$(grep "Strategy:" context/branching.md | head -1)
    BASE_BRANCH=$(grep "Primary Branch:" context/branching.md | head -1 | cut -d: -f2 | tr -d ' ')
else
    echo "⚠️ No branching configuration found. Using defaults."
    BASE_BRANCH="main"
fi
```

## Sync Strategy

1. **Save Current State**: Stash or commit work in progress
2. **Update Base Branch**: Fetch and update configured base branch
3. **Merge or Rebase**: Apply base branch changes to current branch
4. **Resolve Conflicts**: Handle any merge conflicts
5. **Restore State**: Re-apply stashed changes if needed

## Implementation Flow

### 1. Pre-Sync Checks

```bash
# Check for uncommitted changes
git status --porcelain

# Save current branch name
CURRENT_BRANCH=$(git branch --show-current)

# Verify we're not on base branch
if [ "$CURRENT_BRANCH" = "$BASE_BRANCH" ]; then
  echo "Already on $BASE_BRANCH branch, pulling latest..."
  git pull origin $BASE_BRANCH
  exit 0
fi
```

### 2. Save Work in Progress

```bash
# Check if there are changes to stash
if ! git diff-index --quiet HEAD --; then
  echo "Stashing uncommitted changes..."
  git stash push -m "sync-stash-$(date +%Y%m%d-%H%M%S)"
  STASHED=true
fi
```

### 3. Update Base Branch

```bash
# Fetch all remote changes
git fetch origin

# Update local base branch without switching
git fetch origin $BASE_BRANCH:$BASE_BRANCH

# Or switch and pull
git checkout $BASE_BRANCH
git pull origin $BASE_BRANCH
git checkout $CURRENT_BRANCH
```

### 4. Sync Strategy Selection

#### Strategy-Aware Sync Target
```bash
# Determine sync target based on branch type and strategy
if [[ "$STRATEGY" == *"A"* ]]; then
    # Hierarchical: sync with feature branch if on task branch
    if [[ "$CURRENT_BRANCH" == task/* ]]; then
        # Extract feature branch from task name or context
        SYNC_TARGET="feature/[feature-id]"
        echo "Syncing task branch with feature branch: $SYNC_TARGET"
    else
        SYNC_TARGET="$BASE_BRANCH"
        echo "Syncing feature branch with $BASE_BRANCH"
    fi
else
    # Direct (B) or Single Feature (C): always sync with base
    SYNC_TARGET="$BASE_BRANCH"
    echo "Syncing with $BASE_BRANCH"
fi
```

#### Option A: Merge (Preserves branch history)
```bash
git merge $SYNC_TARGET --no-edit

# Or with message
git merge $SYNC_TARGET -m "Merge $SYNC_TARGET into $CURRENT_BRANCH"
```

#### Option B: Rebase (Linear history)
```bash
git rebase $SYNC_TARGET

# Interactive rebase for cleanup
git rebase -i $SYNC_TARGET
```

#### Option C: Smart Selection
```bash
# Use rebase for feature branches with few commits
COMMIT_COUNT=$(git rev-list --count $SYNC_TARGET..$CURRENT_BRANCH)

if [ $COMMIT_COUNT -le 5 ]; then
  echo "Using rebase (few commits)..."
  git rebase $SYNC_TARGET
else
  echo "Using merge (many commits)..."
  git merge $SYNC_TARGET
fi
```

### 5. Conflict Resolution

```bash
# Check for conflicts
if git diff --name-only --diff-filter=U | grep -q .; then
  echo "Conflicts detected in:"
  git diff --name-only --diff-filter=U
  
  # Provide conflict resolution guidance
  echo "
  Conflict Resolution Guide:
  1. Open conflicted files
  2. Look for <<<<<<< markers
  3. Choose correct version or combine
  4. Remove conflict markers
  5. Stage resolved files: git add <file>
  6. Continue sync: git rebase --continue or git merge --continue
  "
fi
```

## Automated Conflict Resolution

### 1. Strategy Patterns

```bash
# Always prefer main for certain files
git checkout --theirs package-lock.json
git checkout --theirs yarn.lock

# Always prefer current branch for others
git checkout --ours .env.local
git checkout --ours config/local.js

# Auto-merge certain file types
git merge-file --theirs migrations/*.sql
```

### 2. Semantic Conflict Resolution

For code conflicts, analyze and suggest resolutions:

```javascript
// Detect import conflicts
if (conflict.includes('import')) {
  // Merge both sets of imports
  mergeImports(theirImports, ourImports);
}

// Detect function signature changes
if (conflict.includes('function') || conflict.includes('=>')) {
  // Suggest keeping version with more parameters
  suggestFunctionMerge();
}
```

## Sync Report Format

```markdown
# Sync Complete ✅

## Summary
- **Branch**: feature/user-auth
- **Synced with**: {{SYNC_TARGET}} (15 new commits)
- **Strategy**: {{STRATEGY_NAME}}
- **Conflicts**: 2 resolved

## Changes from {{SYNC_TARGET}}
### New Files (3)
- src/utils/newHelper.js
- tests/integration/api.test.js
- docs/API.md

### Modified Files (8)
- src/index.js (+45, -12)
- src/auth/login.js (+23, -8)
- package.json (+2 dependencies)
- [... 5 more]

### Deleted Files (1)
- src/deprecated/oldAuth.js

## Conflict Resolution
### File: src/auth/login.js
- **Conflict**: Function parameter mismatch
- **Resolution**: Kept both parameters, updated function body

### File: package.json
- **Conflict**: Dependency version
- **Resolution**: Used newer version from {{SYNC_TARGET}}

## Your Changes Status
✅ All your commits preserved
✅ No changes lost
✅ Tests still passing

## Next Steps
1. Run tests: `/test.md`
2. Validate code: `/validate.md`
3. Continue development
```

## Advanced Features

### 1. Backup Before Sync

```bash
# Create backup branch
git branch backup-$CURRENT_BRANCH-$(date +%Y%m%d)

# Or create a tag
git tag sync-backup-$(date +%Y%m%d-%H%M%S)
```

### 2. Selective Sync

```bash
# Sync only specific files from configured base branch
git checkout $SYNC_TARGET -- path/to/specific/file

# Cherry-pick specific commits
git cherry-pick abc123 def456

# Partial merge
git merge $SYNC_TARGET --no-commit
git reset HEAD path/to/exclude
git commit
```

### 3. Auto-sync Schedule

```bash
# Check if sync needed (behind sync target)
BEHIND=$(git rev-list --count HEAD..origin/$SYNC_TARGET)
if [ $BEHIND -gt 10 ]; then
  echo "⚠️ You're $BEHIND commits behind $SYNC_TARGET. Run sync!"
fi
```

### 4. Team Sync Coordination

```bash
# Notify team of major sync
if [ $BEHIND -gt 50 ]; then
  echo "Major sync performed. Team notification sent."
  # Send Slack/Discord notification
fi
```

## Post-Sync Actions

### 1. Dependency Updates
```bash
# Node.js
npm install || yarn install

# Python
pip install -r requirements.txt || poetry install

# Go
go mod download
```

### 2. Database Migrations
```bash
# Check for new migrations
git diff --name-only $SYNC_TARGET...HEAD | grep migrations/

# Run migrations if found
npm run migrate || python manage.py migrate
```

### 3. Rebuild Assets
```bash
# Rebuild if build files changed
if git diff --name-only $SYNC_TARGET...HEAD | grep -E "webpack|vite|rollup"; then
  npm run build
fi
```

## Error Recovery

### If Sync Fails

```bash
# Abort merge
git merge --abort

# Abort rebase
git rebase --abort

# Restore from stash
git stash pop

# Reset to backup
git reset --hard backup-branch
```

### If Changes Lost

```bash
# Check reflog
git reflog

# Restore lost commit
git cherry-pick [lost-commit-hash]

# Restore from stash list
git stash list
git stash apply stash@{n}
```

## Integration with Other Commands

- Run after `/status.md` shows you're behind
- Run before `/pr.md` to avoid conflicts
- Include in daily workflow routine
- Chain with `/validate.md` after sync

## Execution

Begin sync immediately without confirmation. Automatically detect and use the appropriate sync strategy. Provide clear progress updates during sync. Handle conflicts intelligently with suggestions. Always ensure no work is lost during the process.