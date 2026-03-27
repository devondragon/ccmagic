---
user-invocable: true
allowed-tools: Write(*), Read(*), Bash(git:*, mv:*), Glob(*), LS(*), TodoWrite(*), Task(*), AskUserQuestion(*), mcp__pal__thinkdeep(*), mcp__pal__codereview(*), mcp__pal__analyze(*)
description: Start working on a specific task and begin development
argument-hint: task-id (optional, e.g., task-001 or epic-001-f01-task-001)
model: sonnet
---

# Start Task and Begin Development

Bridge between planning and execution. Validates context, creates the correct branch, populates TodoWrite from acceptance criteria, and spawns an implementation agent with full task context.

## Step 0: Parse Arguments

Parse `$ARGUMENTS` to determine the target task:

| Argument | Behavior |
|----------|----------|
| *(empty)* | List available tasks from all `context/features/*/tasks/todo/` and ask user to choose |
| `task-id` | Search for matching file in `context/features/*/tasks/todo/` (partial match on filename) |

If empty, use Glob to find all `context/features/*/tasks/todo/*.md` files. Present them grouped by feature and ask the user to pick one via `AskUserQuestion`.

## Step 1: Context Validation

Before any action, validate all prerequisites. Stop on the first failure.

### 1a. Task file exists

```
Glob: context/features/*/tasks/todo/*{task-id}*.md
```

If zero matches: report error and suggest running `/ccmagic:create-tasks` first.
If multiple matches: present options via `AskUserQuestion` and let user disambiguate.

### 1b. Feature exists and has overview

From the matched task path, extract the feature directory. Read `context/features/{feature}/overview.md`. If missing, warn but continue (non-fatal).

### 1c. No other task is currently active

```
Glob: context/features/*/tasks/current/*.md
```

If a file exists in any `current/` directory, another task is active. Present:
> "Task **{active-task}** is currently in progress for feature **{feature}**.
> - **Checkpoint** -- save progress and start new task
> - **Cancel** -- abort, keep working on current task"

Use `AskUserQuestion` for the decision.
- If **Checkpoint**: tell the user to run `/ccmagic:checkpoint` first, then re-run `/ccmagic:start-task`. Stop execution.
- If **Cancel**: stop execution entirely.

### 1d. Branch does not already exist

```bash
git branch --list "task/{task-id}" "feature/{feature-id}"
```

If the target branch already exists, ask the user:
> "Branch **{branch-name}** already exists. Options:
> - **Switch** -- check out the existing branch and continue
> - **Delete** -- delete the branch and create fresh
> - **Cancel** -- abort"

Handle each option accordingly.

## Step 2: Read Branching Strategy

Read `context/branching.md` to determine branch creation approach. If the file does not exist, fall back to **Strategy B (Direct Task)** as default.

Parse the file for the configured strategy. The file contains a `strategy` field with one of three values:

### Strategy A: Hierarchical (feature + task branches)

```bash
git checkout {base-branch}
git pull origin {base-branch}
# Create or switch to feature branch
git checkout feature/{feature-id} 2>/dev/null || git checkout -b feature/{feature-id}
# Create task branch from feature
git checkout -b task/{task-id}
```

Working branch: `task/{task-id}` (based on `feature/{feature-id}`)

### Strategy B: Direct Task (task branches from base)

```bash
git checkout {base-branch}
git pull origin {base-branch}
git checkout -b task/{task-id}
```

Working branch: `task/{task-id}` (based on `{base-branch}`)

### Strategy C: Single Feature (feature branch only)

```bash
git checkout {base-branch}
git pull origin {base-branch}
git checkout feature/{feature-id} 2>/dev/null || git checkout -b feature/{feature-id}
```

Working branch: `feature/{feature-id}` (no separate task branch)

**Error handling for git operations:**
- If `git pull` fails (no remote, network error): warn but continue. The user may be working offline.
- If `git checkout -b` fails with "already exists": fall back to `git checkout` (switch only).
- If `git checkout` fails with uncommitted changes: report the error and suggest stashing or committing first. Stop execution.

## Step 3: Move Task to Current

Create the `current/` directory if it does not exist, then move the task file:

```bash
mkdir -p context/features/{feature}/tasks/current
mv context/features/{feature}/tasks/todo/{task-file} context/features/{feature}/tasks/current/
```

If `mv` fails (permissions, path issue): report error and stop.

## Step 4: Read Task File and Extract Context

Read the task file from its new location in `current/`. Extract:

1. **Title** -- first `# Task` heading
2. **Description** -- content of `## Description` section
3. **Acceptance criteria** -- all `- [ ]` items from `## Acceptance Criteria`
4. **Verify blocks** -- all `<verify>...</verify>` content
5. **Done criteria** -- content of `<done>...</done>` block
6. **Implementation notes** -- content of `## Implementation Notes`
7. **Dependencies** -- content of `## Dependencies`
8. **Scope** -- content of `## Scope`

Store each piece for use in Steps 5, 6, and 7.

## Step 5: Populate TodoWrite

Create TodoWrite entries from the acceptance criteria. This makes progress visible in the Claude Code todo panel.

For each acceptance criterion extracted in Step 4:
```
TodoWrite: {
  todos: [
    { id: "task-{seq}-ac-1", content: "{criterion text}", status: "in_progress" },
    { id: "task-{seq}-ac-2", content: "{criterion text}", status: "in_progress" },
    ...
  ]
}
```

Rules:
- One TodoWrite entry per acceptance criterion
- Use `in_progress` status (not `completed`)
- ID format: `task-{task-sequence}-ac-{number}` (e.g., `task-001-ac-1`)
- Limit to 15 entries maximum. If more criteria exist, group related ones.

## Step 6: Update Working States

### 6a. Project-level working-state.md

Read `context/working-state.md`. Update (or create) the current status section:

```markdown
## Current Task
- **Epic**: {epic-id}
- **Feature**: {feature-id} -- {feature-name}
- **Task**: {task-id} -- {task-title}
- **Task Path**: context/features/{feature}/tasks/current/{task-file}
- **Branch**: {branch-name}
- **Started**: {YYYY-MM-DD HH:MM}
- **Status**: in_progress
```

Preserve all other content in the file. Only update the `## Current Task` section.

### 6b. Feature-level working-state.md

Read `context/features/{feature}/working-state.md`. Update (or create) the task progress section:

```markdown
## Active Task
- **Task**: {task-id} -- {task-title}
- **Branch**: {branch-name}
- **Started**: {YYYY-MM-DD HH:MM}
- **Status**: in_progress
```

Preserve all other content. Only update the `## Active Task` section.

## Step 7: Spawn Implementation Agent

After all setup is complete (task moved, branch created, working states updated, todos populated), spawn a fresh agent for implementation.

### 7a. Gather agent context files

Read these files (skip any that do not exist):
1. `context/conventions.md` -- coding standards
2. `context/features/{feature}/overview.md` -- feature scope
3. `context/features/{feature}/CONTEXT.md` -- implementation decisions
4. `context/project.md` -- tech stack, project structure

### 7b. Build agent prompt

Load `${CLAUDE_SKILL_DIR}/agent-handoff.md` and fill placeholders:

| Placeholder | Value |
|-------------|-------|
| `{TASK_ID}` | Full task ID |
| `{TASK_TITLE}` | Task title from heading |
| `{TASK_FILE_CONTENTS}` | Complete task file content |
| `{FEATURE_PATH}` | Feature directory path |
| `{FEATURE_OVERVIEW}` | Content of overview.md (or "Not available") |
| `{FEATURE_CONTEXT}` | Content of CONTEXT.md (or "Not available") |
| `{PROJECT_CONVENTIONS}` | Content of conventions.md (or "No conventions file found") |
| `{PROJECT_INFO}` | Content of project.md (or "Not available") |
| `{BRANCH_NAME}` | Current git branch |
| `{ACCEPTANCE_CRITERIA}` | Extracted acceptance criteria list |
| `{VERIFY_COMMANDS}` | Extracted verify blocks |
| `{DONE_CRITERIA}` | Extracted done criteria |
| `{IMPLEMENTATION_NOTES}` | Extracted implementation notes |

### 7c. Launch the agent

```
Task tool:
  subagent_type: "general-purpose"
  prompt: [filled agent-handoff template]
```

The spawned agent handles implementation. The main session handles task lifecycle.

## Step 8: Post-Agent Summary

After the agent completes and returns its summary:

1. **Display the agent's summary** to the user
2. **Check TodoWrite status** -- show how many criteria were marked complete
3. **Prompt next steps**:

```
Task started: {task-id} on branch {branch-name}

Agent summary:
{agent-output-summary}

Progress: {N}/{M} acceptance criteria addressed

Next steps:
  /ccmagic:verify {task-id}     -- validate acceptance criteria
  /ccmagic:complete-task         -- finalize and move to done
  /ccmagic:checkpoint            -- save progress and pause
  /ccmagic:status                -- check current state
```

## Error Recovery

If any step fails after the task file has been moved (Step 3+), attempt to recover:

1. If branch creation failed: move task back to `todo/` and report the git error
2. If agent spawn failed: leave task in `current/` and branch intact -- the user can re-run or work manually
3. If working-state update failed: log warning but do not block -- this is non-critical

Always leave the project in a consistent state. A task should be in `current/` if and only if work has begun on it.

## Execution

When invoked, begin immediately without asking for confirmation (unless disambiguation is needed in Step 0 or Step 1). Follow each step sequentially -- do not skip validation. Be concise in status messages during setup, verbose only in the final summary.
