---
allowed-tools: Read(*), Bash(git:*), Bash(gh:*), Glob(*), LS(*)
description: Show current work status (fast, lightweight check)
model: claude-haiku-4-20250514
---

# Status Command

Display comprehensive project status including current work, pending tasks, blockers, and overall progress.

## Status Information Gathering

Collect and display information from multiple sources:
1. Git repository state
2. Task tracking files
3. Feature progress
4. Test results
5. PR status
6. Team blockers

## Implementation

### 1. Git Repository Status

```bash
# Current branch and status
git branch --show-current
git status --short

# Commits ahead/behind main
git rev-list --left-right --count main...HEAD

# Recent commits
git log --oneline -5

# Stashed changes
git stash list
```

### 2. Task and Feature Status

Check for task tracking files:
- Read `/context/current-task.md`
- Read `/context/current-feature.md`
- Parse TODO comments in code
- Check for `.todo` files

### 3. Project Metrics

```bash
# Lines of code changed
git diff --stat main...HEAD

# Files modified
git diff --name-only main...HEAD | wc -l

# Test coverage (if available)
npm run test:coverage -- --reporter=json --silent

# Open PRs
gh pr list --state open --author @me

# Open issues assigned
gh issue list --assignee @me --state open
```

## Status Report Format

```markdown
# Project Status Report
Generated: [timestamp]

## Current Work
### Active Branch
📍 **Branch**: feature/TASK-123-user-authentication
📊 **Status**: 12 commits ahead, 0 behind main
⏱️ **Started**: 2 days ago
👤 **Author**: [git config user.name]

### Current Task
**Task ID**: TASK-123
**Description**: Implement user authentication
**Progress**: 75% complete
**Blockers**: None

## Changes Summary
### Files Modified: 15
- `src/auth/` (8 files)
- `tests/auth/` (5 files)
- `docs/` (2 files)

### Statistics
- **Lines Added**: +1,234
- **Lines Removed**: -456
- **Net Change**: +778

## Recent Commits
```
abc1234 feat: Add JWT token generation
def5678 test: Add auth service tests
ghi9012 refactor: Extract validation logic
jkl3456 fix: Handle edge case in login
mno7890 docs: Update auth documentation
```

## Test Status
✅ **All Tests Passing**
- Unit Tests: 145/145 ✅
- Integration Tests: 23/23 ✅
- E2E Tests: 12/12 ✅
- Coverage: 87.3%

## Pull Requests
### Open PRs (2)
1. #123 - [TASK-123] User authentication (Ready for review)
2. #120 - [TASK-120] Database migrations (In progress)

### Recently Merged (3)
- #119 - API rate limiting ✅
- #118 - Error handling improvements ✅
- #117 - Performance optimizations ✅

## Pending Tasks
### High Priority
- [ ] TASK-124: Add password reset flow
- [ ] TASK-125: Implement OAuth providers
- [ ] TASK-126: Add session management

### Medium Priority
- [ ] TASK-127: Improve error messages
- [ ] TASK-128: Add audit logging
- [ ] TASK-129: Update documentation

### Low Priority
- [ ] TASK-130: Refactor test utilities
- [ ] TASK-131: Add performance benchmarks

## Blockers & Issues
### Current Blockers
⚠️ **None identified**

### Potential Risks
- Database migration needs review before production
- OAuth provider credentials needed for integration

## Team Activity
### Recent Merges to Main
- 2 hours ago: Payment processing feature
- Yesterday: Bug fixes for user profile
- 2 days ago: API documentation updates

## Recommendations
### Immediate Actions
1. Complete current task testing
2. Request code review for PR #123
3. Sync with main branch (2 new commits)

### Upcoming Milestones
- Sprint ends in 3 days
- Release scheduled for next week
- Feature freeze in 5 days

## Quick Actions
- Run `/test.md` to verify all tests pass
- Run `/sync.md` to update with main
- Run `/pr.md` to create pull request
- Run `/validate.md` for pre-commit checks
```

## Interactive Features

### 1. Filter by Category
Allow filtering status output:
- `--tasks` - Show only task information
- `--git` - Show only git status
- `--tests` - Show only test results
- `--prs` - Show only PR information

### 2. Verbosity Levels
- `--brief` - One-line summary
- `--normal` - Standard output (default)
- `--verbose` - Detailed information
- `--json` - Machine-readable format

### 3. Time-based Views
- `--today` - Today's activity
- `--week` - This week's progress
- `--sprint` - Current sprint status

## Integration Points

### With Task Management
- Parse task IDs from branch names
- Read task descriptions from commits
- Update task status in external systems

### With CI/CD
- Show build status from GitHub Actions
- Display deployment status
- Include pipeline health

### With Team Tools
- Slack notifications for blockers
- JIRA/Linear integration for tasks
- Calendar integration for deadlines

## Health Indicators

### 🟢 Green (Healthy)
- All tests passing
- No merge conflicts
- On track for deadline

### 🟡 Yellow (Attention Needed)
- Some tests failing
- Behind schedule
- Pending reviews > 2 days

### 🔴 Red (Critical)
- Blocking issues present
- Major test failures
- Overdue deliverables

## Execution

Generate and display status immediately without confirmation. Highlight critical information with colors/emojis. Provide actionable recommendations based on current state. Cache expensive operations for 5 minutes to improve performance on repeated calls.
