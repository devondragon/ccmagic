---
user-invocable: true
allowed-tools: Read(*), Write(*), Bash(git:*, mkdir -p:*, mv:*), Glob(*), Grep(*), LS(*), Task(*), TodoWrite(*), AskUserQuestion(*), mcp__pal__planner(*), mcp__pal__thinkdeep(*)
description: Generate tasks for a specific feature with dependency mapping and sizing
argument-hint: feature-path (optional, e.g., epic-001-f01-core or epic-002-f01-login)
model: sonnet
---

# Task Generation for Feature

Break a feature into well-sized, dependency-ordered tasks with machine-verifiable acceptance criteria.

## Process

### 1. Feature Selection

If `$ARGUMENTS` is provided, treat it as the `feature-path`. Otherwise:
- List available features from `context/features/` using Glob or LS
- Use AskUserQuestion to present options and capture the user's selection
- Validate the feature exists and has an `overview.md` before proceeding

### 2. Gather Context

Read these files in order (skip any that do not exist):

1. **`context/features/[feature-path]/overview.md`** -- feature scope, acceptance criteria, technical approach
2. **`context/features/[feature-path]/CONTEXT.md`** -- implementation decisions from `/ccmagic:discuss-feature`
   - Apply decisions to task breakdown
   - Respect scope boundaries (do not create tasks for out-of-scope items)
   - Reference patterns and files identified in context
3. **`context/conventions.md`** -- coding standards, ID format, commit conventions
4. **`context/project.md`** -- tech stack, project structure

> **Tip:** Run `/ccmagic:discuss-feature` first to clarify gray areas. Tasks will be sharper.

### 3. Explore Codebase

Before planning tasks, explore the codebase to understand existing patterns. This informs acceptance criteria and implementation notes.

Use Grep and Glob to investigate:
- **Existing patterns** -- How similar features are structured (file layout, naming, exports)
- **Test conventions** -- Where tests live, which framework is used, naming patterns
- **Integration points** -- Files that will need modification, shared utilities, config files
- **API patterns** -- Route definitions, controller structure, middleware chains
- **Database patterns** -- Migration format, model definitions, query patterns

Capture findings as implementation notes in each task file.

### 4. Plan Task Breakdown

Use the tiered tool approach for systematic breakdown:

**Tier 1 -- MCP Tools (if available):**
- Use `mcp__pal__planner` for structured task decomposition
- Use `mcp__pal__thinkdeep` for complex dependency analysis

**Tier 2 -- Built-in Claude Code Features (always available):**
- Use `Task` tool with `subagent_type: "Plan"` to design task breakdown
- Analyze feature scope, identify logical work units, map dependencies

The workflow functions fully without MCP tools. Tier 2 provides equivalent capability.

### 5. Apply Sizing Constraints

Read `${CLAUDE_SKILL_DIR}/sizing-guide.md` for detailed heuristics.

**Target: 2-8 hours per task.** Evaluate each proposed task:

**Too large (split it) signals:**
- Acceptance criteria span multiple subsystems (API + UI + DB migration)
- More than 5 acceptance criteria
- Description requires "and" to connect unrelated work
- Estimated at more than 8 hours
- Multiple files in different architectural layers

**Too small (combine it) signals:**
- Single config change with no verification beyond "file exists"
- Under 1 hour of work
- Trivially combined with the task immediately before or after it
- No independent acceptance criteria separate from an adjacent task

**Splitting strategies:**
- Split by architectural layer (data model, API, UI)
- Split by user capability (create vs read vs update vs delete)
- Split by integration boundary (internal logic vs external API)
- Extract setup/infrastructure into a dedicated task-000

### 6. Map Dependencies

For each task, determine:

1. **What it blocks** -- which tasks cannot start until this one is done
2. **What blocks it** -- which tasks must complete before this one starts
3. **Parallel groups** -- tasks with no shared state that can run simultaneously

**Dependency identification rules:**
- Schema/migration tasks block all tasks that read or write those tables
- API endpoint tasks block UI tasks that consume those endpoints
- Shared utility/helper tasks block tasks that import them
- Config/setup tasks block everything that depends on that config
- Test infrastructure tasks block specific test-writing tasks

**Ordering output:**
- Number tasks so that every blocking task has a lower number than the tasks it blocks
- Group parallel-safe tasks with the same numeric prefix when possible
- Mark parallel groups explicitly in each task file

### 7. Create Task Files

Create the directory if it does not exist:
```bash
mkdir -p context/features/[feature-path]/tasks/todo
```

Read the task template from `${CLAUDE_SKILL_DIR}/task-template.md` and generate each task file.

**Naming convention:** `[epic]-[feature]-[seq]-[description].md`
- Example: `001-01-001-setup-database-schema.md`
- Use three-digit zero-padded sequence numbers
- Description is kebab-case, 2-5 words

**For each task file, include all sections from the template:**
- Description and scope
- Acceptance criteria checklist
- `<verify>` blocks with machine-runnable commands
- `<done>` criteria with observable completion state
- Implementation notes (from codebase exploration)
- Dependencies (`addBlockedBy` and `addBlocks` references)
- Parallel group assignment
- Estimated hours

### 8. Write Verify Blocks

Every task must have at least one `<verify>` block. These are commands that return exit code 0 on success.

**Verify block patterns by task type:**

*API endpoint:*
```xml
<verify>curl -sf http://localhost:3000/api/users | jq -e '.data'</verify>
<verify>curl -sf -X POST http://localhost:3000/api/users -H 'Content-Type: application/json' -d '{"name":"test"}' | jq -e '.id'</verify>
```

*Database migration:*
```xml
<verify>npx prisma migrate status | grep -q "applied"</verify>
<verify>npx prisma db pull && diff schema.prisma schema.prisma.backup | grep -q "users"</verify>
```

*UI component:*
```xml
<verify>grep -r "LoginForm" src/components/ | wc -l | grep -q "[1-9]"</verify>
<verify>npm run build 2>&1 | grep -qv "error"</verify>
<verify>npm test -- --testPathPattern="LoginForm" --passWithNoTests 2>&1 | grep -q "passed"</verify>
```

*Configuration change:*
```xml
<verify>grep -q "DATABASE_URL" .env.example</verify>
<verify>node -e "require('./config'); process.exit(0)"</verify>
```

*Test task:*
```xml
<verify>npm test -- --testPathPattern="auth" 2>&1 | grep -q "passed"</verify>
<verify>npm run test:coverage -- --changedSince=main 2>&1 | grep -qE "Statements\s+:\s+[8-9][0-9]|100"</verify>
```

*Documentation task:*
```xml
<verify>test -f docs/api-reference.md</verify>
<verify>grep -q "## Authentication" docs/api-reference.md</verify>
```

**Verify block rules:**
- One command per `<verify>` tag
- Must return exit code 0 on success, non-zero on failure
- Prefer test runners, grep checks, curl calls, or build commands
- At least one verify per acceptance criterion where feasible
- Avoid verify blocks that depend on ephemeral state (running servers) unless the task explicitly sets that up

### 9. Write Done Criteria

Each task must have a `<done>` block. These are human-readable statements of completion:

```xml
<done>
- User table exists with email, name, and password_hash columns
- Migration is reversible (down migration tested)
- Prisma client regenerated and types available
- All existing tests still pass
</done>
```

**Done criteria rules:**
- Specific and testable statements
- Observable behaviors, not implementation details
- Should map to acceptance criteria but phrased as completion state
- Include "all existing tests still pass" for any code-change task

### 10. Update Feature Working State

After creating all tasks, update `context/features/[feature-path]/working-state.md`:

```markdown
## Task Summary
- **Total tasks**: [N]
- **Parallel groups**: [list groups]
- **Critical path**: [longest dependency chain]
- **Estimated total hours**: [sum of estimates]

## Task List
### Group 1 (parallel -- no dependencies)
- [ ] [task-id]: [description] (~Xh)

### Group 2 (depends on Group 1)
- [ ] [task-id]: [description] (~Xh) -- blocked by [task-id]

### Group 3 (depends on Group 2)
- [ ] [task-id]: [description] (~Xh) -- blocked by [task-id]
```

### 11. Present Summary

After creating all tasks, display:

```
Tasks created for [feature-path]:

  Group 1 (parallel):
    001-01-001-description (~3h)
    001-01-002-description (~4h)

  Group 2 (after Group 1):
    001-01-003-description (~6h) -- blocked by 001
    001-01-004-description (~4h) -- blocked by 001, 002

  Total: N tasks, ~Xh estimated
  Critical path: ~Yh

Next: Run /ccmagic:start-task [task-id] to begin work.
Start with any task from Group 1.
```

## Task File Template Reference

Use `${CLAUDE_SKILL_DIR}/task-template.md` for the complete task file structure. Every task file must follow this template.

## Sizing Guide Reference

Use `${CLAUDE_SKILL_DIR}/sizing-guide.md` for detailed heuristics on task sizing, splitting strategies, and dependency patterns.

## Notes

- Tasks should be 2-8 hours each -- see sizing guide for signals
- Number tasks sequentially in dependency order (XXX-YY-ZZZ format)
- Consider a `task-000-setup` if the feature needs infrastructure first
- If CONTEXT.md exists, decisions there override assumptions
- Codebase exploration findings go into implementation notes, not descriptions
- Every task must have at least one `<verify>` block and one `<done>` block
- Mark parallel groups so developers know what can run simultaneously
- Dependencies use task IDs, not task descriptions
