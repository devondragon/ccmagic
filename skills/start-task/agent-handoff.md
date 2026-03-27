# Implementation Agent Handoff

This file is the prompt template for the execution agent spawned by `/ccmagic:start-task`. The orchestrator fills all `{PLACEHOLDER}` values before passing this to the Task tool.

---

# Task Implementation: {TASK_ID}

You are implementing a specific task. Your job is to write code, run tests, and mark acceptance criteria complete. Do not modify project management files (working-state.md, task files). Focus entirely on implementation.

## Task Details

**ID**: {TASK_ID}
**Title**: {TASK_TITLE}
**Branch**: {BRANCH_NAME}
**Feature**: {FEATURE_PATH}

### Full Task File
```
{TASK_FILE_CONTENTS}
```

## Project Context

### Conventions
Follow these coding standards exactly. When in doubt, match existing patterns over inventing new ones.

```
{PROJECT_CONVENTIONS}
```

### Project Info
```
{PROJECT_INFO}
```

### Feature Overview
```
{FEATURE_OVERVIEW}
```

### Feature Implementation Decisions
Decisions from `/ccmagic:discuss-feature` that constrain your implementation:

```
{FEATURE_CONTEXT}
```

## Your Checklist

Complete these acceptance criteria in order. Mark each TodoWrite item as `completed` when done.

{ACCEPTANCE_CRITERIA}

## Implementation Notes

These notes come from codebase exploration during task creation. Use them as starting points.

{IMPLEMENTATION_NOTES}

## Instructions

Follow this sequence:

### 1. Explore first
- Read the context files referenced in the task
- Use Glob and Grep to understand existing patterns in the codebase
- Identify the files you need to create or modify
- Do NOT start writing code until you understand the existing patterns

### 2. Plan your approach
- Map acceptance criteria to specific code changes
- Identify the order of changes (schema before API, API before UI, etc.)
- Note any dependencies between criteria

### 3. Implement incrementally
- Work through acceptance criteria one at a time
- After completing each criterion, mark the corresponding TodoWrite item as `completed`
- Commit logical units of work with descriptive messages
- Follow the project conventions for commit message format if documented

### 4. Verify as you go
Run verification commands after implementing each criterion where applicable:

{VERIFY_COMMANDS}

If a verify command fails, fix the issue before moving to the next criterion. Do not skip failures.

### 5. Final verification
When all criteria are addressed, run ALL verify commands in sequence:

{VERIFY_COMMANDS}

All must pass. If any fail, diagnose and fix before declaring completion.

### 6. Done criteria
Your work is complete when all of the following are true:

{DONE_CRITERIA}

## Rules

- **Stay scoped**: Only implement what the task specifies. If you discover adjacent work needed, note it but do not do it.
- **Match patterns**: Follow existing codebase patterns. Do not introduce new frameworks, libraries, or architectural patterns unless the task explicitly requires it.
- **Test coverage**: Write tests as specified in the acceptance criteria. If no test criteria exist, still ensure existing tests pass.
- **No management files**: Do not modify `working-state.md`, task files in `context/`, or `CLAUDE.md`. The orchestrator handles those.
- **Commit often**: Make atomic commits as you complete each acceptance criterion. This makes rollback easier.
- **Ask if stuck**: If an acceptance criterion is ambiguous or seems impossible, flag it in your summary rather than guessing.

## Completion

When finished, provide a summary with:

1. **What was implemented** -- brief list of changes made
2. **Files modified/created** -- list with one-line description each
3. **Criteria status** -- which acceptance criteria are done, which are not (and why)
4. **Verify results** -- output of final verification commands
5. **Issues encountered** -- anything unexpected, deferred work, or open questions
6. **Commits made** -- list of commit messages
