---
user-invocable: true
allowed-tools: Read(*), Glob(*), LS(*), Write(*), Task(*), Bash(rm:*)
description: Resume work from previous session
model: sonnet
disable-model-invocation: true
---

# Resume Previous Work

Restore context from handoff file and continue where you left off.

## Process

### 1. Find Handoff

Look for `.continue-here.md` in project root.

If not found:
```
No handoff found. Run `/ccmagic:progress` to see current state.
```
(Exit without further action)

### 2. Load Context

Read `.continue-here.md` and extract:
- What was being worked on (task/feature/quick task)
- Current progress summary
- Key decisions made
- Blockers encountered
- Next steps outlined
- Context files to read

### 3. Display Handoff Summary

Show the user what they were working on:

```
## Resuming Previous Session

**Task:** [task being worked on]
**Feature:** [parent feature]
**Progress:** [where we left off]
**Next:** [what to do next]

### Key Decisions Made
- [decision 1]
- [decision 2]

### Blockers/Concerns
- [any blockers noted]

### Context Files
[List files mentioned in handoff]
```

### 4. Route to Action

Based on handoff content, determine the appropriate action:

**If task was incomplete (implementation in progress):**

Spawn agent to continue implementation:

```
Use Task tool with:
  subagent_type: "general-purpose"
  prompt: |
    # Resuming Task: [task-id]

    ## Previous Session Context
    [Embed handoff file contents]

    ## Task File
    [Read and embed task file contents]

    ## Context Files to Read
    [List from handoff]

    ## Instructions
    1. Review the previous session context above
    2. Read the context files listed
    3. Continue from where we left off
    4. Focus on: [next steps from handoff]
    5. Use TodoWrite to track remaining work
    6. Report what you accomplished

    Pick up exactly where the previous session ended.
```

**If awaiting verification:**
```
Previous session completed implementation and needs verification.
Run `/ccmagic:verify` to validate acceptance criteria.
```

**If blocked:**
```
Previous session was blocked on: [blocker description]

Options:
1. Attempt to resolve the blocker
2. Skip and work on something else
3. Create a spike to investigate
```
(Use AskUserQuestion if available, otherwise just display options)

### 5. Cleanup

After successfully resuming (only if agent successfully returned and work has resumed, not on failure):

Check if work was successfully resumed:
- If agent returned with completion/progress, proceed with cleanup
- If agent failed or user chose to skip, keep handoff file for next attempt

```bash
# Only remove if resumption was successful
rm .continue-here.md
```

Confirm cleanup:
```
Handoff file removed. Session resumed successfully.
```

## Notes

- Handoff file is created by `/ccmagic:checkpoint`
- Contains enough context to resume without re-reading everything
- Agent gets focused context from handoff, not full session history
- Clean up handoff file only after successful resume
