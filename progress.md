---
allowed-tools: Read(*), Glob(*), LS(*), Grep(*)
description: Check progress and route to next action
model: haiku
---

# Progress Check & Routing

Check current project state and suggest next action.

## Process

### 1. Gather State

Read the following files (if they exist):

- `context/working-state.md` — current status
- `.continue-here.md` — pending handoff from previous session

Also check these directories:

- `context/features/*/tasks/current/` — active tasks
- `context/features/*/tasks/todo/` — pending tasks
- `context/quick/` — active quick tasks (excluding completed/)

### 2. Determine Position

Use this decision tree to determine what to suggest:

**Priority 1: Handoff Exists**
If `.continue-here.md` exists in project root:
```
Found handoff from previous session.
Run `/ccmagic:resume` to restore context and continue where you left off.
```

**Priority 2: Task In Progress**
If any task file exists in `context/features/*/tasks/current/`:
```
Active task: [task-id]
- Feature: [feature-name]
- Started: [from working-state if available]

Options:
- Continue working on this task
- `/ccmagic:checkpoint` to save progress and pause
- `/ccmagic:verify` to run acceptance criteria checks
- `/ccmagic:complete-task` when finished
```

**Priority 3: Quick Task In Progress**
If non-completed files exist in `context/quick/` (not in completed/):
```
Quick task in progress: [task description]

Complete it or start fresh with `/ccmagic:quick [new task]`
```

**Priority 4: Tasks Available**
If task files exist in `context/features/*/tasks/todo/`:
```
Ready for next task.

Available tasks:
1. [task-id]: [task name] (feature: [feature])
2. [task-id]: [task name] (feature: [feature])
3. [task-id]: [task name] (feature: [feature])

Run `/ccmagic:start-task [task-id]` to begin.
```
(List up to 3 highest priority tasks)

**Priority 5: Features Without Tasks**
If feature directories exist but have empty or no `tasks/todo/`:
```
Feature [feature-name] needs task breakdown.

Run `/ccmagic:create-tasks [feature-id]` to generate tasks.
```

**Priority 6: No Active Work**
If none of the above apply:
```
No active work found.

Options:
- `/ccmagic:plan` to define features and plan work
- `/ccmagic:quick [description]` for ad-hoc tasks
- `/ccmagic:init` if CCMagic not yet initialized
```

### 3. Show Context Summary

Display a brief status summary:

```
Project Status
--------------
Epic: [current epic or "none"]
Feature: [current feature or "none"]
Active Task: [task-id or "none"]

Recent Activity:
- [last completed task/action from working-state]

Blockers: [any blockers from working-state, or "none"]
```

## Notes

- This command is read-only and makes no changes
- Use haiku model for fast, lightweight status checks
- Designed to quickly orient you after opening a project
