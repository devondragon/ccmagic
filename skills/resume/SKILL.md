---
user-invocable: true
allowed-tools: Read(*), Bash(git:*), Glob(*), Grep(*), TodoWrite(*), AskUserQuestion(*), Task(*)
description: Resume work from previous session with validation and context restoration
model: sonnet
---

# Resume Previous Work

Restore context from a previous session's handoff file, validate state consistency, and continue where you left off.

## Step 0: Locate Handoff Source

Search for handoff state in priority order:

1. `.continue-here.md` in project root (created by `/ccmagic:checkpoint`)
2. `context/working-state.md` (fallback — always-current project state)

If neither file exists:
> No handoff or working state found. This project may not be initialized yet.
> - Run `/ccmagic:init` to set up a new project
> - Run `/ccmagic:progress` to check current state

Stop here. Do not proceed.

## Step 1: Validate Handoff File

Read the handoff source found in Step 0. Validate it is usable:

### 1a. Format Check

The `.continue-here.md` file must contain at minimum:
- A `## Working On` section with task and branch info
- A `## Next Steps` section with at least one action item

If the file is empty, truncated, or missing these sections:
> Handoff file exists but appears corrupted or incomplete.
> **Found:** [describe what sections are present]
> **Missing:** [list missing required sections]
>
> Options:
> 1. Attempt recovery from `context/working-state.md`
> 2. Start fresh with `/ccmagic:progress`

Use `AskUserQuestion` to let the user choose.

### 1b. Staleness Check

Extract the `Created:` timestamp from the handoff file. Compare against current time.

```bash
# Check handoff age via git log of the file
git log -1 --format="%ai" -- .continue-here.md
```

- **Under 24 hours**: Proceed normally.
- **24-72 hours**: Warn but continue.
  > This handoff is **[N] hours old**. The codebase may have changed since then.
- **Over 72 hours**: Strong warning.
  > This handoff is **[N] days old** and likely stale. Significant changes may have occurred.
  > Recommend running `/ccmagic:progress` for a fresh assessment instead.

Use `AskUserQuestion` if over 72 hours: "Continue with stale handoff or get fresh assessment?"

### 1c. Extract Handoff Fields

Parse from the handoff (all optional except task and next steps): task ID/name, feature ID/name, branch name, progress percentage, completed/remaining items, key decisions, blockers, next steps, context file paths, and continuation notes. These map to the sections in `.continue-here.md` created by checkpoint.

## Step 2: Verify State Consistency

Run these checks in parallel to confirm the handoff matches reality:

### 2a. Branch Verification

```bash
git branch --list "[branch-from-handoff]"
git branch -r --list "origin/[branch-from-handoff]"
git branch --show-current
```

- Exists locally: will switch in Step 4.
- Remote only: will fetch and checkout in Step 4.
- Gone entirely: warn user — branch may have been merged or deleted.

### 2b. Working State Verification

Read `context/working-state.md` and compare against handoff:
- Does the active task match the handoff task?
- Has the working state been updated more recently than the handoff?

If working state shows a *different* active task than the handoff:
> Working state shows active task **[working-state-task]** but handoff references **[handoff-task]**.
> The working state may have been updated by another session.

Use `AskUserQuestion`: "Resume handoff task [X] or follow current working state task [Y]?"

### 2c. Task File Verification

Search for the task file using `context/features/*/tasks/{current,todo,done}/[task-id]*.md`:

- **`current/`**: Task is active — proceed.
- **`todo/`**: Task was reset — proceed but note it.
- **`done/`**: Task already completed. Direct to `/ccmagic:progress` and stop.
- **Not found**: Warn user, proceed with handoff context only.

### 2d. Recent Changes Detection

```bash
git log --oneline --since="[handoff-timestamp]" -- . 2>/dev/null | head -20
git status --short
```

Report any commits since handoff (summarize up to 10) and any uncommitted changes in the working tree.

## Step 3: Load Context (Parallel)

Read all context files simultaneously. Skip missing files silently.

**Always read:** task file from Step 2c, `context/conventions.md`
**From handoff's Context Files section:** feature overview, feature working-state, any other listed files
**Supplementary:** `context/working-state.md` (if not already read in Step 2b)

## Step 4: Restore Environment

### 4a. Switch Branch (if needed)

If the handoff specifies a branch and it differs from the current branch:

```bash
git checkout [handoff-branch]
```

If the branch was only on remote:
```bash
git checkout -b [handoff-branch] origin/[handoff-branch]
```

If the branch no longer exists, stay on the current branch and note it in the summary.

### 4b. Restore TodoWrite Progress

Extract acceptance criteria from the task file. Create TodoWrite entries reflecting current progress:

- Items listed under "Completed" in the handoff: mark as completed
- Items listed under "Remaining" in the handoff: mark as not completed
- If no completed/remaining split is available, create all items as not completed

This makes progress visible in the session's todo list immediately.

## Step 5: Session Context Report

Present a structured summary of the restored session:

```
## Session Resumed

**Task:** [task-id] — [task-name]
**Feature:** [feature-id] — [feature-name]
**Branch:** [current branch] [note if switched]
**Progress:** [percentage]% complete
**Handoff Age:** [time since handoff created]

### What Was Completed
- [completed item 1]
- [completed item 2]

### What Remains
- [remaining item 1]
- [remaining item 2]

### Key Decisions From Previous Session
- [decision 1]
- [decision 2]

### Changes Since Handoff
[N commits since handoff / no changes / uncommitted changes present]

### Blockers
[blockers if any, or "None noted"]

### Next Steps (from handoff)
1. [next step 1]
2. [next step 2]
3. [next step 3]

### Continuation Notes
[any notes from the previous session]
```

## Step 6: Route to Action

Based on the handoff content and current state, determine the appropriate path:

### If task was in progress (implementation incomplete):

Spawn a focused agent to continue the work:

```
Use Task tool with:
  subagent_type: "general-purpose"
  prompt: |
    # Resuming Task: [task-id] — [task-name]

    ## Previous Session Context
    [Embed key handoff content: progress, decisions, blockers]

    ## Task Definition
    [Embed full task file contents]

    ## Project Conventions
    [Embed conventions.md contents, or note if unavailable]

    ## Instructions
    1. Read the feature overview if needed for broader context
    2. Review the previous session's progress and decisions above
    3. Use TodoWrite to set up remaining acceptance criteria
    4. Continue from where the previous session left off
    5. Focus on: [next steps from handoff]
    6. Mark TodoWrite items complete as you progress
    7. Run any verification commands from the task's <verify> section
    8. Report what you accomplished when done

    Pick up exactly where the previous session ended.
    Do not redo completed work.
```

### If awaiting verification:

> Previous session completed implementation. Run `/ccmagic:verify` to validate acceptance criteria.

### If blocked:

> Previous session was blocked on: **[blocker description]**
>
> Options:
> 1. Attempt to resolve the blocker
> 2. Skip and work on a different task
> 3. Create a research spike to investigate

Use `AskUserQuestion` to let the user choose.

### If using working-state fallback (no .continue-here.md):

Do not spawn an agent. Instead, present the working state summary and suggest:
> Restored context from working state (no handoff file found).
> Run `/ccmagic:start-task [task-id]` to begin active work, or `/ccmagic:progress` for a full status check.

## Step 7: Cleanup

After the action in Step 6 completes successfully:

**Only if an agent was spawned and returned successfully:**

```bash
rm .continue-here.md
```

> Handoff file removed. Session resumed successfully.

**If the agent failed, user chose to skip, or no agent was spawned:**
Keep `.continue-here.md` intact for the next attempt.

## Error Recovery Reference

| Scenario | Recovery |
|----------|----------|
| No handoff or working state | Direct to `/ccmagic:init` or `/ccmagic:progress` |
| Corrupted handoff file | Fall back to `context/working-state.md` |
| Branch deleted | Stay on current branch, warn user |
| Task already completed | Direct to `/ccmagic:progress` for next task |
| Working state conflicts with handoff | Ask user which to follow |
| Stale handoff (>72h) | Offer fresh assessment via `/ccmagic:progress` |
| Task file missing | Proceed with handoff context only, warn user |
| Uncommitted changes present | Note in summary, do not discard |

## Notes

- Handoff file is created by `/ccmagic:checkpoint`
- The handoff contains enough context to resume without re-reading full session history
- Always validate before trusting handoff state — the world may have changed
- TodoWrite restoration ensures progress is immediately visible in the new session
- Clean up handoff file only after confirmed successful resumption
