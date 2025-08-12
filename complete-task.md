---
allowed-tools: Write(*), Read(*), Bash(git:*, mv:*, gh:*), LS(*), Glob(*)
description: Mark a task as complete and update all tracking
argument-hint: [task-id or 'current']
model: claude-sonnet-4-20250514
---

# Complete Task

## Completing Your Task...

I'll help you mark a task as complete, verify all criteria are met, and update all tracking.

### 1. Identifying Task to Complete:

```bash
# Check for task argument or find current task
if [ "$1" = "current" ] || [ -z "$1" ]; then
    echo "🔍 Finding current active task..."
    TASK_FILE=$(find context/features/*/tasks/current -name "*.md" -type f | head -1)
    if [ -z "$TASK_FILE" ]; then
        echo "❌ No active task found in current/ directories"
        exit 1
    fi
else
    echo "🔍 Looking for task: $1"
    # Search in current directories first, then todo
    TASK_FILE=$(find context/features/*/tasks -name "*$1*.md" -type f | head -1)
fi

TASK_ID=$(basename "$TASK_FILE" .md)
echo "📋 Task identified: $TASK_ID"
```

### 2. Reading Task Details:

Loading task file to verify completion readiness...

```markdown
# Task: {{task_id}}

## Parent Feature
{{feature_id}} - {{feature_name}}

## Acceptance Criteria
{{criteria_list}}

## Current Status
- Started: {{start_time}}
- Time Spent: {{duration}}
- Branch: {{branch_name}}
```

### 3. Pre-Completion Checks:

#### Quality Checks:
```bash
echo "🔍 Running pre-completion checks..."

# Check for tests
echo "Running tests..."
if command -v npm &> /dev/null && [ -f "package.json" ]; then
    npm test || echo "⚠️ Tests failed or not configured"
fi

# Check for linting
echo "Running linter..."
if command -v npm &> /dev/null && [ -f "package.json" ]; then
    npm run lint || echo "⚠️ Linting issues found"
fi

# Check for uncommitted changes
UNCOMMITTED=$(git status --porcelain | wc -l)
if [ $UNCOMMITTED -gt 0 ]; then
    echo "⚠️ You have $UNCOMMITTED uncommitted changes"
    echo "Please commit or stash changes before completing task"
fi
```

#### Acceptance Criteria Verification:
```markdown
## ✅ Acceptance Criteria Checklist

Please verify all criteria are met:

{{for each criterion}}
- [x] {{criterion_text}}
  Status: {{COMPLETED/PARTIAL/BLOCKED}}
  Notes: {{implementation_notes}}
{{/for}}

Additional work completed:
- [x] Tests written and passing
- [x] Documentation updated
- [x] Code reviewed (self or peer)
- [x] No console errors
- [x] Performance acceptable

Overall Completion: {{percentage}}%
```

### 4. Completion Notes & Summary:

```markdown
## Completion Summary

### What was accomplished?
{{detailed_accomplishments}}

### Technical decisions made:
{{decisions_list}}

### Known limitations or tech debt:
{{limitations_if_any}}

### Follow-up tasks created:
{{new_tasks_if_any}}

### Time Analysis:
- Estimated: {{original_estimate}}
- Actual: {{actual_time}}
- Variance: {{variance_percentage}}%

### Learnings:
{{what_was_learned}}
```

### 5. Updating Task File:

Adding completion metadata to task file:

```markdown
---
## ✅ COMPLETED

**Completed Date**: {{current_date}}
**Completed By**: {{developer}}
**Final Status**: Done
**Time Taken**: {{total_duration}}

### Completion Notes:
{{completion_summary}}

### Test Coverage:
- Unit Tests: {{unit_coverage}}%
- Integration Tests: {{integration_coverage}}%
- E2E Tests: {{e2e_status}}

### Performance Metrics:
{{performance_notes}}

### Next Steps:
{{follow_up_items}}
---
```

### 6. Moving Task File:

```bash
# Determine source and destination paths
SOURCE_DIR=$(dirname "$TASK_FILE")
FEATURE_DIR=$(echo "$SOURCE_DIR" | sed 's/\/tasks\/current//')
DEST_DIR="$FEATURE_DIR/tasks/completed"

# Create completed directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Move task file
mv "$TASK_FILE" "$DEST_DIR/$TASK_ID.md"
echo "✅ Task moved to completed/"
```

### 7. Updating Working States:

#### Update Project Working State (`context/working-state.md`):
```markdown
# Working State

## Current Focus
- **Epic**: {{epic_id}} - {{epic_name}}
- **Feature**: {{feature_id}} - {{feature_name}}
- **Task**: None (completed {{task_id}})
- **Last Updated**: {{current_timestamp}}

## Recently Completed
- {{current_date}}: {{task_id}} - {{task_name}}
  - Duration: {{total_time}}
  - Outcome: {{completion_summary}}

## Available Tasks
{{list_remaining_tasks_in_feature}}

## Next Priority
{{suggested_next_task}}
```

#### Update Feature Working State:
```markdown
# Feature Working State

## Task Progress

### Recently Completed
- ✅ {{task_id}} ({{completion_date}})
  - Time: {{duration}}
  - Coverage: {{test_coverage}}%

### Tasks Status
- Completed: {{completed_count}} / {{total_count}}
- Progress: {{percentage}}%
- Remaining: {{remaining_count}}

### Feature Velocity
- Average task completion: {{avg_duration}}
- Estimated remaining time: {{remaining_estimate}}
- Projected completion: {{projected_date}}
```

### 8. Updating Backlog (if needed):

Adding any follow-up items to `context/backlog.md`:

```markdown
## Follow-up from {{task_id}}

### Tech Debt
{{tech_debt_items}}

### Enhancements
{{enhancement_ideas}}

### Documentation Needs
{{doc_requirements}}
```

### 9. Git Operations:

```bash
# Commit task completion
echo "📝 Committing task completion..."

git add -A
COMMIT_MSG="feat({{feature_id}}): complete {{task_id}}

- {{main_accomplishment_1}}
- {{main_accomplishment_2}}
- {{main_accomplishment_3}}

Time: {{duration}}
Coverage: {{test_coverage}}%"

git commit -m "$COMMIT_MSG"
echo "✅ Changes committed"

# Read branching configuration
echo "📖 Reading branching configuration..."
if [ -f "context/branching.md" ]; then
    # Parse strategy from branching.md
    STRATEGY=$(grep "Strategy:" context/branching.md | head -1)
    BASE_BRANCH=$(grep "Primary Branch:" context/branching.md | head -1)
fi

# Strategy-specific branch operations
echo "
Branch Options based on your configured strategy:
"

# Different options based on strategy
if [[ "$STRATEGY" == *"A"* ]]; then
    # Hierarchical strategy
    echo "1. Push task branch and create PR to feature branch"
    echo "2. Merge to feature branch locally"
    echo "3. Keep local for now"
    echo "4. Complete feature (if last task)"
elif [[ "$STRATEGY" == *"B"* ]]; then
    # Direct task strategy
    echo "1. Push task branch and create PR to $BASE_BRANCH"
    echo "2. Merge to $BASE_BRANCH locally"
    echo "3. Keep local for now"
    echo "4. Delete task branch"
elif [[ "$STRATEGY" == *"C"* ]]; then
    # Single feature branch
    echo "1. Push feature branch (prepare for PR when feature complete)"
    echo "2. Continue on feature branch"
    echo "3. Mark feature complete and create PR"
fi

echo "Select option: "
```

### 10. Pull Request Creation (if selected):

```bash
# Push branch
git push -u origin "$(git branch --show-current)"

# Determine PR target based on strategy
if [[ "$STRATEGY" == *"A"* ]]; then
    # Task PR to feature branch
    PR_TARGET="feature/{{feature_id}}"
elif [[ "$STRATEGY" == *"B"* ]]; then
    # Task PR directly to base branch
    PR_TARGET="$BASE_BRANCH"
elif [[ "$STRATEGY" == *"C"* ]]; then
    # Feature PR to base branch
    PR_TARGET="$BASE_BRANCH"
fi

# Create PR using gh CLI if available
if command -v gh &> /dev/null; then
    echo "Creating Pull Request to $PR_TARGET..."
    
    PR_TITLE="✅ Complete: {{task_id}} - {{task_name}}"
    PR_BODY="## Task Completion: {{task_id}}

### Summary
{{completion_summary}}

### Changes Made
{{change_list}}

### Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing complete
- [ ] No regressions identified

### Acceptance Criteria
{{criteria_checklist}}

### Screenshots
{{screenshots_if_applicable}}

### Performance Impact
{{performance_notes}}

### Related Issues
Closes #{{issue_number}}

### Follow-up Tasks
{{follow_up_tasks}}"

    gh pr create --base "$PR_TARGET" --title "$PR_TITLE" --body "$PR_BODY"
fi
```

### 11. Completion Report:

```
🎉 Task Completed Successfully!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Task: 001-01-005-user-endpoints
   Feature: 001-01-core - Core Functionality
   Epic: 001-mvp - MVP Development

📊 Completion Stats:
   Started: 2024-01-18 09:00
   Completed: 2024-01-18 16:30
   Duration: 7h 30m
   
   Original Estimate: 8h
   Variance: -6% (Ahead of schedule!)

📈 Quality Metrics:
   Test Coverage: 92%
   Code Review: ✅ Complete
   Documentation: ✅ Updated
   Performance: ✅ Meets targets

📁 File Updates:
   ✅ Task moved to completed/
   ✅ Working states updated
   ✅ Backlog updated with follow-ups

🔀 Git Status:
   Branch: task/001-01-005-user-endpoints
   Commits: 12 commits
   Files Changed: 24
   Insertions: +847
   Deletions: -213

📋 Follow-up Items Added:
   • Optimize database queries (backlog)
   • Add caching layer (backlog)
   • Enhance error messages (minor)

🚀 Next Actions:
   1. Start next task: 001-01-006-frontend-components
   2. Review another feature's tasks
   3. Create handoff documentation
   4. Take a well-deserved break!

What would you like to do next? [1-4]: 
```

### 12. Post-Completion Actions:

#### Suggest Next Task:
```bash
# Find next priority task in same feature
NEXT_TASK=$(ls context/features/{{feature_path}}/tasks/todo/*.md 2>/dev/null | head -1)
if [ -n "$NEXT_TASK" ]; then
    echo "📌 Suggested next task: $(basename $NEXT_TASK .md)"
    echo "Run: /start-task $(basename $NEXT_TASK .md)"
fi
```

#### Update Feature Completion:
```bash
# Check if feature is complete
TODO_COUNT=$(ls context/features/{{feature_path}}/tasks/todo/*.md 2>/dev/null | wc -l)
if [ $TODO_COUNT -eq 0 ]; then
    echo "🎊 Feature Complete! All tasks finished."
    echo "Consider:"
    echo "  • Creating feature completion report"
    echo "  • Merging feature branch to main"
    echo "  • Starting next feature"
fi
```

## Smart Features:

### Auto-Detection:
- Automatically finds current task if not specified
- Detects test frameworks and runs appropriate tests
- Identifies branch strategy and suggests correct git flow

### Quality Gates:
- Enforces test passing (configurable)
- Checks for documentation updates
- Validates acceptance criteria completion
- Ensures clean git status

### Metrics Tracking:
- Time variance analysis
- Test coverage trends
- Velocity calculations
- Feature progress updates

## Error Handling:

- **No active task**: List available tasks to complete
- **Tests failing**: Option to complete with warnings
- **Uncommitted changes**: Force commit or stash first
- **Missing criteria**: Prompt to update task file
- **Branch conflicts**: Guide through resolution

The completion system ensures tasks are properly closed with full documentation and tracking!