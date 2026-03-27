---
user-invocable: true
allowed-tools: Write(*), Read(*), Bash(mkdir -p:*, git:*), Glob(*), Grep(*), LS(*), Task(*), TodoWrite(*), AskUserQuestion(*), mcp__pal__planner(*)
description: Break down an epic into well-bounded, independently deliverable features
argument-hint: "[epic-id] (e.g., epic-001 or epic-001-mvp)"
model: opus
---

# Feature Breakdown for Epic

Break an epic into well-bounded features using structured decomposition principles. Each feature should be cohesive, independently deliverable, testable, and sized for 3-6 tasks of 2-8 hours each.

> **Parallel execution:** When operations are independent, run them simultaneously.

## Step 0: Parse Arguments and Select Epic

Parse `$ARGUMENTS` for an epic ID:
- If provided: validate the epic exists in `context/epics/`
- If not provided: list available epics and let the user choose via `AskUserQuestion`
- If no epics exist: inform user to create an epic first or use `/ccmagic:plan`

```bash
ls context/epics/
```

## Step 1: Load Context

Read these files to build full understanding before decomposing:

1. **Epic file** — `context/epics/{epic-id}.md` or `context/epics/{epic-id}/overview.md`
2. **Project context** — `context/project.md` (if exists) for project overview and constraints
3. **Conventions** — `context/conventions.md`, `CLAUDE.md`, `.claude/CLAUDE.md` for patterns to follow
4. **Existing features** — `ls context/features/` to understand what already exists and avoid overlap

Load `${CLAUDE_SKILL_DIR}/decomposition-guide.md` for boundary principles and sizing heuristics.
Load `${CLAUDE_SKILL_DIR}/feature-template.md` for the overview.md template.

## Step 2: Analyze Epic Scope

Before decomposing, understand the epic's full scope:

1. **Identify all user capabilities** the epic delivers (what can users do after this ships?)
2. **Identify all technical components** required (APIs, UI, data, integrations, infrastructure)
3. **Map external dependencies** (third-party services, other teams, existing systems)
4. **Note constraints** from the epic file (timeline, technology, compatibility)

## Step 3: Decompose into Features

Use tiered approach for the decomposition:

**Tier 1 — MCP Tools (if available):**
- Use `mcp__pal__planner` for systematic, AI-assisted feature breakdown
- Provide the epic scope analysis from Step 2 as context

**Tier 2 — Built-in (always available):**
- Use `Task` tool with `subagent_type: "Plan"` to design feature breakdown
- Provide the epic scope, project context, and decomposition guide

### Decomposition Principles (from guide)

Apply these boundary tests to each proposed feature:

1. **Cohesion** — Can you describe the feature in one sentence without "and"?
2. **Independence** — Could a developer start this with only epic context?
3. **Testability** — Can you write 3-5 concrete acceptance criteria?
4. **Value delivery** — After this ships, can someone see or use something new?
5. **Sizing** — Will this produce 3-6 tasks of 2-8 hours each?

### Decomposition Patterns (choose the best fit)

- **By capability**: each feature adds one user-facing ability (best for workflow epics)
- **By entity**: each feature handles one domain object end-to-end (best for data-centric epics)
- **By integration**: each feature handles one external system (best for multi-service epics)
- **By layer**: each feature handles one technical layer (use sparingly — prefer vertical slices)

See `${CLAUDE_SKILL_DIR}/decomposition-guide.md` for detailed patterns and anti-patterns.

### Target: 2-6 features per epic
- Simple epics: 2-3 features
- Medium epics: 3-5 features
- Large epics: 5-6 features (if more, consider splitting the epic)

## Step 4: Validate Decomposition

Before creating any files, validate the proposed breakdown:

### Coverage Check
- [ ] Every capability from the epic is covered by at least one feature
- [ ] No epic requirement is orphaned (not assigned to any feature)
- [ ] Edge cases and error handling are assigned to specific features

### Overlap Check
- [ ] No two features deliver the same capability
- [ ] Shared infrastructure is assigned to one feature (not duplicated)
- [ ] Boundaries are clean — modifying one feature doesn't require changing another

### Sizing Check
For each feature:
- [ ] Estimated at 3-6 tasks (if <3, consider merging; if >6, consider splitting)
- [ ] Each task estimable at 2-8 hours
- [ ] Total feature effort: 12-48 hours

### Dependency Check
- [ ] No circular dependencies between features
- [ ] Foundation features (auth, schema, core models) come first
- [ ] Hard dependencies are minimized (prefer soft dependencies)

### Present to User
Show the proposed breakdown via `AskUserQuestion`:

```
Proposed feature breakdown for {epic-name}:

1. {feature-name} — {one-line description} (~{task count} tasks)
   Depends on: none
2. {feature-name} — {one-line description} (~{task count} tasks)
   Depends on: Feature 1
3. {feature-name} — {one-line description} (~{task count} tasks)
   Depends on: none (parallel with Feature 2)

Options:
- Approve — create all features
- Modify — adjust boundaries or ordering
- Redo — start decomposition over with different approach
```

Wait for user approval before proceeding.

## Step 5: Create Feature Directories

For each approved feature, using the ID format `{epic-id}-f{NN}-{description}`:

### Create directory structure
```bash
mkdir -p context/features/{feature-id}/tasks/todo
mkdir -p context/features/{feature-id}/tasks/current
mkdir -p context/features/{feature-id}/tasks/completed
```

### Create overview.md
Use the template from `${CLAUDE_SKILL_DIR}/feature-template.md`. Fill in:
- Feature ID and name
- Epic reference
- Description and scope (in/out)
- Value delivered
- Acceptance criteria (3-5 concrete, testable items)
- Technical approach (key files, patterns to follow)
- Dependencies (hard, soft, blocks)
- Constraints and risks

### Create working-state.md
```markdown
# Working State: {feature-name}

- **Status**: Not Started
- **Current Task**: None
- **Tasks**: 0 todo / 0 current / 0 completed
- **Blockers**: None
- **Last Updated**: {date}
```

## Step 6: Update Epic File

Add feature links to the epic file:

```markdown
## Features
- [{feature-id}](../features/{feature-id}/overview.md) — {description} ({status})
```

## Step 7: Summary and Next Steps

Create `TodoWrite` entries for the recommended workflow:

```
Feature breakdown complete for {epic-name}:
- {N} features created in context/features/
- Recommended order: {ordered list}

Next steps:
1. /ccmagic:discuss-feature {first-feature-id} — gather implementation context
2. /ccmagic:create-tasks {first-feature-id} — generate tasks
3. /ccmagic:start-task — begin development
```

## Execution

When invoked, immediately begin the breakdown process. Load all context before decomposing. Always validate the breakdown and present it for user approval before creating files. Quality of feature boundaries determines the quality of everything downstream — take the time to get boundaries right.
