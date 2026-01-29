---
allowed-tools: Write(*), Read(*), Bash(mkdir -p:*), Glob(*), LS(*), mcp__pal__planner(*), Task(*)
description: Break down an epic into manageable features
argument-hint: epic-id (optional, e.g., epic-001 or epic-001-mvp)
model: opus
---

# Feature Breakdown for Epic

## Implementation Plan

This command will:
1. **Epic Selection:**
   - If epic-id is provided: Use the specified epic
   - If no epic-id: List available epics from `context/epics/` and ask user to choose
   - Validate the epic exists before proceeding

2. **Feature Planning:**
   - Use tiered approach for feature breakdown (see Tool Priority below)

3. **Create Feature Structure:**
   - Create feature directories: `context/features/epic-XXX-fNN-name/`
   - For each feature, create:
     - `overview.md` - Feature scope, acceptance criteria, technical approach
     - `working-state.md` - Progress tracking for this feature
     - `tasks/todo/` directory - Ready for task creation
     - `tasks/current/` directory - For active task
     - `tasks/completed/` directory - For finished tasks

## Tool Priority (MCP Fallback)

**Tier 1 - MCP Tools (if available):**
- Use `mcp__pal__planner` for systematic, AI-assisted feature breakdown
- Provides structured analysis with user value focus and dependency mapping

**Tier 2 - Built-in Claude Code Features (always available):**
- Use `Task` tool with `subagent_type: "Plan"` to design feature breakdown
- Analyze epic scope, identify user-facing capabilities, and suggest feature boundaries
- Consider deployment independence, value delivery, and parallelization opportunities

**Note:** The workflow functions fully without MCP tools. Tier 2 provides equivalent capability using Claude Code's built-in planning features.

## Workflow:
- **Step 1:** Determine which epic to work on (provided or selected)
- **Step 2:** Read the epic file to understand scope and requirements
- **Step 3:** Use tool priority above (MCP if available, otherwise built-in Plan agent)
- **Step 4:** Suggest logical feature boundaries based on:
  - User capabilities and value delivery
  - Technical dependencies
  - Development parallelization opportunities
- **Step 5:** Create 2-5 features per epic typically (or 1 for simple projects)
- **Step 6:** Update the epic file with links to created features

## Output
Creates features in `context/features/epic-XXX-fNN-name/` format with overview.md, working-state.md, and tasks/ directories.

## Notes:
- Features should be independently deployable when possible
- Each feature should deliver user value
- Update epic file with links to created features
