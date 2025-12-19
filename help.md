---
allowed-tools: Read(*), Glob(*), Bash(git:*), TodoWrite(*)
description: Interactive help and command reference with examples
model: sonnet
---

# CCMagic Help System

Display comprehensive help information about CCMagic commands with practical examples and workflow guidance.

## Command Categories

### 🚀 Getting Started
Commands for initializing and setting up your project:

**`/ccmagic:init`**
- **Purpose**: Initialize the complete CCMagic context structure
- **When to use**: First time setting up CCMagic in a project
- **Creates**: Directory structure, epics, features, tasks, knowledge base
- **Example**:
  ```
  /ccmagic:init
  ```

**`/ccmagic:doctor`**
- **Purpose**: Diagnose setup issues and validate installation
- **When to use**: When something isn't working or to verify setup
- **Checks**: Directory structure, git configuration, file permissions
- **Example**:
  ```
  /ccmagic:doctor
  ```

**`/ccmagic:quick-start [feature-name]`**
- **Purpose**: Fast-track setup for new features
- **When to use**: Starting a new feature without manual setup
- **Does**: Creates feature structure, initial task, starts work
- **Example**:
  ```
  /ccmagic:quick-start user-authentication
  ```

### 📋 Planning & Management
Commands for organizing and planning work:

**`/ccmagic:plan`**
- **Purpose**: Interactive project planning and requirements gathering
- **When to use**: Beginning of projects or major features
- **Output**: Structured epic/feature breakdown with tasks
- **Example**:
  ```
  /ccmagic:plan
  ```

**`/ccmagic:create-features`**
- **Purpose**: Break plan into feature epics
- **When to use**: After planning, before implementation
- **Example**:
  ```
  /ccmagic:create-features
  ```

**`/ccmagic:create-tasks`**
- **Purpose**: Decompose features into tasks
- **When to use**: Breaking down features into work items
- **Example**:
  ```
  /ccmagic:create-tasks
  ```

**`/ccmagic:create-spike`**
- **Purpose**: Define research/exploration spikes
- **When to use**: Need to investigate or research
- **Example**:
  ```
  /ccmagic:create-spike
  ```

**`/ccmagic:add-backlog`**
- **Purpose**: Add items to project backlog
- **When to use**: Capturing ideas without immediate implementation
- **Updates**: `context/backlog.md`
- **Example**:
  ```
  /ccmagic:add-backlog
  ```

### 💼 Daily Workflow
Commands for day-to-day development:

**`/ccmagic:start-task [task-id]`**
- **Purpose**: Begin work on a specific task
- **When to use**: Starting any new task
- **Does**: Creates branch, moves task to current, updates working-state
- **Example**:
  ```
  /ccmagic:start-task 001-01-001-initial-setup
  ```

**`/ccmagic:start-spike`**
- **Purpose**: Start research/exploration spike
- **When to use**: Beginning investigation work
- **Example**:
  ```
  /ccmagic:start-spike
  ```

**`/ccmagic:current-task`**
- **Purpose**: Show current task details
- **When to use**: Quick reference for active task
- **Example**:
  ```
  /ccmagic:current-task
  ```

**`/ccmagic:current-feature`**
- **Purpose**: Display active feature info
- **When to use**: Understanding feature context
- **Example**:
  ```
  /ccmagic:current-feature
  ```

**`/ccmagic:checkpoint`**
- **Purpose**: Save current progress with context
- **When to use**: End of work session, before switching tasks
- **Creates**: Session snapshot with progress notes
- **Example**:
  ```
  /ccmagic:checkpoint
  ```

**`/ccmagic:complete-task [task-id]`**
- **Purpose**: Mark task as completed
- **When to use**: After task is done and tested
- **Does**: Moves task to completed, updates tracking files
- **Example**:
  ```
  /ccmagic:complete-task 001-01-001-initial-setup
  ```

**`/ccmagic:daily-standup`**
- **Purpose**: Generate daily progress summary
- **When to use**: Start or end of day, team standups
- **Output**: Yesterday's work, today's plan, blockers
- **Example**:
  ```
  /ccmagic:daily-standup
  ```

### 🔍 Status & Monitoring
Commands for checking project state:

**`/ccmagic:status`**
- **Purpose**: Show comprehensive project status
- **When to use**: Checking overall progress and health
- **Shows**: Git status, tasks, tests, PRs, blockers
- **Example**:
  ```
  /ccmagic:status
  ```

**`/ccmagic:handoff`**
- **Purpose**: Create detailed handoff documentation
- **When to use**: Ending work session, team transitions
- **Creates**: Complete context for next developer
- **Example**:
  ```
  /ccmagic:handoff
  ```

### 🧪 Testing & Quality
Commands for validation and testing:

**`/ccmagic:test`**
- **Purpose**: Run project tests
- **When to use**: Before commits, during development
- **Runs**: All configured test suites
- **Example**:
  ```
  /ccmagic:test
  ```

**`/ccmagic:validate`**
- **Purpose**: Validate code changes
- **When to use**: Before creating PR
- **Checks**: Tests, linting, type checking, build
- **Example**:
  ```
  /ccmagic:validate
  ```

**`/ccmagic:review`**
- **Purpose**: Code review workflow
- **When to use**: Reviewing code changes
- **Does**: Analyzes changes for quality and issues
- **Example**:
  ```
  /ccmagic:review
  ```

### 🔀 Git & Collaboration
Commands for version control:

**`/ccmagic:pr`**
- **Purpose**: Create pull request
- **When to use**: Ready to merge work
- **Does**: Generates PR with context from tasks
- **Example**:
  ```
  /ccmagic:pr
  ```

**`/ccmagic:merge`**
- **Purpose**: Merge changes
- **When to use**: After PR approval
- **Does**: Safely merges and cleans up branches
- **Example**:
  ```
  /ccmagic:merge
  ```

**`/ccmagic:sync`**
- **Purpose**: Sync with remote repository
- **When to use**: Start of day, before new work
- **Does**: Pulls latest changes, updates branches
- **Example**:
  ```
  /ccmagic:sync
  ```

### 💾 Context Management
Commands for managing project context:

**`/ccmagic:context-save`**
- **Purpose**: Save current context state
- **When to use**: Before major changes
- **Creates**: Context snapshot
- **Example**:
  ```
  /ccmagic:context-save
  ```

**`/ccmagic:context-load`**
- **Purpose**: Load saved context state
- **When to use**: Restoring previous state
- **Restores**: Context from snapshot
- **Example**:
  ```
  /ccmagic:context-load
  ```

## Common Workflows

### Starting a New Project
```
1. /ccmagic:init
2. Edit context/project.md with project details
3. /ccmagic:plan
4. /ccmagic:start-task [first-task-id]
```

### Daily Development Flow
```
Morning:
1. /ccmagic:daily-standup
2. /ccmagic:sync
3. /ccmagic:start-task [task-id]

During Work:
4. Regular commits as you work
5. /ccmagic:checkpoint (periodically)

End of Day:
6. /ccmagic:test
7. /ccmagic:checkpoint
8. /ccmagic:handoff (if needed)
```

### Completing a Feature
```
1. /ccmagic:complete-task [task-id]
2. /ccmagic:validate
3. /ccmagic:pr
4. Wait for review
5. /ccmagic:merge
```

### Troubleshooting
```
1. /ccmagic:doctor
2. /ccmagic:status
3. Check context/working-state.md
```

## Tips & Best Practices

### 🎯 Task Management
- Use descriptive task IDs: `001-01-001-add-user-login`
- Keep tasks small and focused (< 4 hours)
- Update working-state.md frequently
- Move completed tasks promptly

### 📝 Context Files
- `project.md` - Project overview (update rarely)
- `conventions.md` - Team standards (update rarely)
- `working-state.md` - Current status (update constantly)
- `backlog.md` - Future ideas (update often)

### 🔀 Git Workflow
- Always work on feature/task branches
- Never commit directly to main
- Use checkpoint before switching tasks
- Sync regularly to avoid conflicts

### 🧪 Quality Gates
- Run tests before completing tasks
- Validate before creating PRs
- Use review command for self-review
- Keep builds green

## Context Structure Quick Reference

```
context/
├── project.md              # Project overview
├── conventions.md          # Coding standards
├── working-state.md        # Current status ⭐ READ THIS FIRST
├── backlog.md             # Future work
├── branching.md           # Git workflow config
│
├── epics/                 # Major initiatives
│   └── 001-mvp.md        # Epic files
│
├── features/              # Feature implementations
│   └── 001-01-core/      # Feature directory
│       ├── overview.md
│       ├── working-state.md
│       └── tasks/
│           ├── todo/     # Planned tasks
│           ├── current/  # Active task
│           └── completed/# Done tasks
│
├── spikes/               # Research tasks
│   ├── todo/
│   ├── current/
│   └── completed/
│
├── knowledge/            # Technical documentation
│   ├── architecture.md
│   ├── data-model.md
│   ├── business-rules.md
│   └── tech-debt.md
│
└── sessions/             # Work history
    └── handoffs/         # Handoff notes
```

## Need More Help?

### Getting Support
- Check `/ccmagic:doctor` for common issues
- Read `docs/getting-started.markdown`
- Review `docs/context-systems-reference.markdown`

### Understanding CCMagic
- **Epics**: Major feature groups (e.g., MVP, V2)
- **Features**: Specific implementations within epics
- **Tasks**: Concrete work items with acceptance criteria
- **Spikes**: Time-boxed research or investigation

### Command Arguments
- `[task-id]`: Format `XXX-YY-ZZZ-description`
  - XXX: Epic number
  - YY: Feature number
  - ZZZ: Task number
- `[feature-name]`: Kebab-case name (e.g., `user-auth`)

## Quick Command Reference

| Command | Purpose | When |
|---------|---------|------|
| `init` | Setup structure | Once per project |
| `doctor` | Check health | When issues arise |
| `quick-start` | Fast feature setup | New features |
| `plan` | Create roadmap | Planning phase |
| `start-task` | Begin work | Starting tasks |
| `checkpoint` | Save progress | During/end of work |
| `complete-task` | Finish task | Task done |
| `daily-standup` | Daily summary | Daily |
| `status` | Check progress | Anytime |
| `handoff` | Transfer context | End of session |
| `test` | Run tests | Before commits |
| `validate` | Full validation | Before PR |
| `pr` | Create PR | Feature complete |
| `sync` | Update from remote | Daily |

---

**Pro Tip**: Start simple! Use `quick-start` for your first feature and let CCMagic guide you through the workflow.
