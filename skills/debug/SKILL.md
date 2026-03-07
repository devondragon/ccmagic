---
user-invocable: true
allowed-tools: Read(*), Write(*), Bash(*), Glob(*), Grep(*), Task(*), AskUserQuestion(*)
description: Systematic debugging with persistent investigation
argument-hint: "[description of the bug]"
model: sonnet
disable-model-invocation: true
---

# Structured Debugging

Systematic bug investigation with persistent state across sessions.

## Process

### 1. Capture Symptoms

If `$ARGUMENTS` provided, use as initial bug description.

If no arguments, use AskUserQuestion to gather:
- What's the expected behavior?
- What's the actual behavior?
- Steps to reproduce?
- When did it start happening?

### 2. Create Debug File

Create directory if needed: `context/debug/`

Create debug session file: `context/debug/[YYYYMMDD-HHMMSS]-[slug].md`

```markdown
# Debug: [brief description]
Created: [timestamp]
Status: investigating

## Symptoms
**Expected:** [expected behavior]
**Actual:** [actual behavior]

**Repro Steps:**
1. [step]
2. [step]
3. [step]

**When Started:** [if known]
**Environment:** [relevant env details]

## Investigation Log

### Attempt 1 - [timestamp]
**Hypothesis:** [what we think is wrong]
**Evidence Gathered:** [what we looked at]
**Result:** [confirmed/rejected/inconclusive]
**Notes:** [observations]

## Root Cause
[To be filled when found]

## Fix Applied
[To be filled when fixed]

## Verification
[How we confirmed the fix works]
```

### 3. Spawn Investigation Agent

```
Use Task tool with:
  subagent_type: "general-purpose"
  prompt: |
    # Debug Investigation

    ## Bug
    **Expected:** [expected behavior]
    **Actual:** [actual behavior]
    **Repro:** [steps to reproduce]

    ## Instructions
    1. Form a hypothesis about the root cause
    2. Gather evidence:
       - Read relevant code files
       - Check logs if available
       - Trace execution path
       - Look for recent changes (git log/diff)
    3. Confirm or reject your hypothesis with evidence
    4. If rejected, form a new hypothesis and repeat
    5. When root cause is found:
       - Document the evidence clearly
       - If fix is straightforward (<20 lines), implement it
       - If fix is complex, describe what needs to change
    6. Report your findings:
       - Root cause (or best hypothesis if not found)
       - Evidence supporting your conclusion
       - Fix applied (if any)
       - Suggested next steps (if not resolved)
```

### 4. Update Debug File

After agent returns, update the debug session file:

- Log the investigation attempt with findings
- Update status if root cause found
- If fix was applied, update "Fix Applied" section
- If still investigating, note current hypothesis

### 5. Multi-Round Support

If bug is not resolved after agent returns:

Use AskUserQuestion:
```
Bug Status: [current status]
Latest Findings: [summary of what agent found]

How would you like to proceed?
```

Options:
- **"Another investigation round"** - Spawn new agent with accumulated context
- **"Create fix task"** - Add to backlog for structured work
- **"Mark as blocked"** - Note current findings, pause investigation
- **"Close as resolved"** - If fix was successful

If "Another investigation round" selected:
- Read the updated debug file
- Spawn new agent with all previous findings as context
- Agent should build on previous hypotheses, not start fresh

### 6. Resolution

When bug is resolved:

1. Update debug file:
   - Status: `resolved`
   - Document root cause clearly
   - Document the fix
   - Note verification steps

2. Move to resolved: `context/debug/resolved/`

3. Summary:
```
Bug resolved!

Root Cause: [brief description]
Fix: [what was changed]
Files Modified: [list]

Debug log saved to: context/debug/resolved/[filename]
```

### 7. Optional: Create Related Task

If the fix revealed need for additional work:

```
Related improvements identified:
- [improvement 1]
- [improvement 2]

Add these to backlog? (y/n)
```

If yes, ensure `context/backlog.md` exists and create a "## From Debugging" section if it does not already exist, then append the items under that section.

## Notes

- Debug files persist across sessions for continuity
- Each investigation round builds on previous findings
- Agents get focused context on the specific bug
- Multi-round approach handles complex bugs
- Resolved bugs create audit trail in `context/debug/resolved/`
