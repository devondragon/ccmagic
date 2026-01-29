---
allowed-tools: Write(*), Read(*), Edit(*), Bash(*), Glob(*), LS(*), Grep(*), Task(*), TodoWrite(*), AskUserQuestion(*)
description: Execute ad-hoc task without feature overhead
argument-hint: "[description of what to do]"
model: sonnet
---

# Quick Task Execution

Execute a quick task with atomic commits but without full feature/task structure.
Perfect for bug fixes, config changes, small improvements.

## Process

### 1. Capture Intent

If no argument provided via $ARGUMENTS, ask: "What do you want to do?"

Create quick task record in `context/quick/` (create directory if needed):

**File**: `context/quick/[YYYYMMDD-HHMMSS]-[slug].md`

```markdown
# Quick Task: [description]
Created: [timestamp]
Status: in_progress

## Intent
[User's description]

## Changes Made
[To be filled during execution]

## Verification
[To be filled if applicable]
```

### 2. Spawn Execution Agent

Use Task tool with fresh context for implementation:

```
Use Task tool with:
  subagent_type: "general-purpose"
  prompt: |
    # Quick Task
    [User's description from $ARGUMENTS or prompt]

    ## Context
    - Read context/conventions.md for coding standards (if exists)
    - This is a quick task - no feature structure needed

    ## Instructions
    1. Understand what needs to be done
    2. Use TodoWrite to track subtasks if more than one step
    3. Implement the change
    4. Verify it works (run tests if applicable)
    5. Summarize what you changed

    Keep changes focused and minimal.
```

### 3. Atomic Commit

After agent completes successfully:

1. **Stage changes** - Add only the files that were modified (not context/quick/)
   ```bash
   git add [specific files changed]
   ```

2. **Create commit** with appropriate prefix:
   - `fix:` for bug fixes
   - `chore:` for config/maintenance
   - `feat:` for small features
   - `docs:` for documentation
   ```bash
   git commit -m "[prefix]: [concise description]"
   ```

3. **Update quick task file** with changes made and verification results

### 4. Cleanup

1. Move quick task file to `context/quick/completed/` (create if needed)
2. Report summary to user:
   ```
   Quick task complete:
   - [What was done]
   - Commit: [commit hash]
   - Files changed: [list]
   ```

## Notes

- Quick tasks bypass the epic/feature/task hierarchy
- Still maintains atomic commits and audit trail
- Use for work that doesn't fit into current feature scope
- If task grows complex, suggest converting to proper feature task
