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

### 4. **Spawn Execution Agent:**

After setup is complete (task moved, branch created, working states updated), spawn a fresh agent for implementation with focused context. This ensures a clean context window for the actual work.

#### Prepare Agent Context:
First, read the task file and extract key information:
- Full task description and acceptance criteria
- `<done>` criteria if present (explicit completion state)
- `<verify>` commands if present (machine-verifiable checks)
- Technical details and dependencies

#### Spawn Implementation Agent:

```
Use Task tool with:
  subagent_type: "general-purpose"
  prompt: |
    # Task Implementation: [task-id]

    ## Task
    [Embed full task file contents here]

    ## Context Files to Read
    - context/conventions.md (coding standards)
    - context/features/[feature-path]/overview.md (feature scope)

    ## Done When
    [Extract <done> criteria if present, otherwise use acceptance criteria]

    ## Instructions
    1. Use the Read tool to load each of the context files listed above
    2. Use TodoWrite immediately - create checklist from acceptance criteria
    3. Explore codebase as needed (use Explore agent for broad searches)
    4. Implement following project conventions
    5. Mark TodoWrite items complete as you progress
    6. Run verification commands if <verify> section exists
    7. When complete, summarize what was accomplished

    Focus only on this task. Do not load unnecessary context.
```

#### Key Implementation Reminders (passed to agent):
- Follow project conventions for code style and structure
- Write tests as specified in task requirements
- Update documentation as needed
- Run `<verify>` commands before declaring complete

### 5. **Task Completion:**

After the agent completes and returns its summary:

1. **Review agent output** - Verify the work was completed successfully
2. **Run verification** - If `<verify>` commands exist, confirm they pass
3. **Prompt user** - Display: "Task implementation complete. Run `/ccmagic:verify [task-id]` to validate acceptance criteria, or `/ccmagic:complete-task` when ready to finalize."

The agent handles implementation; the main session handles task lifecycle (moving files, updating states, commits).

## Notes:
- Only one task should be active at a time
- If another task is active, prompt to complete or checkpoint first
- Remind user to pull latest changes before starting
- Check for blockers or dependencies in task file
