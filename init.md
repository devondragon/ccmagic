---
allowed-tools: Write(*), Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(mkdir*), Bash(mkdir:*), Bash(mkdir -p:*), Bash(touch:*), AskUserQuestion(*)
description: Initializes CCMagic context (use --light for minimal setup)
argument-hint: [--light] [--full]
model: claude-sonnet-4-20250514
---

# Initialize CCMagic Project

## Mode Detection

Check the arguments to determine initialization mode:

**$ARGUMENTS**

### Light Mode (`--light` or `light`)
Creates minimal structure for simple projects or quick starts:
- `context/project.md` - Project overview
- `context/working-state.md` - Current status
- `context/backlog.md` - Future work
- `CLAUDE.md` - AI instructions

**Best for:** Solo developers, simple projects, quick prototypes, learning CCMagic.

### Full Mode (default or `--full`)
Creates complete structure with epics, features, knowledge management:
- All directories and files (epics, features, spikes, knowledge, sessions)
- Full task tracking hierarchy
- Team collaboration features

**Best for:** Teams, complex projects, enterprise development.

---

### If no flag provided, ask the user:
```
Use AskUserQuestion tool:
{
  questions: [{
    question: "What type of CCMagic setup do you need?",
    header: "Setup Mode",
    options: [
      { label: "Light Mode (Recommended)", description: "Minimal setup: project.md, working-state.md, backlog.md. Best for solo devs and simple projects." },
      { label: "Full Mode", description: "Complete setup with epics, features, tasks, knowledge base. Best for teams and complex projects." }
    ],
    multiSelect: false
  }]
}
```

---

## Light Mode Initialization

If `--light` flag or user selected Light Mode:

```bash
# Create minimal structure
mkdir -p context

# Create only essential files
```

**Files to create in Light Mode:**

1. `context/project.md` - Basic project info
2. `context/working-state.md` - Current status
3. `context/backlog.md` - Ideas and future work
4. `CLAUDE.md` - AI instructions (simplified)

**Skip in Light Mode:** epics/, features/, spikes/, knowledge/, sessions/

---

## Full Mode Initialization

If `--full` flag, user selected Full Mode, or default:

I'll initialize the complete CCMagic context structure for your project with full epics, features, and knowledge management capabilities.

## Creating Directory Structure

### Creating directories:

```bash
# Core directories
mkdir -p context

# Epic and feature management
mkdir -p context/epics
mkdir -p context/features

# Spikes for one-off research/investigation tasks
mkdir -p context/spikes/todo
mkdir -p context/spikes/current
mkdir -p context/spikes/completed

# Knowledge base
mkdir -p context/knowledge

# Session tracking
mkdir -p context/sessions/handoffs
```

## Branching Strategy Configuration

Before creating the context structure, let me ask about your team's git workflow preferences:

### Select Your Branching Strategy:

**Option A: Hierarchical Branches** (Recommended for teams)
- Feature branches from base branch
- Task branches from feature branches  
- Flow: base → feature → task → feature → base
- Best for: teams, complex features, clean history

**Option B: Direct Task Branches**
- Task branches directly from base branch
- Each task merges directly back to base
- Simpler but less organized
- Best for: small features, hotfixes, rapid development

**Option C: Single Feature Branch**  
- Feature branches from base branch
- All tasks committed directly on feature branch
- PR when entire feature complete
- Best for: solo developers, simple features

Please tell me which strategy (A, B, or C) you prefer, and I'll configure the project accordingly.

### Select Your Base Branch:

What is your main development branch?
- **main** (GitHub default, modern standard)
- **develop** (GitFlow pattern)
- **master** (Legacy projects)
- **Custom** (Please specify)

I'll use your selections to create a `context/branching.md` configuration file that all git-related commands will reference.

## Creating Core Files

### 1. Creating `context/branching.md`:
Based on your selections above, I'll create:
```markdown
# Branching Configuration

## Selected Strategy
**Strategy**: [Your selection: A, B, or C]
**Description**: [Description of selected strategy]

## Base Branch
**Primary Branch**: [main/develop/master/custom]
**Description**: All feature and task branches originate from this branch

## Branch Naming Patterns
Based on your selected strategy:
[Specific patterns for the selected strategy]

## Workflow
[Detailed workflow for the selected strategy]

## Merge Direction
[Where branches should be merged based on strategy]

---
*This configuration is used by all CCMagic git-related commands*
```

### 2. Creating `context/project.md`:
```markdown
# Project Name

## What We're Building
[Brief description of the project and its value proposition]

## Current Phase
- Sprint/Milestone: MVP
- Target Date: [TBD]
- Primary Goal: [Define initial goal]

## Tech Stack
- Frontend: [Framework/Library]
- Backend: [Language/Framework]
- Database: [Database System]
- Infrastructure: [Cloud/Hosting]

## Project Structure
```
[TBD]
```

## Development Commands
```bash
[TBD]
```

## Important Links
- Repository: [URL]
- Staging: [URL]
- Production: [URL]
- Documentation: [URL]
```

### 3. Creating `context/conventions.md`:
```markdown
# Development Conventions

## ID Format Convention
**Task IDs**: `XXX-YY-ZZZ-description`
- `XXX`: Epic number (e.g., 001 for first epic)
- `YY`: Feature number within epic (e.g., 01 for first feature)
- `ZZZ`: Task number within feature (e.g., 001 for first task)
- `description`: Brief kebab-case description

Example: `001-01-003-add-user-auth` = Epic 1, Feature 1, Task 3

## Git Workflow
**See `context/branching.md` for your project's configured branching strategy**

The branching strategy and base branch are configured during project initialization.
All git-related commands reference the branching.md configuration to ensure consistency.

## Commit Messages
Follow conventional commits:
   - `feat: Add user authentication`
   - `fix: Resolve login validation bug`
   - `refactor: Simplify error handling`
   - `docs: Update API documentation`
   - `test: Add auth service tests`
   - `chore: Update dependencies`

## Code Style

### Naming Conventions
[TBD]

### TypeScript/JavaScript
[TBD - Project-specific conventions]

## Testing Standards
- Write tests for new features
- Aim for 80% coverage minimum
- Test file naming: `*.test.ts` or `*.spec.ts`

## Documentation
- Update context files regularly
- Document key decisions in working-state.md
- Add JSDoc for complex functions
```

### 4. Creating `context/working-state.md`:
```markdown
# Working State

## Current Focus
- **Epic**: None
- **Feature**: None
- **Task**: None (completed or not started)
- **Last Updated**: [Today's Date]

## Active Work Hierarchy
### Current Epic
**ID**: None assigned
**Name**: N/A
**Status**: Not started

### Current Feature
**ID**: None assigned
**Name**: N/A
**Parent Epic**: N/A
**Status**: Not started

### Current Task
**ID**: None assigned (format: XXX-YY-ZZZ-description)
**Name**: N/A
**Parent Feature**: N/A
**Branch**: N/A
**Started**: N/A
**Status**: Completed or Not started

### Progress
- [ ] Waiting for work assignment

## Key Decisions
<!-- Document important technical decisions here -->

## Environment Setup
- [ ] Development environment configured
- [ ] Dependencies installed
- [ ] Tests passing

## Next Steps
1. Select an epic from `context/epics/`
2. Select a feature from `context/features/XXX-YY-name/`
3. Choose a task from the feature's `tasks/todo/` directory
4. Run `/start-task [task-id]` to begin
```

### 5. Creating `context/backlog.md`:
```markdown
# Backlog

## 🚀 Feature Ideas
<!-- Features we want to build but aren't in current scope -->

---

## 🐛 Tech Debt
<!-- Technical improvements and refactoring needs -->

---

## 🎯 Performance Optimizations
<!-- Performance improvements to consider -->

---

## 📝 Documentation Needs
<!-- Documentation that needs to be written or updated -->

---

## 💭 Questions to Research
<!-- Technical questions that need investigation -->
```

### 6. Creating `context/epics/001-mvp.md`:
```markdown
# Epic 001: MVP Development

## Business Value
Deliver core functionality that validates product concept.

## Success Criteria
- [ ] Core features implemented
- [ ] Deployed to production

## Feature Breakdown
[TBD based on project]

## Dependencies
[TBD]
```

### 7. Creating feature directory structure:

```bash
# Create feature directory for the MVP epic
# Features use format: 001-01-feature-name (epic-feature)
mkdir -p context/features/001-01-core
mkdir -p context/features/001-01-core/tasks/todo
mkdir -p context/features/001-01-core/tasks/current
mkdir -p context/features/001-01-core/tasks/completed
```

### 8. Creating `context/features/001-01-core/overview.md`:
```markdown
# Feature: Core Functionality

## Parent Epic
001: MVP Development

## Feature Scope
Implementation of the primary functionality that delivers user value

## Architecture Decisions
- Start with simple, working solution
- Refactor as requirements become clearer

## Task Summary
- Total tasks: TBD
- Completed: 0
- In Progress: 0

## Dependencies
- Project setup complete
```

### 9. Creating `context/features/001-01-core/working-state.md`:
```markdown
# Feature: Core Functionality - Working State

## Feature Status
- **Started**: [Today's Date]
- **Target Completion**: TBD
- **Owner**: [Developer Name]

## Task Progress

### In Progress
- [ ] None yet

### Ready to Start
- [ ] 001-01-001-initial-setup

### Completed
- [ ] None yet

## Current Focus
[What's being worked on]

## Decisions Log
- [Date]: [Decision]

## Next Sync
[Date/Time]
```

### 10. Creating task files for the feature:

Creating `context/features/001-01-core/tasks/todo/001-01-001-initial-setup.md`:
```markdown
# Task 001-01-001: Initial Setup

## Parent Epic
001: MVP Development

## Parent Feature
Core Functionality

## Description
Set up the initial project structure and development environment

## Acceptance Criteria
- [ ] Project builds successfully
- [ ] Development environment runs
- [ ] Basic project structure in place

## Technical Details
- Initialize project with chosen framework
- Set up development dependencies
- Configure build tools

## Estimated Time
2-4 hours
```

### 11. Creating example spike:

Creating `context/spikes/todo/spike-001-research-framework.md`:
```markdown
# Spike 001: Research Framework Options

## Type
Research / Investigation

## Time Box
4 hours maximum

## Goal
Evaluate and recommend the best framework for our use case

## Questions to Answer
- [ ] Performance characteristics
- [ ] Learning curve for team
- [ ] Community support
- [ ] Long-term maintainability

## Success Criteria
- Recommendation with pros/cons documented
- Decision recorded in knowledge/architecture.md

## Notes
[Research findings will go here]
```

### 12. Creating knowledge base files:

#### `context/knowledge/architecture.md`:
```markdown
# System Architecture

## Overview
[System description]

## Architecture Pattern
[Pattern used]

## Key Components
- Component A: [purpose]
- Component B: [purpose]

## Data Flow
1. [Step 1]
2. [Step 2]

## Technology Decisions
- [Decision 1]: [Reasoning]
- [Decision 2]: [Reasoning]
```

#### `context/knowledge/data-model.md`:
```markdown
# Data Model

## Database Schema
[TBD]

## API Contracts
[TBD]

## State Management
[TBD]
```

#### `context/knowledge/business-rules.md`:
```markdown
# Business Rules

## User Management
- [Rule 1]
- [Rule 2]

## Data Validation
- [Validation rule 1]
- [Validation rule 2]

## Business Logic
- [Logic rule 1]
- [Logic rule 2]
```

#### `context/knowledge/api-contracts.md`:
```markdown
# API Contracts

## Authentication Endpoints
[TBD]

## User Endpoints
[TBD]
```

#### `context/knowledge/tech-debt.md`:
```markdown
# Technical Debt Register

## High Priority
- **Issue**: [Description]
  - Impact: [What it affects]
  - Effort: [Estimated time]
  - Added: [Date]

## Medium Priority
[Items to address when time permits]

## Low Priority
[Nice-to-have improvements]
```

### 13. Creating placeholder for sessions:
```markdown
# Creating context/sessions/example-session.md

# Session: [Date]

## Task Worked On
[Task ID]

## Progress Made
- [What was completed]

## Next Steps
- [What to do next]

## Notes
[Any important notes]
```

---

## Creating CLAUDE.md in Project Root

```markdown
# Claude Code Instructions

This project uses the CCMagic System.

## Quick Start
1. Read `context/project.md` to understand the project
2. Read `context/conventions.md` for coding standards
3. Read `context/working-state.md` for current status
4. Check working-state.md for active task, load only that file

## Available Commands
- `/ccmagic:init` - Initialize CCMagic context (already done!)
- `/ccmagic:start-task [id]` - Start working on a task
- `/ccmagic:checkpoint` - Save progress
- `/ccmagic:complete-task [id]` - Complete a task
- `/ccmagic:handoff` - Create handoff notes
- `/ccmagic:add-backlog` - Add item to backlog

## Important Rules
1. Always create feature branches before changes
2. Update working-state.md regularly
3. Follow conventions.md strictly
4. Add ideas to backlog.md (don't implement)
5. Move completed tasks to tasks/completed/

## Context Structure
- Core files in context/
- Epics in epics/XXX-name.md (e.g., 001-mvp.md)
- Features in features/XXX-YY-name/ (e.g., 001-01-core/)
  - overview.md - Feature overview and scope
  - working-state.md - Current progress
  - tasks/todo/ - Planned tasks
  - tasks/current/ - Active task (usually just one)
  - tasks/completed/ - Finished tasks
- Spikes in spikes/ for research & one-off tasks
  - todo/ - Planned investigations
  - current/ - Active spike
  - completed/ - Finished research
- Knowledge base in knowledge/
- Sessions in sessions/

## Starting Simple
For solo developers or simple projects:
- Use one epic: `001-mvp`
- Use one feature: `001-01-core`
- Focus on tasks within that feature
- Add more epics/features only as needed
```

---

## Final Setup

Creating `.gitkeep` files in empty directories:
```bash
touch context/epics/.gitkeep
touch context/features/.gitkeep
touch context/features/001-01-core/tasks/todo/.gitkeep
touch context/features/001-01-core/tasks/current/.gitkeep
touch context/features/001-01-core/tasks/completed/.gitkeep
touch context/spikes/todo/.gitkeep
touch context/spikes/current/.gitkeep
touch context/spikes/completed/.gitkeep
touch context/sessions/handoffs/.gitkeep
touch context/knowledge/.gitkeep
```

---

## ✅ Initialization Complete!

**Complete CCMagic Structure Created**

### Next Steps:
1. Update `context/project.md` with your project details
2. Update `context/conventions.md` with your team standards
3. Create your first task in `context/tasks/current/`
4. Run `/start-task [id]` to begin development

### Quick Reference:
- **Check status:** Look at `context/working-state.md`
- **Add ideas:** Update `context/backlog.md`
- **Start work:** `/start-task [task-id]`
- **Save progress:** `/checkpoint`

Your CCMagic context structure is ready for use!
