---
user-invocable: true
allowed-tools: Read(*), LS(*), Glob(*)
description: Display current active feature with all its tasks and progress
model: sonnet
---

# Current Feature Status

## Checking Current Feature Status...

I'll check the current active feature and display its complete status including all tasks.

### 1. First, checking if context directory exists:

```bash
if [ -d "context" ]; then
    echo "[OK] Context directory found"
else
    echo "[ERROR] Context directory not found. Run /init first to set up CCMagic."
    exit 1
fi
```

### 2. Reading Working State for Active Feature:

Reading `context/working-state.md` to identify the current feature...

```markdown
# Current Feature Summary

## Active Feature
{{feature_id}} - {{feature_name}}
Parent Epic: {{parent_epic}}
Status: {{feature_status}}
Path: context/features/{{feature_path}}/
```

### 3. Reading Feature Overview:

Loading `context/features/{{feature_path}}/overview.md` for feature details...

```markdown
## Feature Details
- **Scope**: {{feature_scope}}
- **Architecture**: {{architecture_decisions}}
- **Dependencies**: {{dependencies}}
- **Total Tasks**: {{total_tasks}}
```

### 4. Reading Feature Working State:

Loading `context/features/{{feature_path}}/working-state.md` for progress...

```markdown
## Feature Progress
- **Started**: {{start_date}}
- **Target Completion**: {{target_date}}
- **Owner**: {{owner}}
- **Current Focus**: {{current_focus}}
```

### 5. Scanning All Feature Tasks:

Checking all task directories for comprehensive status...

```bash
# Count tasks in each status
TODO_COUNT=$(ls -1 context/features/{{feature_path}}/tasks/todo/*.md 2>/dev/null | wc -l)
CURRENT_COUNT=$(ls -1 context/features/{{feature_path}}/tasks/current/*.md 2>/dev/null | wc -l)
COMPLETED_COUNT=$(ls -1 context/features/{{feature_path}}/tasks/completed/*.md 2>/dev/null | wc -l)

echo "Task Distribution:"
echo "  [ ] Todo: $TODO_COUNT"
echo "  [>] Current: $CURRENT_COUNT"
echo "  [x] Completed: $COMPLETED_COUNT"
```

### 6. Listing All Tasks by Status:

#### Todo Tasks:
```bash
for task in context/features/{{feature_path}}/tasks/todo/*.md; do
    if [ -f "$task" ]; then
        task_name=$(basename "$task" .md)
        echo "  [ ] $task_name"
    fi
done
```

#### Current Task(s):
```bash
for task in context/features/{{feature_path}}/tasks/current/*.md; do
    if [ -f "$task" ]; then
        task_name=$(basename "$task" .md)
        echo "  [>] $task_name (ACTIVE)"
    fi
done
```

#### Completed Tasks:
```bash
for task in context/features/{{feature_path}}/tasks/completed/*.md; do
    if [ -f "$task" ]; then
        task_name=$(basename "$task" .md)
        echo "  [x] $task_name"
    fi
done
```

## Display Format:

The system will show:
1. Feature identification and parent epic
2. Feature overview (scope, architecture, dependencies)
3. Progress metrics and timeline
4. Task distribution (todo/current/completed counts)
5. Detailed task list by status
6. Progress percentage
7. Next actions and blockers

## Example Output:

```
## Current Feature Status
==============================

[FEATURE] 001-01-core - Core Functionality
   Parent Epic: 001-mvp - MVP Development
   Status: In Progress

Overview:
   Scope: Implementation of primary user-facing functionality
   Architecture: MVC pattern with REST API
   Dependencies: Authentication system, Database setup

Progress:
   Started: 2024-01-15
   Target: 2024-02-01
   Owner: Development Team

Task Statistics:
   +------------------------------+
   | Todo:      5 tasks (50%)     |
   | Current:   1 task  (10%)     |
   | Completed: 4 tasks (40%)     |
   |                              |
   | Total:     10 tasks          |
   | Progress:  [====----] 40%    |
   +------------------------------+

Task Breakdown:

   [x] Completed (4):
      - 001-01-001-initial-setup
      - 001-01-002-database-schema
      - 001-01-003-api-structure
      - 001-01-004-auth-integration

   [>] In Progress (1):
      - 001-01-005-user-endpoints (Current)
        Branch: task/001-01-005-user-endpoints
        Started: 2024-01-18 09:00

   [ ] Todo (5):
      - 001-01-006-frontend-components
      - 001-01-007-state-management
      - 001-01-008-api-integration
      - 001-01-009-error-handling
      - 001-01-010-testing

Current Blockers:
   - Waiting for design specs for frontend
   - Need clarification on user roles

Next Priority Tasks:
   1. Complete 001-01-005-user-endpoints
   2. Start 001-01-006-frontend-components
   3. Review completed tasks for tech debt

Quick Actions:
   - Start next task: /start-task 001-01-006
   - View current task: /current-task
   - Update feature status: Edit working-state.md
   - Add new task: /create-tasks
```

## Advanced Features:

### Task Details Preview:
For each task, can optionally show:
- Acceptance criteria status
- Estimated vs actual time
- Dependencies
- Blockers

### Feature Health Indicators:
```
[OK] On Track - Progress matches timeline
[!] At Risk - Behind schedule but recoverable
[X] Blocked - Critical blockers present
```

### Velocity Metrics:
```
Average Task Completion: 2 tasks/day
Estimated Completion: 3 days remaining
Burn Rate: 40% complete
```

## Error Handling:

- **No context/**: Prompt to run `/init`
- **No active feature**: Show all features and suggest selecting one
- **Multiple features active**: Warning with list of active features
- **Missing feature files**: Create skeleton structure
- **Orphaned tasks**: Show tasks not in standard directories

## Implementation Notes:

This command will:
1. Parse working-state.md for current feature
2. Load feature overview and working-state files
3. Scan all task directories for comprehensive view
4. Calculate progress metrics
5. Display in hierarchical, visual format
6. Provide actionable next steps
7. Show blockers and priorities

The display is read-only and provides a complete feature overview at a glance, helping track progress and identify what needs attention.
