---
user-invocable: true
allowed-tools: Read(*), Bash(*), Glob(*), LS(*), Grep(*), Task(*), Write(*), AskUserQuestion(*)
description: Interactive verification of task acceptance criteria
argument-hint: "[task-id or 'current']"
model: sonnet
disable-model-invocation: true
---

# Verify Task Completion

Interactively verify acceptance criteria and spawn debug agents for failures.

## Process

### 1. Load Task

Locate the task file:
- If `$ARGUMENTS` is "current" or empty: Find task in `context/features/*/tasks/current/`
- If task-id provided: Search for matching task file

Read the task file and extract:
- **Acceptance criteria** - The checklist items
- **`<verify>` commands** - Machine-verifiable checks (if present)
- **`<done>` criteria** - Explicit completion state (if present)

### 2. Run Automated Checks

For each `<verify>` command found in the task:

```bash
verify_cmd="[verify command]"  # Replace with the actual verify command from task file
echo "Running: $verify_cmd"

# Execute the command
bash -c "$verify_cmd"

if [ $? -eq 0 ]; then
  echo "✅ PASS: $verify_cmd"
else
  echo "❌ FAIL: $verify_cmd"
  # Store failure for later handling
fi
```

Display summary:
```
Automated Verification Results:
- [command 1]: PASS/FAIL
- [command 2]: PASS/FAIL
...
```

### 3. Interactive Walkthrough

For each acceptance criterion that doesn't have an automated `<verify>`:

Use AskUserQuestion to prompt:
```
Criterion: [criterion text]

Can you confirm this is working?
```

Options:
- "Yes, verified" - Mark as passing
- "No, failing" - Mark as failing (will trigger debug options)
- "Skip for now" - Skip this criterion

### 4. Handle Failures

For each failing criterion (automated or manual), present options using AskUserQuestion:

```
Failed: [criterion or verify command]
[Include error output if from automated check]

How would you like to proceed?
```

Options:
1. **"Spawn debug agent"** - Launch agent to investigate and fix
2. **"Create fix task"** - Add to backlog for later
3. **"Mark as known issue"** - Continue with noted limitation
4. **"Retry verification"** - Run the check again

#### Debug Agent (Option 1):

```
Use Task tool with:
  subagent_type: "general-purpose"
  prompt: |
    # Debug: [criterion that failed]

    ## Context
    The following acceptance criterion is failing:
    [criterion text]

    Verification command (if any): [verify command]
    Output: [command output or user description]

    ## Instructions
    1. Investigate why this is failing
    2. Identify the root cause
    3. If fix is straightforward, implement it
    4. Run the verification again to confirm
    5. Report what you found and what you fixed (if anything)
```

After debug agent returns, automatically re-run the specific failed verification command to check if the issue was resolved.

### 5. Generate Report

Create verification report:

```markdown
# Verification Report: [task-id]
Generated: [timestamp]

## Summary
- Total criteria: X
- Passed: Y
- Failed: Z
- Skipped: W

## Automated Checks
| Command | Status | Output |
|---------|--------|--------|
| [cmd] | PASS/FAIL | [output snippet] |

## Manual Verification
| Criterion | Status | Notes |
|-----------|--------|-------|
| [text] | PASS/FAIL/SKIP | [user notes] |

## Issues Found
[List any failures with details]

## Follow-up Tasks Created
[If any fix tasks were added to backlog]

## Verdict
[READY FOR COMPLETION / NEEDS FIXES]
```

Save report to: `context/features/[feature-path]/tasks/current/[task-id]-verification.md`

### 6. Final Prompt

Based on results:

**If all pass:**
```
All acceptance criteria verified. Ready to complete task.
Run `/ccmagic:complete-task` to finalize.
```

**If failures remain:**
```
[N] criteria still failing. Options:
- Fix issues and run `/ccmagic:verify` again
- Run `/ccmagic:complete-task --force` to complete with known issues
```

## Notes

- Verification is non-destructive - can be run multiple times
- Debug agents get focused context on the specific failure
- Report provides audit trail for what was verified
- Works with or without `<verify>` commands (falls back to manual)
