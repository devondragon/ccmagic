# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the **ccmagic** project - a collection of custom slash commands for Claude Code that implement a comprehensive project management and context system. These commands help developers maintain organized project context, track work progress, and enable smooth handoffs between development sessions.

## Development Commands

### Core CCMagic Commands
All commands are available with the `/ccmagic:` prefix when this repository is cloned to `~/.claude/commands/`:

- `/ccmagic:init` - Initialize CCMagic context structure in a project
- `/ccmagic:plan` - Interactive project planning and requirements gathering
- `/ccmagic:start-task [task-id]` - Start working on a specific task
- `/ccmagic:checkpoint` - Save current progress
- `/ccmagic:complete-task [task-id]` - Mark task as completed
- `/ccmagic:handoff` - Create detailed handoff documentation
- `/ccmagic:status` - Check current project and task status
- `/ccmagic:add-backlog` - Add items to the project backlog
- `/ccmagic:context-save` - Save current context state
- `/ccmagic:context-load` - Load saved context state

### Testing & Validation
- `/ccmagic:test` - Run project tests
- `/ccmagic:validate` - Validate code changes
- `/ccmagic:review` - Code review workflow

### Git Workflow
- `/ccmagic:pr` - Create pull request
- `/ccmagic:merge` - Merge changes
- `/ccmagic:sync` - Sync with remote repository

## Code Architecture

### Repository Structure
```
ccmagic/
├── *.md                    # Command definition files (each file = one command)
├── docs/                   # Documentation
│   ├── getting-started.markdown
│   ├── directory-structure.markdown
│   ├── context-systems-reference.markdown
│   ├── claude-code-quickstart.markdown
│   └── claude-code-team-guide.markdown
└── LICENSE
```

### Command File Structure
Each `.md` file in the root directory defines a custom command with:
- **Frontmatter**: YAML configuration including:
  - `allowed-tools`: Tools the command can use
  - `description`: Brief command description
  - `argument-hint`: Expected arguments
  - `model`: Optional model override
- **Body**: Command prompt template using:
  - `$ARGUMENTS` for dynamic values
  - Markdown formatting for instructions

### Key Concepts

#### CCMagic Context System
The commands implement a hierarchical project organization:
- **Epics**: High-level feature groups (e.g., `epic-001-mvp.md`)
- **Features**: Implementation units within epics (e.g., `epic-001-f01-core/`)
- **Tasks**: Specific work items within features
- **Spikes**: One-off research/investigation tasks

#### Directory Structure Created by `/ccmagic:init`
```
context/
├── project.md           # Project overview
├── conventions.md       # Coding standards
├── working-state.md     # Current status
├── backlog.md          # Future work
├── epics/              # Major initiatives
├── features/           # Feature implementations
├── spikes/             # Research tasks
├── knowledge/          # Technical docs
└── sessions/           # Work history
```

## Important Conventions

### When Modifying Commands
1. Maintain backward compatibility - existing projects rely on these commands
2. Test commands in isolation before committing
3. Update relevant documentation in `/docs` when changing command behavior
4. Follow the existing command file naming pattern (kebab-case)

### When Adding New Commands
1. Create a new `.md` file in the root directory
2. Include comprehensive frontmatter configuration
3. Use clear, actionable prompts in the command body
4. Document the command in README.markdown
5. Consider which tools the command needs in `allowed-tools`

### Git Workflow
- Branch from `main` for new features
- Use descriptive commit messages
- Test commands thoroughly before creating PRs
- Update documentation alongside code changes

## Testing

To test a command locally:
1. Clone to `~/.claude/commands/ccmagic/`
2. Run the command in Claude Code: `/ccmagic:commandname [args]`
3. Verify expected behavior and tool usage

## Notes for Development

- Commands should be self-contained and not depend on external state
- Use appropriate model selections in frontmatter for command complexity
- Keep command prompts focused on single responsibilities
- Document complex workflows in the command body itself
- Consider token usage when designing commands that read many files