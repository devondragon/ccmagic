---
user-invocable: true
allowed-tools: Read(*), LS(*), Glob(*)
description: Display current active task, feature, and epic information
model: sonnet
---

# Current Task Status

## Checking Current Work Status...

I'll check the current active task, feature, and epic from your CCMagic context structure.

### 1. First, checking if context directory exists:

```bash
if [ -d "context" ]; then
    echo "[OK] Context directory found"
else
    echo "[ERROR] Context directory not found. Run /init first to set up CCMagic."
    exit 1
fi
```

### 2. Reading Working State:

Reading `context/working-state.md` to get current status...

```markdown
# Current Work Summary

## Active Epic
{{epic_id}} - {{epic_name}}
Status: {{epic_status}}
Path: context/epics/{{epic_file}}

## Active Feature
{{feature_id}} - {{feature_name}}
Parent Epic: {{parent_epic}}
Status: {{feature_status}}
Path: context/features/{{feature_path}}/

## Current Task
{{task_id}} - {{task_name}}
Parent Feature: {{parent_feature}}
Branch: {{branch_name}}
Started: {{start_time}}
Status: {{task_status}}
Path: {{task_path}}

### Task Progress
{{progress_checklist}}

## Quick Actions
- View task details: Read the task file at {{task_path}}
- Update progress: Edit context/working-state.md
- Complete task: Run /complete-task {{task_id}}
- Save progress: Run /checkpoint
```

### 3. Checking for Active Tasks in Features:

Scanning `context/features/*/tasks/current/` for any active tasks...

```bash
# Check for tasks in current directories
for feature_dir in context/features/*/; do
    if [ -d "$feature_dir/tasks/current/" ]; then
        task_count=$(ls -1 "$feature_dir/tasks/current/"*.md 2>/dev/null | wc -l)
        if [ $task_count -gt 0 ]; then
            echo "Active task found in: $feature_dir"
            ls "$feature_dir/tasks/current/"*.md
        fi
    fi
done
```

### 4. Checking for Active Spikes:

Looking in `context/spikes/current/` for any active research tasks...

```bash
if [ -d "context/spikes/current/" ]; then
    spike_count=$(ls -1 context/spikes/current/*.md 2>/dev/null | wc -l)
    if [ $spike_count -gt 0 ]; then
        echo "Active spike found:"
        ls context/spikes/current/*.md
    fi
fi
```

## Status Display Logic:

The system will:
1. Check if context directory exists (prompt to run /init if not)
2. Read working-state.md for current epic/feature/task info
3. Display hierarchical status (Epic > Feature > Task)
4. Show task progress checklist
5. Provide quick action commands
6. Check for any orphaned tasks in current/ directories
7. Display any active spikes separately

## Information Hierarchy:

```
Epic (e.g., 001-mvp)
 +-- Feature (e.g., 001-01-core)
     +-- Task (e.g., 001-01-001-initial-setup)
         +-- Progress Checklist
             +-- Next Steps
```

## Error Handling:

- **No context/**: Prompt to run `/init`
- **No active task**: Show "No active task" and suggest `/start-task`
- **Multiple active tasks**: Warning - should only have one active task
- **Incomplete working-state**: Show partial info with warning

## Example Output:

```
## Current Task Status
==============================

[EPIC] 001-mvp - MVP Development
   Status: In Progress

[FEATURE] 001-01-core - Core Functionality
   Parent: 001-mvp
   Status: In Progress

[TASK] 001-01-001-initial-setup - Initial Setup
   Branch: task/001-01-001-initial-setup
   Started: 2024-01-15 14:30
   Status: In Progress

Progress:
   [x] Project structure created
   [x] Dependencies installed
   [ ] Configure build tools
   [ ] Set up development environment

Next Steps:
   - Complete build configuration
   - Test development server

Quick Actions:
   - Update progress: /checkpoint
   - Complete task: /complete-task 001-01-001
   - View details: Read task file
```

## Implementation Notes:

This command will:
1. Parse the working-state.md file for current status
2. Extract epic, feature, and task information
3. Display in a clear, hierarchical format
4. Show progress checkboxes from the task file
5. Provide actionable next steps
6. Handle edge cases gracefully

The implementation should be read-only and fast, providing immediate visibility into what's being worked on without modifying any files.
