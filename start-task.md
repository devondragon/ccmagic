---
allowed-tools: Write(*), Read(*), Bash(git:*), Glob(*), LS(*), TodoWrite(*), Task(*), mcp__pal__thinkdeep(*), mcp__pal__codereview(*), mcp__pal__analyze(*)
description: Start working on a specific task and begin development
argument-hint: task-id (optional, e.g., task-001 or epic-001-f01-task-001)
model: sonnet
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

> **Parallel execution:** When operations are independent, run them simultaneously—exploring different code areas, reading unrelated files, or editing separate files. Claude Code will determine when this is safe and helpful.

#### Quick Context Loading with Explore Agent:
For efficient context loading, use the Task tool with subagent_type="Explore":

```
Use Task tool with:
  subagent_type: "Explore"
  prompt: "Explore the codebase to understand the context for task [task-id].
          Focus on: 1) Files related to the feature, 2) Existing patterns and
          conventions, 3) Dependencies and integration points. Be thorough."
```

This parallelizes context gathering and provides a focused summary without loading all files sequentially.

#### Traditional Context Loading (fallback):
If Explore agent is unavailable, load context in order:
1. `/context/project.md` - Project overview
2. `/context/conventions.md` - Development conventions
3. `/context/working-state.md` - Current project state
4. `/context/features/[feature-path]/overview.md` - Feature scope
5. `/context/features/[feature-path]/working-state.md` - Feature progress
6. `/context/features/[feature-path]/tasks/current/[task-file].md` - Task details

Note: CLAUDE.md is automatically loaded. Only load specific knowledge files if referenced in the task.

#### CRITICAL: Populate TodoWrite Immediately
After loading the task, **IMMEDIATELY use TodoWrite** to create a visible checklist:

```
Use TodoWrite tool with todos containing:
1. All acceptance criteria from the task file (status: pending)
2. Key implementation steps identified during analysis
3. Testing requirements
4. Documentation updates needed

Example format:
[
  {"content": "Implement user validation logic", "status": "pending", "activeForm": "Implementing user validation"},
  {"content": "Add unit tests for validation", "status": "pending", "activeForm": "Adding validation tests"},
  {"content": "Update API documentation", "status": "pending", "activeForm": "Updating API docs"}
]
```

This provides real-time visibility in the Claude Code interface. **Mark items as in_progress/completed as you work.**

#### Development Workflow:

**Tool Priority (use whichever is available, in order):**

**Tier 1 - External MCP Tools (if available):**
1. **Analysis**: Use `mcp__pal__thinkdeep` or `mcp__pal__analyze` to:
   - Analyze the task requirements
   - Create detailed implementation plan
   - Identify potential challenges

2. **Always use `TodoWrite`** to break down into subtasks with real-time tracking

3. Implement the solution following project conventions

4. **Code Review**: Use `mcp__pal__codereview` before marking complete

5. For complex features: Use `Task` tool with `subagent_type: "general-purpose"`

**Tier 2 - Built-in Claude Code Features (always available):**
1. Use `Task` tool with `subagent_type: "Plan"` to design implementation approach
2. Use `TodoWrite` for task breakdown and tracking
3. Implement solution following conventions
4. Use `Task` tool with `subagent_type: "Explore"` to verify implementation
5. Perform thorough self-review before completing

**Note:** All PAL MCP tools are optional enhancements. The workflow functions fully without them using Claude Code's built-in Task tool and subagents.

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
