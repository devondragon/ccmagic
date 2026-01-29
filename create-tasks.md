---
allowed-tools: Write(*), Read(*), Bash(mkdir -p:*), Glob(*), LS(*), mcp__pal__planner(*), Bash(mv*), Task(*)
description: Generate tasks for a specific feature
argument-hint: feature-path (optional, e.g., epic-001-f01-core or epic-002-f01-login)
model: sonnet
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
   - Use tiered approach for task breakdown (see Tool Priority below)

3. **Create Task Structure:**
   - Generate granular, actionable tasks (2-8 hours each)
   - Create task files in `context/features/[feature-path]/tasks/todo/`
   - Update feature's `working-state.md` with task list and progress tracking

## Tool Priority (MCP Fallback)

**Tier 1 - MCP Tools (if available):**
- Use `mcp__pal__planner` for systematic, AI-assisted task breakdown
- Provides structured analysis and dependency identification

**Tier 2 - Built-in Claude Code Features (always available):**
- Use `Task` tool with `subagent_type: "Plan"` to design task breakdown
- Analyze feature scope, identify logical work units, and create tasks interactively
- Consider dependencies, testing requirements, and documentation needs

**Note:** The workflow functions fully without MCP tools. Tier 2 provides equivalent capability using Claude Code's built-in planning features.

## Task Generation Strategy:
- **Step 1:** Determine which feature to work on (provided or selected)
- **Step 2:** Read feature overview to understand requirements
- **Step 3:** Use tool priority above (MCP if available, otherwise built-in Plan agent)
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
- Technical implementation notes
- Dependencies on other tasks
- Estimated time

## Output
Creates task files in feature's tasks/todo/ directory with time estimates.

## Notes:
- Tasks should be 2-8 hours each
- Number tasks sequentially (XXX-YY-ZZZ format)
- Consider task-000-setup.md if needed
