---
user-invocable: true
allowed-tools: Read(*), Bash(*), Glob(*), Grep(*), Task(*), TodoWrite(*), AskUserQuestion(*), Write(*)
description: Interactive verification of task acceptance criteria
argument-hint: "[task-id or 'current']"
model: sonnet
---

# Verify Task Completion

Run machine-verifiable checks, interactively confirm done criteria, and diagnose failures with Explore agents.

> **Parallel execution:** Independent verify commands and diagnostic agents run simultaneously.

## Step 1: Locate and Parse Task File

### 1a. Find the task file

If `$ARGUMENTS` is "current" or empty:
```bash
ls context/features/*/tasks/current/*.md 2>/dev/null
```

If a task-id is provided:
```bash
find context/features/ -name "*$ARGUMENTS*" -path "*/tasks/*" 2>/dev/null
```

If no task file is found, report the error and stop.

### 1b. Read and parse the task file

Read the task file. Load `${CLAUDE_SKILL_DIR}/verification-guide.md` for parsing rules and failure classification.

Extract three categories of criteria:

**Verify commands** -- shell commands inside `<verify>` tags:
```
<verify>npm test -- --testPathPattern="auth"</verify>
```
Each `<verify>` tag contains exactly one shell command that returns exit code 0 on success.

**Done criteria** -- human-readable statements inside `<done>` tags:
```
<done>
- User table exists with required columns
- All existing tests still pass
</done>
```
Parse each line starting with `- ` as a separate done criterion.

**Acceptance criteria** -- checklist items in the task body (lines matching `- [ ]` or `- [x]`). These serve as the master checklist for TodoWrite integration.

Record the feature path from the task file location for report output later.

## Step 2: Run Verify Commands (Parallel)

Execute all `<verify>` commands simultaneously. For each command:

```bash
bash -c '{verify_command}' 2>&1; echo "EXIT_CODE:$?"
```

Capture both stdout/stderr and exit code for every command.

Build the results table:

| # | Command | Status | Exit Code | Output (truncated) |
|---|---------|--------|-----------|--------------------|
| 1 | `npm test ...` | PASS | 0 | ... |
| 2 | `curl -sf ...` | FAIL | 1 | Connection refused... |

Display the results table immediately so the user sees progress.

### Handling verify edge cases

- **Timeout**: If a command runs longer than 60 seconds, kill it and record as TIMEOUT
- **No verify blocks**: Skip to Step 3 (done criteria check). Note: "No machine-verifiable checks found in task file."
- **All pass**: Proceed to Step 3

## Step 3: Diagnose Failures (Parallel Explore Agents)

For each failed verify command, launch a diagnostic Explore agent. Launch up to 3 agents simultaneously for independent failures.

Before spawning, read the relevant source files. Use Grep to find code related to the failure:
- Parse the verify command for file paths, module names, test patterns
- Read error output for file:line references
- Identify the subsystem under test

### Spawn diagnostic agent

```
Use Task tool with:
  subagent_type: "Explore"
  prompt: |
    # Diagnostic: Verify command failed

    ## Failed Command
    ```
    {verify_command}
    ```

    ## Exit Code: {exit_code}

    ## Output
    ```
    {captured_output}
    ```

    ## Task Context
    This verification is for task: {task_id}
    Task description: {task_description}

    ## Instructions
    1. Read the relevant source files to understand what the command tests
    2. Identify why the command fails — missing file, wrong output, test error, build failure
    3. Classify the failure:
       - MISSING_IMPL: Feature not yet implemented
       - BUG: Implementation exists but behaves incorrectly
       - ENV_ISSUE: Environment, config, or dependency problem
       - TEST_ISSUE: The verify command itself is wrong or outdated
    4. Report:
       - Classification: one of the four types above
       - Root cause: specific explanation with file:line references
       - Suggested fix: concrete steps to resolve
       - Confidence: High / Medium / Low
```

After all diagnostic agents return, collect their classifications and suggested fixes.

## Step 4: Check Done Criteria (Interactive)

For each done criterion parsed from the `<done>` block, use `AskUserQuestion` to confirm:

```
Done Criterion: {criterion text}

Can you confirm this is complete?
- Yes — verified and working
- No — not yet done
- Skip — defer for now
```

If the user answers "No", ask a follow-up:
```
What's the issue with: {criterion text}
- Describe the problem briefly so a diagnostic agent can investigate.
```

For each "No" response with a description, spawn a diagnostic Explore agent (same pattern as Step 3 but using the user's description instead of command output).

Record each criterion as PASS / FAIL / SKIP.

## Step 5: Update Acceptance Criteria Checklist

Map verify results and done criteria back to the acceptance criteria checklist items from the task body.

Use `TodoWrite` to update status:
- Verify PASS + related done criterion PASS = mark complete
- Any FAIL in the chain = mark incomplete with failure note
- SKIP = leave unchanged

Create TodoWrite entries for each unresolved failure:
```
TodoWrite: "VERIFY FAIL: {criterion} — {classification}: {root cause summary}"
```

## Step 6: Generate Verification Report

Build the report and display it directly (do not write to file unless all criteria are checked):

```markdown
# Verification Report: {task-id}
Date: {YYYY-MM-DD}

## Summary
| Metric | Count |
|--------|-------|
| Verify commands | {total} |
| Passed | {pass_count} |
| Failed | {fail_count} |
| Timed out | {timeout_count} |
| Done criteria | {done_total} |
| Confirmed | {confirmed_count} |
| Not done | {notdone_count} |
| Skipped | {skip_count} |

## Verify Command Results
| # | Command | Status | Classification | Root Cause |
|---|---------|--------|----------------|------------|
| 1 | `{cmd}` | PASS/FAIL | — / {type} | — / {cause} |

## Done Criteria Results
| # | Criterion | Status | Notes |
|---|-----------|--------|-------|
| 1 | {text} | PASS/FAIL/SKIP | {user notes or agent finding} |

## Failure Analysis
For each failure:
### {criterion or command}
- **Classification**: {MISSING_IMPL / BUG / ENV_ISSUE / TEST_ISSUE}
- **Root cause**: {explanation with file:line}
- **Suggested fix**: {concrete steps}
- **Confidence**: {High / Medium / Low}

## Verdict
{READY FOR COMPLETION / NEEDS FIXES ({fail_count} issues remaining)}
```

If all criteria pass, also save the report to:
`context/features/{feature-path}/tasks/current/{task-id}-verification.md`

## Step 7: Offer Next Steps

Based on the verdict:

### All pass
```
All acceptance criteria verified.

Next: Run /ccmagic:complete-task to finalize.
```

### Failures remain
Present options via `AskUserQuestion`:

```
{fail_count} verification(s) failed. How to proceed?
- Fix now — I'll address the issues, then re-verify
- Re-run — retry all failed verifications (after making changes)
- Force complete — complete task with known issues noted
- Abort — stop verification, return to development
```

**If "Re-run"**: Re-execute only the previously failed verify commands and re-check failed done criteria. Update the report with new results. Repeat Step 7.

**If "Fix now"**: Display the failure analysis summary and let the user work. Remind them to run `/ccmagic:verify` again when ready.

**If "Force complete"**: Note unresolved issues in TodoWrite entries and proceed.

**If "Abort"**: End verification. TodoWrite entries for failures remain for tracking.

## Execution

When invoked, immediately locate the task file and begin verification. Do not ask for confirmation before running verify commands — they are designed to be safe, read-only checks. Run verify commands in parallel for speed. Display results progressively: verify results first, then interactive done criteria, then the full report. Every failure gets a diagnostic agent so the user receives actionable fix suggestions, not just pass/fail status.
