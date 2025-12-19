---
allowed-tools: Read(*), Glob(*), Bash(git:*), Bash(gh:*), TodoWrite(*)
description: Generate daily progress summary for standup meetings
model: haiku
---

# Daily Standup Report

Generate a concise daily standup summary showing yesterday's work, today's plan, and any blockers. Perfect for team standups, daily planning, or progress tracking.

## Standup Report Structure

The report includes three key sections:
1. **Yesterday**: What was accomplished
2. **Today**: What's planned
3. **Blockers**: Issues preventing progress

## Implementation

### 1. Collect Git Activity (PARALLEL)

Run these git commands **IN PARALLEL** using multiple Bash tool calls in a single message:

```
# Call ALL of these simultaneously in ONE message:

Bash 1: git log --since="24 hours ago" --pretty=format:"%h - %s (%ar)" --author="$(git config user.email)"
Bash 2: git diff --stat HEAD~10..HEAD 2>/dev/null || git diff --stat
Bash 3: git status --short
Bash 4: gh pr list --author @me --state open 2>/dev/null || echo "No gh CLI"
```

This parallelizes data collection for faster standup generation.

### Git Data to Extract:
```bash
# Commits from last 24 hours (already run in parallel above)
COMMIT_COUNT=$(git log --since="24 hours ago" --author="$(git config user.email)" --oneline | wc -l)

# Summary of changes
git shortlog --since="24 hours ago" --author="$(git config user.email)" -s
```

### 2. Read Current Working State

Read `context/working-state.md` to get:
- Current Epic
- Current Feature
- Current Task
- Progress checkboxes

### 3. Check Recent Session Files

Look for recent checkpoint or handoff files:

```bash
# Find recent session files
RECENT_SESSIONS=$(find context/sessions/ -name "*.md" -mtime -1 2>/dev/null | sort -r)

if [ ! -z "$RECENT_SESSIONS" ]; then
  echo "📝 Recent session notes found"
  # Read the most recent one
fi
```

### 4. Analyze Task Progress

Read current task file from `context/features/*/tasks/current/*.md`:

```bash
# Find current task
CURRENT_TASK=$(find context/features/*/tasks/current/ -name "*.md" 2>/dev/null | head -1)

if [ -f "$CURRENT_TASK" ]; then
  echo "📋 Current task analysis:"
  # Extract acceptance criteria
  # Count completed vs total checkboxes
  TOTAL=$(grep -c "- \[" "$CURRENT_TASK")
  DONE=$(grep -c "- \[x\]" "$CURRENT_TASK")
  echo "Progress: $DONE / $TOTAL criteria complete"
fi
```

### 5. Check for Blockers

Identify potential blockers:

```bash
# Check for uncommitted changes that might indicate stuck work
UNCOMMITTED=$(git status --short | wc -l)

# Check for merge conflicts
CONFLICTS=$(git diff --name-only --diff-filter=U 2>/dev/null | wc -l)

# Check for failing tests (if test results file exists)
if [ -f "test-results.json" ] || [ -f ".test-results" ]; then
  echo "⚠️  Test results found - checking status"
fi

# Check for TODO/FIXME comments added recently
git diff HEAD~1 | grep -E "TODO|FIXME" || true
```

### 6. Read Backlog for Today's Plan

Read `context/backlog.md` and current task for planning:

```bash
# Check if there are pending tasks
TODO_TASKS=$(find context/features/*/tasks/todo/ -name "*.md" 2>/dev/null | wc -l)
echo "📋 Tasks in todo: $TODO_TASKS"
```

## Standup Report Format

Generate a formatted report:

```markdown
# Daily Standup Report
**Date**: [Today's date]
**Developer**: [From git config user.name]
**Project**: [From context/project.md]

---

## 🎯 Yesterday (Last 24 Hours)

### Completed Work
**Current Task**: [Task ID and name]
**Branch**: [Current branch]

### Progress Made
- [Commit 1 summary]
- [Commit 2 summary]
- [Commit 3 summary]
[List all commits from last 24 hours]

### Files Modified
- [File 1]: +X -Y lines
- [File 2]: +X -Y lines
[Show git diff --stat]

### Task Progress
**Acceptance Criteria**: X/Y complete (Z% done)
- [x] Completed criterion 1
- [x] Completed criterion 2
- [ ] Pending criterion 3

### Metrics
- **Commits**: X
- **Lines Added**: +XXX
- **Lines Removed**: -XXX
- **Files Changed**: XX
- **Time on Task**: [Estimate from task start date]

---

## 📋 Today (Next 24 Hours)

### Current Focus
**Task**: [Current task ID and name]
**Goal**: [Main objective for today]

### Planned Work
1. [Specific goal 1]
2. [Specific goal 2]
3. [Specific goal 3]

### Acceptance Criteria to Complete
- [ ] [Pending criterion 1]
- [ ] [Pending criterion 2]
- [ ] [Pending criterion 3]

### Next Steps
Based on current task and progress:
1. [Next concrete step]
2. [Following step]
3. [Final step before completion]

### Estimated Completion
- **Current Task**: [Today/Tomorrow/Date]
- **Overall Feature**: [Date estimate]

---

## 🚧 Blockers & Concerns

### Current Blockers
[If none: "✅ No blockers - on track!"]

[If blockers exist:]
1. **[Blocker 1]**
   - Impact: [High/Medium/Low]
   - Description: [Details]
   - Need: [What's needed to unblock]

2. **[Blocker 2]**
   - Impact: [High/Medium/Low]
   - Description: [Details]
   - Need: [What's needed to unblock]

### Risks & Concerns
[If any:]
- ⚠️ [Risk 1]: [Description and mitigation plan]
- ⚠️ [Risk 2]: [Description and mitigation plan]

[If none: "✅ No risks identified"]

### Help Needed
[If any:]
- [ ] [Specific help request 1]
- [ ] [Specific help request 2]

[If none: "✅ No assistance needed currently"]

---

## 📊 Status Summary

### Health Indicators
- **Task Progress**: [🟢 On Track | 🟡 At Risk | 🔴 Blocked]
- **Timeline**: [🟢 On Schedule | 🟡 Slightly Behind | 🔴 Behind]
- **Quality**: [🟢 Good | 🟡 Needs Attention | 🔴 Issues]
- **Tests**: [🟢 Passing | 🟡 Some Failing | 🔴 Many Failing]

### Overall Status
[One sentence summary of overall status]

### Team Updates
[Any information relevant to the team:]
- Completed PR: [PR #]
- Needs review: [PR #]
- Merged to main: [Feature name]
- Upcoming: [What's next after current task]

---

## 🔄 Git Status

### Current State
- **Branch**: [branch name]
- **Ahead of main**: [X commits]
- **Behind main**: [Y commits]
- **Uncommitted changes**: [Yes/No]
- **Stashed changes**: [Count]

### Recent Activity
```
[Git log output - last 5 commits]
```

### PR Status
[If PR exists:]
- **PR #**: [Number]
- **Status**: [Draft/Ready/Under Review/Approved]
- **Reviewers**: [Names]
- **Comments**: [Count]

[If no PR: "No open PR for current work"]

---

## 📈 Velocity & Trends

### This Week
- **Commits**: [Count]
- **Tasks Completed**: [Count]
- **PRs Merged**: [Count]
- **Days Active**: [Count]

### Trend
[Based on recent activity:]
- Velocity: [🔼 Increasing | ➡️ Steady | 🔽 Decreasing]
- Focus: [Single task | Multiple tasks]
- Quality: [High test coverage | Needs improvement]

---

## 🎬 Quick Actions

Based on current status, recommended actions:
- [ ] `/ccmagic:test` - Run tests before continuing
- [ ] `/ccmagic:sync` - Sync with main branch
- [ ] `/ccmagic:checkpoint` - Save current progress
- [ ] `/ccmagic:validate` - Run validation checks
- [ ] `/ccmagic:pr` - Create pull request (if ready)

---

## 💡 Notes

### Key Decisions Made
[From working-state.md or recent commits:]
- [Decision 1]
- [Decision 2]

### Learned Today
- [Learning 1]
- [Learning 2]

### Follow-up Items
- [ ] [Follow-up 1]
- [ ] [Follow-up 2]
```

## Smart Analysis

### Progress Detection

Automatically detect what kind of progress was made:

- **Feature work**: Implementation of core functionality
- **Bug fixes**: Commits with "fix:" prefix
- **Testing**: Test file changes
- **Refactoring**: Refactor commits
- **Documentation**: Doc file updates
- **Setup/Config**: Configuration changes

### Blocker Detection

Automatically identify potential blockers:

- Merge conflicts present
- Tests failing
- Missing dependencies
- Stuck on same task > 3 days
- No commits in 24 hours (when task is active)
- TODO/FIXME comments added
- Repeated reverts

### Health Scoring

Calculate overall health:

```
🟢 Healthy (80-100%)
- Making consistent progress
- Tests passing
- No blockers
- On schedule

🟡 At Risk (50-79%)
- Some blockers present
- Slightly behind schedule
- Some test failures
- Limited progress

🔴 Critical (0-49%)
- Major blockers
- Significant delays
- Many test failures
- Little/no progress
```

## Output Options

### Format Options

**Standard** (default):
```
Full detailed report with all sections
```

**Brief**:
```markdown
Quick summary:
Yesterday: [1-line summary]
Today: [1-line summary]
Blockers: [None/List]
```

**Slack Format**:
```
Formatted for Slack posting with emojis and sections
```

**Markdown**:
```
Clean markdown for documentation
```

## Integration Points

### With Other Commands

- **After `/ccmagic:checkpoint`**: Include checkpoint notes
- **Before `/ccmagic:handoff`**: Basis for handoff document
- **With `/ccmagic:status`**: Complementary daily view

### Team Workflows

- Copy output to team standup channel
- Paste into project management tools
- Include in daily email updates
- Attach to time tracking systems

## Usage Examples

### Morning Standup
```bash
# Generate standup report
/ccmagic:daily-standup

# Review the report
# Share in standup meeting
# Use "Today" section as daily plan
```

### End of Day Review
```bash
# Generate standup report
/ccmagic:daily-standup

# Review what was accomplished
# Plan tomorrow's work
# Checkpoint progress
/ccmagic:checkpoint
```

### Team Update
```bash
# Generate standup report
/ccmagic:daily-standup

# Copy relevant sections
# Share with team
# Address any blockers identified
```

## Automation Ideas

### Daily Email
Send standup report via email automatically:
```bash
/ccmagic:daily-standup --email team@company.com
```

### Slack Bot
Post to Slack channel:
```bash
/ccmagic:daily-standup --slack #team-standups
```

### Time Tracking
Log to time tracking system:
```bash
/ccmagic:daily-standup --log-time
```

## Pro Tips

1. **Run Daily**: Make it part of your morning routine
2. **Be Honest**: Don't hide blockers - surface them early
3. **Be Specific**: "Fixed auth bug" is better than "worked on auth"
4. **Look Ahead**: Use "Today" section to set clear goals
5. **Track Trends**: Review velocity over time
6. **Share Context**: Include enough detail for team awareness
7. **Update Status**: Use report to update working-state.md if stale

## Customization

### Project-Specific Metrics

Add custom metrics based on project:
- Test coverage percentage
- Build time
- Performance metrics
- Code review feedback

### Team Preferences

Adjust format based on team needs:
- Include/exclude certain sections
- Change verbosity level
- Add custom fields
- Integration with team tools

---

## Execution

Generate and display standup report immediately. Focus on:
- Clear, concise summaries
- Actionable information
- Honest blocker assessment
- Forward-looking plan

The report should be useful for both personal tracking and team communication.
