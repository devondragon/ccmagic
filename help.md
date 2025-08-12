# Help Command

Display available slash commands organized by typical workflow order.

## Command Overview

### 🚀 Project Setup
- `/ccmagic:init` - Initialize project with CLAUDE.md and context
- `/ccmagic:context-load` - Resume from saved session context

### 📋 Planning & Organization
- `/ccmagic:plan` - Create strategic project plan
- `/ccmagic:create-features` - Break plan into feature epics
- `/ccmagic:create-tasks` - Decompose features into tasks
- `/ccmagic:create-spike` - Define research/exploration spikes
- `/ccmagic:add-backlog` - Add items to product backlog

### 💻 Development Workflow
- `/ccmagic:start-task` - Begin working on a specific task
- `/ccmagic:start-spike` - Start research/exploration spike
- `/ccmagic:current-task` - Show current task details
- `/ccmagic:current-feature` - Display active feature info
- `/ccmagic:status` - View comprehensive project status

### 🔄 Code Management
- `/ccmagic:sync` - Update branch with latest from main
- `/ccmagic:test` - Run test suite for current changes
- `/ccmagic:validate` - Pre-commit validation checks
- `/ccmagic:review` - Detailed code review of changes

### 📤 Collaboration
- `/ccmagic:pr` - Create pull request with smart description
- `/ccmagic:merge` - Merge PR and cleanup branches
- `/ccmagic:checkpoint` - Save progress checkpoint
- `/ccmagic:complete-task` - Mark task as complete

### 💾 Context Management
- `/ccmagic:context-save` - Save current session state
- `/ccmagic:handoff` - Prepare work for team handoff

### ℹ️ Information
- `/ccmagic:help` - Show this help message

## Typical Workflow

```bash
# 1. Start your day
/ccmagic:init                  # Setup project context
/ccmagic:context-load          # Resume previous work
/ccmagic:status               # Check project status

# 2. Begin work
/ccmagic:start-task TASK-123  # Start a task
/ccmagic:sync                 # Sync with main branch

# 3. During development
/ccmagic:test                 # Run tests frequently
/ccmagic:checkpoint           # Save progress
/ccmagic:status              # Check current state

# 4. Before commit
/ccmagic:validate            # Run all checks
/ccmagic:review             # Review your changes

# 5. Submit work
/ccmagic:pr                  # Create pull request
/ccmagic:complete-task      # Mark task done

# 6. Wrap up
/ccmagic:context-save       # Save session
/ccmagic:handoff           # Prepare for team
```

## Quick Tips

- Run `/ccmagic:status` frequently to stay oriented
- Use `/ccmagic:checkpoint` before risky changes
- Always `/ccmagic:validate` before creating PRs
- Save context with `/ccmagic:context-save` before ending sessions
- Run `/ccmagic:sync` daily to avoid conflicts

## Need More Info?

- View any command file directly for detailed documentation
- Each command is self-documenting with examples
- Commands can be chained for efficient workflows
