# Getting Started with CCMagic

This guide will help you get started with the CCMagic custom commands collection for Claude Code.

## Prerequisites

- Claude Code installed and configured
- Git for cloning the repository

## Installation

### Option 1: Global Installation (Recommended for Individual Developers)

```bash
# Navigate to your Claude commands directory
cd ~/.claude/commands/

# Clone the ccmagic repository
git clone https://github.com/devondragon/ccmagic.git

# That's it! Commands are now available with /ccmagic: prefix
```

### Option 2: Project-Local Installation (Recommended for Teams)

```bash
# From your project root - using git submodule
git submodule add https://github.com/devondragon/ccmagic.git .claude/commands/ccmagic
git commit -m "Add CCMagic commands"

# Team members initialize after cloning
git submodule update --init --recursive
```

## Verify Installation

In Claude Code, try:
```
/ccmagic:help
```

You should see the CCMagic help system with available commands.

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

## Essential Commands

| Command | Purpose |
|---------|---------|
| `/ccmagic:init` | Initialize project structure |
| `/ccmagic:status` | Check current project status |
| `/ccmagic:plan` | Interactive project planning |
| `/ccmagic:start-task` | Begin working on a task |
| `/ccmagic:checkpoint` | Save progress |
| `/ccmagic:complete-task` | Mark task as done |
| `/ccmagic:help` | Get help with all commands |

## Typical Workflow

```
1. /ccmagic:init --light          # Set up project
2. /ccmagic:plan my-feature       # Plan your work
3. /ccmagic:start-task            # Begin a task
4. ... work on implementation ...
5. /ccmagic:checkpoint            # Save progress
6. /ccmagic:complete-task         # Finish task
7. /ccmagic:pr                    # Create pull request
```

## Next Steps

- Read the [Quickstart Guide](claude-code-quickstart.markdown) for a detailed walkthrough
- Check [Directory Structure](directory-structure.markdown) for context organization
- See [Team Guide](claude-code-team-guide.markdown) for collaboration workflows

## Getting Help

- Run `/ccmagic:help` for command reference
- Run `/ccmagic:doctor` to diagnose setup issues
- Check [GitHub Issues](https://github.com/devondragon/ccmagic/issues) for support
