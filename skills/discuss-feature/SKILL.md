---
user-invocable: true
allowed-tools: Read(*), Write(*), Glob(*), Grep(*), LS(*), Task(*), AskUserQuestion(*)
description: Gather implementation context before task creation
argument-hint: feature-path (e.g., epic-001-f01-core)
model: sonnet
---

# Discuss Feature Implementation

Gather context and implementation decisions BEFORE creating tasks. This ensures task creation has clear direction on gray areas, user preferences, and codebase patterns.

Run this before `/ccmagic:create-tasks` to produce a `CONTEXT.md` that guides task generation.

> **Parallel execution:** Launch independent agents simultaneously. Claude Code determines when this is safe.

## Step 0: Parse Arguments and Select Feature

If `$ARGUMENTS` is provided, treat it as the `feature-path`. Otherwise:
- List available feature directories in `context/features/` using Glob or LS
- Use AskUserQuestion to present the options and capture the user's selection
- If no features exist: inform user to create features first with `/ccmagic:create-features`

Validate the feature directory exists and contains `overview.md` before proceeding.

## Step 1: Load Feature Context

Read these files (skip any that do not exist):

1. **`context/features/[feature-path]/overview.md`** -- feature scope, acceptance criteria, technical approach
2. **`context/project.md`** -- tech stack, project structure, constraints
3. **`context/conventions.md`** -- coding standards, patterns
4. **`CLAUDE.md`** or **`.claude/CLAUDE.md`** -- project-level conventions

Extract from the overview:
- **Feature type**: Classify as one of: API, UI, data-migration, integration, infrastructure, full-stack, or mixed
- **Key nouns**: Domain entities, services, components mentioned
- **Stated technical approach**: Any architecture already decided
- **Acceptance criteria**: What must be true when done

## Step 2: Explore Codebase for Patterns

Before asking any questions, launch parallel Explore agents to discover how the codebase already handles similar work. This grounds the discussion in reality rather than assumptions.

### 2a. Pattern Discovery Agents (parallel)

Launch 2-3 Task agents with `subagent_type: "Explore"` based on what the feature needs:

**Agent 1 -- Similar Implementation Finder:**
> Search the codebase for existing implementations similar to [feature description]. Find files/modules handling similar domain concepts, how they are structured (layout, naming, exports), shared utilities or base classes for reuse, and common patterns. Report file paths, patterns used, reusable components.

**Agent 2 -- Integration Point Mapper:**
> Find all code this feature will integrate with: entry points (routes, handlers, CLI commands), data layer (models, schemas, migrations), shared state (config, env vars, constants), and test infrastructure (helpers, factories, fixtures). Report file paths, integration approach, inconsistencies.

**Agent 3 -- Convention Extractor (if conventions.md is sparse or missing):**
> Analyze the codebase for unwritten conventions relevant to [feature type]: file naming, error handling, logging, and testing patterns. Report observed conventions with 2-3 file examples each.

### 2b. Synthesize Findings

After agents complete, compile a **Pattern Summary**:
- Existing patterns the feature should follow (with file references)
- Reusable utilities and components available
- Integration points that will be touched
- Conventions that apply (documented and observed)
- Gaps where no existing pattern exists (these become questions)

## Step 3: Identify Gray Areas

Review the feature overview against the pattern summary. Categorize unresolved decisions:

**Technical Decisions** -- Architecture choices not yet specified:
- How to structure new code (follow existing pattern vs introduce new one)
- Library/framework choices (if multiple options exist in the codebase)
- Data model questions (schema design, relationships, migrations)
- API design decisions (endpoints, request/response shape, versioning)
- Performance vs simplicity tradeoffs

**Scope Boundaries** -- What is in vs out:
- Edge cases that need clarification
- MVP vs future considerations
- Error handling depth (graceful degradation vs strict failure)
- Backward compatibility requirements

**Integration Decisions** -- How this connects to existing code:
- Which existing patterns to follow (when multiple exist)
- Breaking changes and migration strategy
- External dependency choices

Skip categories where the overview and codebase patterns already provide clear answers. Only surface genuine ambiguities.

## Step 4: Adaptive Questioning

Load `${CLAUDE_SKILL_DIR}/question-patterns.md` for question templates organized by feature type.

### 4a. Select Relevant Questions

Based on the feature type identified in Step 1 and the gray areas from Step 3:
1. Pull question templates matching the feature type
2. Filter out questions already answered by the overview or codebase exploration
3. Group remaining questions into 2-4 rounds (most important first)

### 4b. Conduct Question Rounds

For each round, use AskUserQuestion with grouped related questions. Present context from codebase exploration to inform the user's decisions:

**Format for each question:**
```
[Gray Area]: [specific question]
Codebase context: [relevant pattern/file discovered in Step 2]
Options:
  A) [approach] -- [tradeoff] [recommended if codebase suggests it]
  B) [approach] -- [tradeoff]
  C) Skip -- capture as open question for implementer
```

**Round progression:**
- **Round 1**: Architecture and data model decisions (cascade into everything else)
- **Round 2**: Scope boundaries and edge cases
- **Round 3**: Integration approach and conventions
- **Round 4** (if needed): Follow-ups from user responses that raised new questions

### 4c. Adaptive Depth

- **Simple feature** (1-2 gray areas): 1 round, 2-3 questions max
- **Medium feature** (3-5 gray areas): 2 rounds, 5-8 questions total
- **Complex feature** (6+ gray areas): 3-4 rounds, up to 12 questions

If the user answers "skip" or "not sure", capture as open question rather than pressing further.

### 4d. Follow-up Exploration

If a user's answer references specific codebase patterns (e.g., "follow the auth module"), launch a targeted Explore agent to document that module's structure, key abstractions, public API, and testing approach. Incorporate findings into the decision record.

## Step 5: Validate Gray Area Resolution

Before generating CONTEXT.md, verify completeness:

### 5a. Resolution Check

Review all gray areas identified in Step 3:
- [ ] Each has either a decision (from user) or is explicitly marked as an open question
- [ ] No decision contradicts another decision
- [ ] No decision contradicts an existing codebase pattern without acknowledgment
- [ ] Scope boundaries are explicit -- in-scope and out-of-scope items are listed

### 5b. Gap Detection

Check for common blind spots based on feature type:
- **API features**: Authentication/authorization decided? Error response format? Rate limiting?
- **UI features**: Loading/error/empty states discussed? Accessibility approach? Responsive behavior?
- **Data features**: Migration strategy? Rollback plan? Data validation rules?
- **Integration features**: Failure handling? Retry logic? Circuit breaker? Timeout values?
- **Infrastructure features**: Monitoring? Alerting? Rollback procedure?

If gaps are found, present them in one final AskUserQuestion round:

```
Before finalizing, these areas are still unresolved:

1. [gap description] -- Want to decide now or leave as open question?
2. [gap description] -- Want to decide now or leave as open question?

Options:
  A) Let me answer these now
  B) Mark all as open questions for the implementer
  C) [specific selections]
```

## Step 6: Generate CONTEXT.md

Write to `context/features/[feature-path]/CONTEXT.md`:

```markdown
# Feature Context: [feature-name]

Generated: [YYYY-MM-DD]
Feature: [feature-path]
Feature Type: [API | UI | data-migration | integration | infrastructure | full-stack]

## Implementation Decisions

### [Decision Title]
**Question:** [What was asked]
**Decision:** [User's choice]
**Rationale:** [Why -- from user input or codebase evidence]
**Reference:** [file path or pattern that informed this, if applicable]

[...repeat for each decision]

## Scope Boundaries

### In Scope
- [Item explicitly included]

### Out of Scope
- [Item excluded] -- reason: [why deferred]

### Edge Cases
- [Edge case]: [How to handle]

## Technical Approach

### Architecture
[Summary of architectural decisions referencing existing patterns]

### Patterns to Follow
- [Pattern]: See `[file path]` for reference

### Reusable Components
- `[file/module path]`: [What it provides]

### New Patterns (if any)
- [Pattern]: [Why existing patterns don't fit]

## Dependencies

- **Codebase**: `[file/module]` -- [how this feature depends on it]
- **External**: [library/service] -- [how used, version constraints]
- **Integration**: [system/module] -- [how connected, changes needed]

## Constraints
- [Performance, compatibility, timeline constraints if discussed]

## Open Questions

- [Question]: [Context and partial guidance]

If none remain: "All identified gray areas were resolved during discussion."

---
*Generated by `/ccmagic:discuss-feature`. Read by `/ccmagic:create-tasks` to inform task breakdown.*
```

## Step 7: Summary and Next Step

After writing CONTEXT.md, display:

```
Feature context captured for [feature-path]:

  Decisions made: [N]
  Scope items: [in-scope count] in / [out-of-scope count] out
  Patterns identified: [N] existing, [N] new
  Open questions: [N] (or "none -- all resolved")

  Written to: context/features/[feature-path]/CONTEXT.md

Next: Run /ccmagic:create-tasks [feature-path] to generate tasks informed by this context.
```

## Execution

When invoked, immediately begin the process. Explore the codebase before asking questions -- informed questions produce better decisions. Adapt question depth to feature complexity. Every decision should reference codebase evidence where possible. Quality of context directly determines quality of task breakdown downstream.
