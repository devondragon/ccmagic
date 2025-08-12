---
allowed-tools: Write(*), Read(*), Bash(git:*), Glob(*), LS(*), TodoWrite(*), mcp__zen__thinkdeep(*), mcp__zen__codereview(*), mcp__zen__refactor(*), mcp__zen__docgen(*), Task(*)
description: Start working on a specific task and begin development
argument-hint: task-id (optional, e.g., task-001 or epic-001-f01-task-001)
model: claude-sonnet-4-20250514
---

# Start Task and Begin Development

## Implementation Plan

This command will:

### 1. **Task Selection & Validation:**
- If task-id provided: Locate in `context/features/*/tasks/todo/`
- If no task-id: List available tasks and ask user to choose
- Move task from `todo/` to `current/` directory
- Validate no other task is currently active

### 2. **Git Branching Strategy:**
Reading branching configuration from `context/branching.md`:

```bash
# Read the configured branching strategy
if [ -f "context/branching.md" ]; then
    echo "Loading branching configuration..."
    # Parse strategy from branching.md
else
    echo "⚠️ No branching configuration found. Run /ccmagic:init first."
fi
```

The configured strategy will determine:
- Whether to create feature branches, task branches, or both
- Which base branch to use (main, develop, or custom)
- Branch naming patterns

#### Strategy-Specific Branch Creation:

**If Strategy A (Hierarchical)**:
```bash
# Check if feature branch exists
git checkout [base-branch]
git pull origin [base-branch]
git checkout -b feature/[feature-id] || git checkout feature/[feature-id]
# Then create task branch from feature
git checkout -b task/[task-id]
```

**If Strategy B (Direct Task)**:
```bash
# Create task branch directly from base
git checkout [base-branch]
git pull origin [base-branch]
git checkout -b task/[task-id]
```

**If Strategy C (Single Feature)**:
```bash
# Use or create feature branch only
git checkout [base-branch]
git pull origin [base-branch]
git checkout -b feature/[feature-id] || git checkout feature/[feature-id]
# No separate task branch - work directly on feature
```

### 3. **Update Working States:**
Update both project and feature working-state.md files:

**Project working-state.md:**
```markdown
## Current Status
- **Epic**: 001-mvp
- **Feature**: 001-01-authentication
- **Active Task**: 001-01-001-login-form
- **Task Path**: context/features/001-01-authentication/tasks/current/
- **Branch**: task/001-01-001-login-form (or feature/001-01-authentication)
- **Started**: 2024-01-15 14:30
```

**Feature working-state.md:**
```markdown
## Task Progress
- **Current**: 001-01-001-login-form (Started: 2024-01-15 14:30)
- **Branch**: task/001-01-001-login-form (or feature/001-01-authentication)
- **Status**: in_progress
```

### 4. **Begin Development Work:**

#### Load Context (in order):
1. `/context/project.md` - Project overview
2. `/context/conventions.md` - Development conventions
3. `/context/working-state.md` - Current project state
4. `/context/features/[feature-path]/overview.md` - Feature scope
5. `/context/features/[feature-path]/working-state.md` - Feature progress
6. `/context/features/[feature-path]/tasks/current/[task-file].md` - Task details

Note: CLAUDE.md is automatically loaded. Only load specific knowledge files if referenced in the task.

#### Development Workflow:

**If zen MCP tools are available:**
1. Use `mcp__zen__thinkdeep` (model: gemini-2.5-pro or best available) to:
   - Analyze the task requirements
   - Create detailed implementation plan
   - Identify potential challenges

2. Use `TodoWrite` to break down into subtasks

3. Implement the solution following project conventions

4. Use `mcp__zen__codereview` before marking complete

5. For specific task types:
   - Refactoring tasks: Use `mcp__zen__refactor`
   - Documentation tasks: Use `mcp__zen__docgen`
   - Complex features: Use `Task` tool with general-purpose agent

**If zen MCP tools are NOT available:**
1. Analyze task requirements using standard Claude model
2. Create implementation plan and subtasks manually
3. Implement solution following conventions
4. Perform self-review before completing

#### Key Implementation Reminders:
- Create feature branch BEFORE any code changes
- Check task dependencies in working-state.md
- Follow project conventions for code style and structure
- Write tests as specified in task requirements
- Update documentation as needed

### 5. **Task Completion:**
When development is complete:
- Move task from `current/` to `completed/`
- Update working-state.md files
- Prepare for code review or PR creation

## Notes:
- Only one task should be active at a time
- If another task is active, prompt to complete or checkpoint first
- Remind user to pull latest changes before starting
- Check for blockers or dependencies in task file
