# Getting Started with CCMagic

This guide will help you get started with CCMagic, a Claude Code plugin for project management.

## Prerequisites

- Claude Code installed and configured
- Git for cloning the repository

## Installation

### Option 1: Plugin Installation (Recommended)

```bash
# Clone the repository
git clone https://github.com/devondragon/ccmagic.git ~/ccmagic

# Use as a plugin with Claude Code
claude --plugin-dir ~/ccmagic
```

### Option 2: Project-Local Plugin (Recommended for Teams)

```bash
# From your project root
git clone https://github.com/devondragon/ccmagic.git .claude/plugins/ccmagic

# Use with Claude Code
claude --plugin-dir .claude/plugins/ccmagic
```

### Legacy: Slash Commands (Deprecated)

<details>
<summary>Previous installation via ~/.claude/commands/ (no longer recommended)</summary>

```bash
cd ~/.claude/commands/
git clone https://github.com/devondragon/ccmagic.git
```

Note: The legacy slash command files have been removed in v2.0. Use the plugin installation instead.
</details>

## Verify Installation

In Claude Code, try:
```
/ccmagic:help
```

You should see the CCMagic help system with available skills.

## Your First Project

### For Simple Projects (Solo Developer)

```bash
# Initialize with minimal structure
/ccmagic:init --light

# This creates:
# - context/project.md
# - context/working-state.md
# - context/backlog.md
# - CLAUDE.md
```

### For Complex Projects (Teams)

```bash
# Initialize with full structure
/ccmagic:init

# This creates:
# - Full context/ directory with epics, features, tasks
# - Knowledge base directories
# - Session tracking
```

## Essential Skills

| Skill | Purpose |
|-------|---------|
| `/ccmagic:init` | Initialize project structure |
| `/ccmagic:status` | Check current project status |
| `/ccmagic:progress` | Check progress and route to next action |
| `/ccmagic:plan` | Interactive project planning |
| `/ccmagic:start-task` | Begin working on a task |
| `/ccmagic:checkpoint` | Save progress |
| `/ccmagic:complete-task` | Mark task as done |
| `/ccmagic:verify` | Verify acceptance criteria are met |
| `/ccmagic:resume` | Resume work from previous session |
| `/ccmagic:research` | Deep research with source evaluation |
| `/ccmagic:help` | Get help with all skills |

## Typical Workflow

```
1. /ccmagic:init --light          # Set up project
2. /ccmagic:plan my-feature       # Plan your work
3. /ccmagic:start-task            # Begin a task
4. ... work on implementation ...
5. /ccmagic:checkpoint            # Save progress
6. /ccmagic:verify                # Verify acceptance criteria
7. /ccmagic:complete-task         # Finish task
8. /ccmagic:pr                    # Create pull request
```

### Resuming Work

When returning to a project after a break:
```
1. /ccmagic:resume                # Load previous context
2. /ccmagic:progress              # See what's next
3. /ccmagic:start-task            # Continue working
```

## Next Steps

- Read the [Quickstart Guide](claude-code-quickstart.markdown) for a detailed walkthrough
- Check [Directory Structure](directory-structure.markdown) for context organization
- See [Team Guide](claude-code-team-guide.markdown) for collaboration workflows

## Getting Help

- Run `/ccmagic:help` for skill reference
- Run `/ccmagic:doctor` to diagnose setup issues
- Check [GitHub Issues](https://github.com/devondragon/ccmagic/issues) for support
