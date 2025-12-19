---
allowed-tools: Write(*), Read(*), Bash(mkdir -p:*), Glob(*), LS(*), mcp__zen__planner(*)
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
   - First check if mcp__zen__planner tool is available
   - If available: Use zen:planner to systematically break down the epic into features
   - If not available: Use interactive session to identify features within the epic

3. **Create Feature Structure:**
   - Create feature directories: `context/features/epic-XXX-fNN-name/`
   - For each feature, create:
     - `overview.md` - Feature scope, acceptance criteria, technical approach
     - `working-state.md` - Progress tracking for this feature
     - `tasks/todo/` directory - Ready for task creation
     - `tasks/current/` directory - For active task
     - `tasks/completed/` directory - For finished tasks

## Workflow:
- **Step 1:** Determine which epic to work on (provided or selected)
- **Step 2:** Read the epic file to understand scope and requirements
- **Step 3:** Use zen:planner (if available) for systematic feature breakdown
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
