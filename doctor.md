---
allowed-tools: Read(*), Glob(*), Bash(*)
description: Diagnose CCMagic setup issues and validate installation
model: claude-sonnet-4-20250514
---

# CCMagic Doctor - System Health Check

Run comprehensive diagnostics to identify and help fix CCMagic setup issues.

## Diagnostic Process

### 1. Check Directory Structure

Verify that all required directories exist:

```bash
# Core directories
test -d context && echo "✅ context/ exists" || echo "❌ context/ missing"
test -d context/epics && echo "✅ context/epics/ exists" || echo "⚠️  context/epics/ missing"
test -d context/features && echo "✅ context/features/ exists" || echo "⚠️  context/features/ missing"
test -d context/spikes && echo "✅ context/spikes/ exists" || echo "⚠️  context/spikes/ missing"
test -d context/knowledge && echo "✅ context/knowledge/ exists" || echo "⚠️  context/knowledge/ missing"
test -d context/sessions && echo "✅ context/sessions/ exists" || echo "⚠️  context/sessions/ missing"
```

### 2. Check Core Files

Verify essential configuration files:

```bash
# Core configuration files
test -f context/project.md && echo "✅ project.md exists" || echo "❌ project.md missing"
test -f context/conventions.md && echo "✅ conventions.md exists" || echo "❌ conventions.md missing"
test -f context/working-state.md && echo "✅ working-state.md exists" || echo "❌ working-state.md missing"
test -f context/backlog.md && echo "✅ backlog.md exists" || echo "⚠️  backlog.md missing"
test -f context/branching.md && echo "✅ branching.md exists" || echo "⚠️  branching.md missing"
```

### 3. Git Configuration

Check git setup:

```bash
# Git repository check
git rev-parse --git-dir 2>/dev/null && echo "✅ Git repository initialized" || echo "❌ Not a git repository"

# Git configuration
git config user.name >/dev/null 2>&1 && echo "✅ Git user.name configured: $(git config user.name)" || echo "⚠️  Git user.name not set"
git config user.email >/dev/null 2>&1 && echo "✅ Git user.email configured: $(git config user.email)" || echo "⚠️  Git user.email not set"

# Current branch
echo "📍 Current branch: $(git branch --show-current 2>/dev/null || echo 'N/A')"

# Remote configuration
git remote -v 2>/dev/null | head -1 && echo "✅ Git remote configured" || echo "⚠️  No git remote configured"
```

### 4. Check CCMagic Commands Installation

Verify CCMagic commands are accessible:

```bash
# Check if CCMagic is installed in Claude Code
test -d ~/.claude/commands/ccmagic && echo "✅ CCMagic commands installed" || echo "❌ CCMagic not found in ~/.claude/commands/ccmagic"

# Count available commands
if [ -d ~/.claude/commands/ccmagic ]; then
  CMD_COUNT=$(ls -1 ~/.claude/commands/ccmagic/*.md 2>/dev/null | wc -l)
  echo "📊 Available commands: $CMD_COUNT"
fi
```

### 5. Check Epics and Features

Analyze project structure:

```bash
# Count epics
EPIC_COUNT=$(ls -1 context/epics/*.md 2>/dev/null | wc -l)
echo "📚 Epics defined: $EPIC_COUNT"

# Count features
FEATURE_COUNT=$(ls -d context/features/*/ 2>/dev/null | wc -l)
echo "🎯 Features defined: $FEATURE_COUNT"

# Count tasks
TODO_COUNT=$(find context/features/*/tasks/todo/ -name "*.md" 2>/dev/null | wc -l)
CURRENT_COUNT=$(find context/features/*/tasks/current/ -name "*.md" 2>/dev/null | wc -l)
COMPLETED_COUNT=$(find context/features/*/tasks/completed/ -name "*.md" 2>/dev/null | wc -l)
echo "📋 Tasks - Todo: $TODO_COUNT, Current: $CURRENT_COUNT, Completed: $COMPLETED_COUNT"
```

### 6. Working State Validation

Check current work status from working-state.md:

Read `context/working-state.md` and extract:
- Current Epic
- Current Feature
- Current Task
- Branch status
- Last updated date

### 7. File Permissions

Check that files are readable and writable:

```bash
# Check key file permissions
for file in context/project.md context/conventions.md context/working-state.md; do
  if [ -f "$file" ]; then
    if [ -r "$file" ] && [ -w "$file" ]; then
      echo "✅ $file: Read/Write OK"
    else
      echo "❌ $file: Permission issue"
      ls -l "$file"
    fi
  fi
done
```

### 8. Branch Naming Convention Check

Verify branch follows naming conventions:

```bash
# Get current branch
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)

if [ ! -z "$CURRENT_BRANCH" ]; then
  echo "📍 Current branch: $CURRENT_BRANCH"

  # Check if branch follows CCMagic conventions
  if [[ "$CURRENT_BRANCH" =~ ^(feature|task|spike)/.* ]]; then
    echo "✅ Branch follows naming convention"
  elif [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ] || [ "$CURRENT_BRANCH" = "develop" ]; then
    echo "⚠️  Working on base branch (not recommended for active development)"
  else
    echo "⚠️  Branch doesn't follow recommended convention (feature/*, task/*, spike/*)"
  fi
fi
```

### 9. Check for Common Issues

Identify common problems:

#### Issue: Multiple tasks in current/
```bash
CURRENT_TASKS=$(find context/features/*/tasks/current/ -name "*.md" 2>/dev/null | wc -l)
if [ "$CURRENT_TASKS" -gt 1 ]; then
  echo "⚠️  WARNING: Multiple tasks in current/ directory"
  echo "   Found $CURRENT_TASKS tasks - should typically have only 1"
  find context/features/*/tasks/current/ -name "*.md" 2>/dev/null
fi
```

#### Issue: Uncommitted changes
```bash
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  echo "⚠️  Uncommitted changes detected"
  echo "   Run 'git status' to see changes"
else
  echo "✅ No uncommitted changes"
fi
```

#### Issue: Behind remote
```bash
git fetch origin 2>/dev/null
LOCAL=$(git rev-parse @ 2>/dev/null)
REMOTE=$(git rev-parse @{u} 2>/dev/null)
if [ ! -z "$LOCAL" ] && [ ! -z "$REMOTE" ]; then
  if [ "$LOCAL" = "$REMOTE" ]; then
    echo "✅ Up to date with remote"
  else
    BASE=$(git merge-base @ @{u} 2>/dev/null)
    if [ "$LOCAL" = "$BASE" ]; then
      echo "⚠️  Behind remote - need to pull"
    elif [ "$REMOTE" = "$BASE" ]; then
      echo "✅ Ahead of remote"
    else
      echo "⚠️  Branches have diverged"
    fi
  fi
fi
```

### 10. Dependency Check

Check if required tools are available:

```bash
# Check for required tools
command -v git >/dev/null 2>&1 && echo "✅ git installed" || echo "❌ git not found"
command -v gh >/dev/null 2>&1 && echo "✅ gh (GitHub CLI) installed" || echo "⚠️  gh not installed (optional)"
command -v node >/dev/null 2>&1 && echo "✅ node installed: $(node --version)" || echo "⚠️  node not found"
command -v npm >/dev/null 2>&1 && echo "✅ npm installed: $(npm --version)" || echo "⚠️  npm not found"
```

## Diagnostic Report Summary

Generate a summary report:

```markdown
# CCMagic Doctor Report
Generated: [timestamp]

## Status Overview
- **Overall Health**: [✅ Healthy | ⚠️  Warnings | ❌ Critical Issues]
- **Project**: [project name from project.md]
- **Current Branch**: [branch name]
- **Active Task**: [task from working-state.md]

## Issues Found
[List of issues with severity]

### Critical (Must Fix)
- [Critical issue 1]
- [Critical issue 2]

### Warnings (Should Fix)
- [Warning 1]
- [Warning 2]

### Info
- [Info item 1]

## Recommendations

### Immediate Actions
1. [Action 1]
2. [Action 2]

### Optional Improvements
1. [Improvement 1]
2. [Improvement 2]

## Quick Fixes

### If CCMagic not initialized:
Run: `/ccmagic:init`

### If git not configured:
```bash
git config user.name "Your Name"
git config user.email "your.email@example.com"
```

### If missing directories:
Run: `/ccmagic:init` to recreate structure

### If multiple current tasks:
Move extra tasks back to todo/ or completed/

### If working-state.md is stale:
Run: `/ccmagic:status` to refresh

## System Information
- **OS**: [OS type]
- **Git Version**: [version]
- **Node Version**: [version if applicable]
- **CCMagic Version**: [check README or package.json]

## Next Steps
Based on the health check results:
1. [Step 1 based on findings]
2. [Step 2 based on findings]
3. [Step 3 based on findings]
```

## Auto-Fix Suggestions

For each issue found, provide specific fix commands:

### Missing directory structure
```bash
# Run init command to create missing directories
/ccmagic:init
```

### Git not configured
```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### Multiple current tasks
```
Move extra tasks:
- Review each task in context/features/*/tasks/current/
- Move completed ones to completed/
- Move pending ones to todo/
- Keep only the active task in current/
```

### Outdated working-state.md
```bash
# Update working state with current status
/ccmagic:status
```

## Preventive Health Tips

1. **Daily**: Run `/ccmagic:daily-standup` to keep tracking current
2. **Before work**: Run `/ccmagic:sync` to stay updated
3. **After work**: Run `/ccmagic:checkpoint` to save state
4. **Weekly**: Review and clean up completed tasks
5. **Monthly**: Archive old sessions and spikes

---

**Doctor Complete!**

If any critical issues were found, address them before continuing development.
For questions about specific issues, check `/ccmagic:help` for detailed command information.
