---
allowed-tools: Write(*), Read(*), Bash(git:*), LS(*)
description: Save current progress and update working state
argument-hint: [optional commit message]
model: sonnet
---

# Checkpoint Progress

## Saving Your Work Progress...

I'll save your current progress by updating the working state and optionally committing to git.

### 1. Checking Context Directory:

```bash
if [ ! -d "context" ]; then
    echo "❌ Context directory not found. Run /init first."
    exit 1
fi
```

### 2. Reading Current Task:

Loading `context/working-state.md` to identify active work...

```markdown
Current Task: {{task_id}} - {{task_name}}
Feature: {{feature_id}} - {{feature_name}}
Epic: {{epic_id}} - {{epic_name}}
Branch: {{branch_name}}
Started: {{start_time}}
```

### 3. Reading Task File:

Loading the current task file to check progress...

```bash
# Find current task file
TASK_FILE=$(find context/features/*/tasks/current -name "*.md" -type f | head -1)
if [ -z "$TASK_FILE" ]; then
    echo "⚠️ No active task found in current/ directories"
    echo "Checking working-state.md for task reference..."
fi
```

### 4. Progress Update Prompts:

#### Completed Items:
```markdown
## What did you complete? (Check all that apply)

From task acceptance criteria:
- [ ] {{criterion_1}}
- [ ] {{criterion_2}}
- [ ] {{criterion_3}}

Additional work completed:
- [ ] Documentation updated
- [ ] Tests written/updated
- [ ] Code reviewed
- [ ] Dependencies resolved
```

#### Current Status:
```markdown
## How would you describe current progress?

Select one:
- [ ] Just started (0-25%)
- [ ] Making progress (25-50%)
- [ ] Halfway done (50%)
- [ ] Almost complete (75-90%)
- [ ] Ready for review (90-100%)
- [ ] Completed (100%)
```

#### Blockers & Issues:
```markdown
## Any blockers or issues encountered?

- [ ] No blockers
- [ ] Waiting on dependencies
- [ ] Need clarification
- [ ] Technical challenges
- [ ] External blocker

Details: {{blocker_details}}
```

#### Key Decisions Made:
```markdown
## Important decisions or discoveries:

- Decision: {{decision_1}}
  Reasoning: {{reasoning_1}}
  
- Discovery: {{discovery_1}}
  Impact: {{impact_1}}
```

#### Next Steps:
```markdown
## What's next?

Immediate next steps:
1. {{next_step_1}}
2. {{next_step_2}}
3. {{next_step_3}}

Estimated time to complete: {{time_estimate}}
```

### 5. Updating Working State Files:

#### Update Project Working State (`context/working-state.md`):
```markdown
# Working State

## Current Focus
- **Epic**: {{epic_id}} - {{epic_name}}
- **Feature**: {{feature_id}} - {{feature_name}}
- **Task**: {{task_id}} - {{task_name}}
- **Last Updated**: {{current_timestamp}}
- **Last Checkpoint**: {{current_timestamp}}

## Progress Summary
- **Status**: {{status_percentage}}% complete
- **Time Spent**: {{time_spent}}
- **Estimated Remaining**: {{time_remaining}}

## Recent Progress
- {{checkpoint_timestamp}}: {{progress_summary}}
  - Completed: {{completed_items}}
  - Blockers: {{blockers_if_any}}
  - Next: {{immediate_next_step}}

## Key Decisions Log
- {{date}}: {{decision}}

## Active Blockers
{{blockers_list}}

## Environment Status
- Branch: {{branch_name}}
- Tests: {{test_status}}
- Build: {{build_status}}
```

#### Update Feature Working State:
```markdown
# Feature Working State

## Task Progress

### Current Task
- **ID**: {{task_id}}
- **Status**: {{percentage}}% complete
- **Last Checkpoint**: {{timestamp}}
- **Next Review**: {{review_time}}

### Completed in This Session
{{completed_items_list}}

### Velocity
- Tasks completed this week: {{completed_count}}
- Average task duration: {{avg_duration}}
- Estimated feature completion: {{estimated_date}}
```

### 6. Creating Session Note:

Creating `context/sessions/{{date}}-{{time}}-checkpoint.md`:

```markdown
# Checkpoint: {{timestamp}}

## Task
- **ID**: {{task_id}}
- **Name**: {{task_name}}
- **Feature**: {{feature_id}}

## Progress Made
{{detailed_progress}}

### Completed
{{completed_checklist}}

### Code Changes
- Files modified: {{file_count}}
- Lines added: {{lines_added}}
- Lines removed: {{lines_removed}}

### Technical Details
{{technical_notes}}

## Decisions & Discoveries
{{decisions_list}}

## Blockers Encountered
{{blockers_with_details}}

## Next Steps
1. {{next_1}}
2. {{next_2}}
3. {{next_3}}

## Time Tracking
- Session duration: {{duration}}
- Total task time: {{total_time}}
- Estimated remaining: {{remaining}}

## Notes for Next Session
{{continuation_notes}}
```

### 7. Git Integration:

```bash
# Show current git status
echo "📊 Current Git Status:"
git status --short

# Count changes
CHANGES=$(git status --porcelain | wc -l)
if [ $CHANGES -gt 0 ]; then
    echo "📝 You have $CHANGES uncommitted changes"
    
    # Ask about committing
    echo "Would you like to commit these changes? (y/n)"
    
    if [ "$COMMIT" = "y" ]; then
        # Generate commit message if not provided
        if [ -z "$1" ]; then
            # Auto-generate from task and progress
            COMMIT_MSG="checkpoint({{task_id}}): {{progress_summary}}"
            echo "Generated commit message: $COMMIT_MSG"
        else
            COMMIT_MSG="$1"
        fi
        
        # Stage and commit
        git add -A
        git commit -m "$COMMIT_MSG"
        echo "✅ Changes committed"
    fi
fi
```

### 8. Progress Visualization:

```
📊 Checkpoint Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━

📍 Current Task: 001-01-005-user-endpoints
   Feature: 001-01-core - Core Functionality
   Epic: 001-mvp - MVP Development

⏱️ Time Tracking:
   Started: 2024-01-18 09:00
   Checkpoint: 2024-01-18 14:30
   Duration: 5h 30m
   
📈 Progress: ████████████░░░░ 75%

✅ Completed This Session:
   • Implemented user model
   • Created CRUD endpoints
   • Added validation middleware
   • Written unit tests (80% coverage)
   
🚧 Current Blockers:
   • Waiting for auth token format specification
   
🎯 Next Steps:
   1. Complete integration tests
   2. Add error handling
   3. Document API endpoints
   
💾 Git Status:
   Branch: task/001-01-005-user-endpoints
   Changes: 12 files modified
   Last Commit: 2 hours ago
   
📝 Session Note Created:
   context/sessions/2024-01-18-1430-checkpoint.md
   
✨ Checkpoint saved successfully!
```

## Auto-Checkpoint Features:

### Time-Based Reminders:
```markdown
## Auto-Checkpoint Configuration

Enable in CLAUDE.md:
- Reminder after: 2 hours
- Warning after: 3 hours
- Force checkpoint: Before task switch
```

### Checkpoint Triggers:
1. **Manual**: User runs `/checkpoint`
2. **Time-based**: After 2 hours of work
3. **Task switch**: Before starting new task
4. **End of session**: Before `/handoff`
5. **Major milestone**: After completing significant work

## Quick Checkpoint Options:

### Minimal Checkpoint:
```bash
/checkpoint --quick
# Just saves current state without prompts
```

### Detailed Checkpoint:
```bash
/checkpoint --detailed
# Full interactive session with all prompts
```

### Silent Checkpoint:
```bash
/checkpoint --silent
# Updates files without output
```

## Best Practices:

1. **Checkpoint frequently** - Every 1-2 hours minimum
2. **Be specific** - Detail what was actually completed
3. **Document blockers** - Help the next session start smoothly
4. **Update estimates** - Adjust remaining time based on progress
5. **Commit regularly** - Keep git history clean and traceable

## Error Handling:

- **No active task**: Prompt to select task first
- **Uncommitted changes**: Show diff and ask about committing
- **Merge conflicts**: Guide through resolution
- **Missing files**: Recreate structure as needed

The checkpoint system ensures work is never lost and progress is always tracked!