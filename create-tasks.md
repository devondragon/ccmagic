---
allowed-tools: Write(*), Read(*), Bash(mkdir -p:*), Glob(*), LS(*), mcp__pal__planner(*), Bash(mv*)
description: Generate tasks for a specific feature
argument-hint: feature-path (optional, e.g., epic-001-f01-core or epic-002-f01-login)
---

# Task Generation for Feature

## Implementation Plan

This command will:
1. **Feature Selection:**
   - If feature-path is provided: Use the specified feature
   - If no feature-path: List available features from `context/features/` and ask user to choose
   - Validate the feature exists and has an overview.md before proceeding

2. **Task Planning:**
   - Read the feature's `overview.md` from `context/features/[feature-path]/`
   - **Check for `CONTEXT.md`** - If exists, read implementation decisions from `/ccmagic:discuss-feature`
   - Check if mcp__pal__planner tool is available
   - If available: Use pal:planner to systematically break down the feature into tasks
   - If not available: Analyze feature scope and generate tasks interactively

   > **Tip:** Run `/ccmagic:discuss-feature` first to clarify gray areas. Tasks will be more focused.

3. **Create Task Structure:**
   - Generate granular, actionable tasks (2-8 hours each)
   - Create task files in `context/features/[feature-path]/tasks/todo/`
   - Update feature's `working-state.md` with task list and progress tracking

## Task Generation Strategy:
- **Step 1:** Determine which feature to work on (provided or selected)
- **Step 2:** Read feature overview to understand requirements
- **Step 2b:** Read `CONTEXT.md` if exists (from `/ccmagic:discuss-feature`)
  - Apply implementation decisions to task breakdown
  - Respect scope boundaries (don't create tasks for out-of-scope items)
  - Reference patterns/files identified in context
- **Step 3:** Use pal:planner (if available) for systematic task breakdown
- **Step 4:** Generate tasks considering:
  - Clear acceptance criteria for each task
  - Task dependencies and optimal ordering
  - Implementation tasks
  - Testing tasks
  - Documentation tasks
  - Integration tasks

## Task File Format:
Each task file (`task-XXX-description.md`) will include:
- Parent epic and feature references
- Clear description
- Acceptance criteria checklist
- **Verification commands** (`<verify>` blocks with runnable tests)
- **Done criteria** (`<done>` block with explicit completion state)
- Technical implementation notes
- Dependencies on other tasks
- Estimated time

### Verification Section
Each task should include machine-verifiable checks where possible. These are commands that return exit code 0 on success:

```xml
## Verification
<verify>npm test src/auth/login.test.ts</verify>
<verify>curl -s localhost:3000/api/health | grep '"status":"ok"'</verify>
<verify>grep -r "LoginForm" src/components/ | wc -l | grep -q "[1-9]"</verify>
```

Guidelines for `<verify>` commands:
- One command per `<verify>` tag
- Must return exit code 0 on success, non-zero on failure
- Prefer test commands, grep checks, or API calls
- At least one verify command per acceptance criterion where feasible

### Done Criteria Section
Explicit statement of what "done" means - these are the conditions that must all be true:

```xml
## Done When
<done>
- Login endpoint returns JWT token on valid credentials
- Login endpoint returns 401 with error message on invalid credentials
- Rate limiting applied (max 5 attempts per minute)
- All tests pass
</done>
```

Guidelines for `<done>` criteria:
- Specific and testable statements
- Observable behaviors, not implementation details
- Should map to acceptance criteria but phrased as completion state

## Output
Creates task files in feature's tasks/todo/ directory with time estimates.

## Notes:
- Tasks should be 2-8 hours each
- Number tasks sequentially (XXX-YY-ZZZ format)
- Consider task-000-setup.md if needed
