# ccmagic - Advanced Project Management Commands for Claude Code

A powerful collection of skills (formerly slash commands) that transform Claude Code into a comprehensive project management system. Maintain organized context, track work progress, manage features and tasks, and enable seamless handoffs between development sessions.

**Now a Claude Code Plugin**: Parallel subagents, real-time TodoWrite integration, optional MCP tool enhancements, auto-invocation for read-only skills, and subagent isolation for heavy operations.

## Quick Start

### Installation

#### Option 1: Marketplace (Recommended)

```shell
# Add the ccmagic marketplace
/plugin marketplace add devondragon/ccmagic

# Install the plugin
/plugin install ccmagic@ccmagic
```

#### Option 2: Direct Plugin Installation

```bash
# Clone the repository
git clone https://github.com/devondragon/ccmagic.git ~/ccmagic

# Use as a plugin with Claude Code
claude --plugin-dir ~/ccmagic
```

#### Option 3: Project-local Plugin

For team projects, clone into your project:

```bash
# From your project root
git clone https://github.com/devondragon/ccmagic.git .claude/plugins/ccmagic
```

Then reference it with `claude --plugin-dir .claude/plugins/ccmagic`.

### Your First Command

Initialize a new project with the CCMagic context system:
```
/ccmagic:init           # Full setup with epics, features, knowledge base
/ccmagic:init --light   # Minimal setup for simple projects
```

This creates a project management structure in your repository's `context/` directory.

## Available Skills

### Project Setup & Planning
| Skill                 | Description                                        | Example                      |
| --------------------- | -------------------------------------------------- | ---------------------------- |
| `/ccmagic:init`       | Initialize CCMagic context (`--light` for minimal) | `/ccmagic:init --light`      |
| `/ccmagic:plan`       | Interactive planning with EnterPlanMode support    | `/ccmagic:plan saas-app`     |
| `/ccmagic:quick-start`| Fast-track feature setup                           | `/ccmagic:quick-start auth`  |
| `/ccmagic:map-codebase`| Analyze existing codebase and document patterns   | `/ccmagic:map-codebase`      |
| `/ccmagic:settings`   | Configure CCMagic preferences                      | `/ccmagic:settings`          |
| `/ccmagic:help`       | Get help with CCMagic commands                     | `/ccmagic:help`              |
| `/ccmagic:doctor`     | Diagnose setup issues and validate installation    | `/ccmagic:doctor`            |

### Task Management
| Skill                      | Description                                | Example                             |
| -------------------------- | ------------------------------------------ | ----------------------------------- |
| `/ccmagic:create-features` | Create new features for an epic            | `/ccmagic:create-features epic-001` |
| `/ccmagic:discuss-feature` | Gather implementation context before tasks | `/ccmagic:discuss-feature`          |
| `/ccmagic:create-tasks`    | Break down features into tasks             | `/ccmagic:create-tasks`             |
| `/ccmagic:start-task`      | Start working on a specific task           | `/ccmagic:start-task 001-01-003`    |
| `/ccmagic:current-task`    | View current active task                   | `/ccmagic:current-task`             |
| `/ccmagic:complete-task`   | Mark task as completed                     | `/ccmagic:complete-task 001-01-003` |
| `/ccmagic:verify`          | Interactive verification of acceptance criteria | `/ccmagic:verify`              |
| `/ccmagic:checkpoint`      | Save current progress                      | `/ccmagic:checkpoint`               |

### Features & Epics
| Skill                      | Description                        | Example                          |
| -------------------------- | ---------------------------------- | -------------------------------- |
| `/ccmagic:current-feature` | View current feature status        | `/ccmagic:current-feature`       |
| `/ccmagic:create-spike`    | Create research/investigation task | `/ccmagic:create-spike`          |
| `/ccmagic:start-spike`     | Begin working on a spike           | `/ccmagic:start-spike spike-001` |

### Project Status & Documentation
| Skill                    | Description                              | Example                            |
| ------------------------ | ---------------------------------------- | ---------------------------------- |
| `/ccmagic:status`        | Quick project status check (uses haiku)  | `/ccmagic:status`                  |
| `/ccmagic:progress`      | Check progress and route to next action  | `/ccmagic:progress`                |
| `/ccmagic:daily-standup` | Generate standup report from git history | `/ccmagic:daily-standup`           |
| `/ccmagic:handoff`       | Create detailed handoff notes            | `/ccmagic:handoff`                 |
| `/ccmagic:add-backlog`   | Add items to project backlog             | `/ccmagic:add-backlog`             |
| `/ccmagic:blockers`      | Surface and track blockers               | `/ccmagic:blockers`                |
| `/ccmagic:research`      | Deep iterative research with sources     | `/ccmagic:research JWT vs sessions`|

### Context Management
| Skill                   | Description                         | Example                 |
| ----------------------- | ----------------------------------- | ----------------------- |
| `/ccmagic:context-save` | Save current context state          | `/ccmagic:context-save` |
| `/ccmagic:context-load` | Load saved context state            | `/ccmagic:context-load` |
| `/ccmagic:resume`       | Resume work from previous session   | `/ccmagic:resume`       |

### Development Workflow
| Skill                    | Description                                   | Example                            |
| ------------------------ | --------------------------------------------- | ---------------------------------- |
| `/ccmagic:quick`         | Execute ad-hoc task without feature overhead  | `/ccmagic:quick fix typo in login` |
| `/ccmagic:test`          | Run project tests                             | `/ccmagic:test`                    |
| `/ccmagic:validate`      | Validate code (parallel checks)               | `/ccmagic:validate`                |
| `/ccmagic:review`        | Code review with parallel exploration         | `/ccmagic:review`                  |
| `/ccmagic:codex-review`  | Codex CLI review + Claude triage and fix plan | `/ccmagic:codex-review branch`     |
| `/ccmagic:debug`         | Systematic debugging with persistent state    | `/ccmagic:debug login issue`       |
| `/ccmagic:analyze-impact`| Analyze dependencies and blast radius         | `/ccmagic:analyze-impact src/auth` |

### Git Integration
| Skill                | Description                                      | Example              |
| -------------------- | ------------------------------------------------ | -------------------- |
| `/ccmagic:push`      | Smart commit (logical groups) and push           | `/ccmagic:push`      |
| `/ccmagic:pr`        | Create pull request                              | `/ccmagic:pr`        |
| `/ccmagic:pr-feedback`| Review PR comments and plan fixes               | `/ccmagic:pr-feedback`|
| `/ccmagic:merge`     | Merge changes                                    | `/ccmagic:merge`     |
| `/ccmagic:sync`      | Sync with remote repository                      | `/ccmagic:sync`      |

## Claude Code Plugin Features

### Auto-Invocation Control
Skills are categorized by safety:

**Auto-invocable** (read-only/analysis - Claude can suggest these automatically):
`status`, `current-task`, `current-feature`, `progress`, `blockers`, `daily-standup`, `help`, `doctor`, `review`, `validate`, `test`, `analyze-impact`, `discuss-feature`, `pr-feedback`, `research`

**Manual only** (`disable-model-invocation: true` - require explicit `/ccmagic:` invocation):
`init`, `checkpoint`, `complete-task`, `push`, `merge`, `pr`, `sync`, `quick`, `quick-start`, `create-features`, `create-tasks`, `create-spike`, `start-task`, `start-spike`, `add-backlog`, `context-save`, `context-load`, `resume`, `settings`, `codex-review`, `plan`, `handoff`, `map-codebase`, `debug`, `verify`

### Subagent Isolation (`context: fork`)
Heavy skills run in isolated subagents to avoid polluting your main conversation:
`map-codebase`, `review`, `codex-review`, `validate`, `analyze-impact`, `research`, `daily-standup`, `handoff`, `doctor`

### Parallel Subagents
Skills like `/review` and `/analyze-impact` use the Task tool with Explore agents to analyze code in parallel.

### Real-time Progress with TodoWrite
Skills populate Claude Code's native todo UI for visibility:
- `/start-task` creates checklist from acceptance criteria
- `/plan` shows next steps after planning
- Progress updates in real-time as you work

### Model Tiering
Skills use appropriate models for their complexity:
- **haiku**: Fast operations (`/status`, `/daily-standup`, `/blockers`, `/progress`, `/settings`)
- **sonnet**: Standard operations (`/review`, `/validate`, `/start-task`)
- **opus**: Complex reasoning (`/plan`, `/create-features`, `/research`, `/start-spike`)

### Optional MCP Tool Integration
Skills integrate with external MCP tools when available, with graceful fallback:

| Tool | Purpose | Fallback |
|------|---------|----------|
| `mcp__pal__codereview` | Expert code review | Explore agents |
| `mcp__pal__analyze` | Deep analysis | Standard analysis |
| `mcp__pal__planner` | Planning assistance | Task tool with Plan agent |

**All skills work fully without MCP tools** - they're optional enhancements.

### Optional CLI Tool Integration
Some skills integrate with external CLI tools for enhanced capabilities:

| Tool | Skill | Purpose | Fallback |
|------|-------|---------|----------|
| Codex CLI | `/ccmagic:codex-review` | OpenAI's Codex for code review | `/ccmagic:review` |

Install Codex with `npm install -g @openai/codex`. Skills gracefully fall back when tools aren't installed.

## CCMagic Context System

CCMagic creates a hierarchical project organization that scales from simple to complex projects:

### Directory Structure
```
your-project/
├── context/                     # All project context
│   ├── project.md              # Project overview & tech stack
│   ├── conventions.md          # Coding standards
│   ├── working-state.md       # Current status
│   ├── backlog.md             # Ideas & tech debt
│   ├── epics/                 # Major initiatives
│   │   └── epic-001-mvp.md
│   ├── features/              # Feature implementations
│   │   └── epic-001-f01-core/
│   │       ├── overview.md
│   │       ├── working-state.md
│   │       └── tasks/
│   │           ├── todo/
│   │           ├── current/
│   │           └── completed/
│   ├── spikes/                # Research tasks
│   │   ├── todo/
│   │   ├── current/
│   │   └── completed/
│   ├── knowledge/             # Technical docs & research
│   │   ├── architecture.md
│   │   ├── data-model.md
│   │   ├── api-contracts.md
│   │   └── research-*.md      # Research findings from /research
│   └── sessions/              # Work history
│       └── handoffs/
└── CLAUDE.md                   # AI assistant instructions
```

### Hierarchy Explained

- **Epics**: High-level feature groups (e.g., Authentication, Payments, Analytics)
- **Features**: Specific implementations within epics (e.g., Login, Registration, Password Reset)
- **Tasks**: Individual work items within features
- **Spikes**: One-off research or investigation tasks

### ID Convention
Tasks follow the format `XXX-YY-ZZZ-description`:
- `XXX`: Epic number (001)
- `YY`: Feature number (01)
- `ZZZ`: Task number (003)
- Example: `001-01-003-add-login-form`

## Use Cases

### Solo Developer
Start simple with minimal setup:
```
/ccmagic:init --light   # Minimal structure for simple projects
/ccmagic:plan my-feature
/ccmagic:start-task
# Work on tasks
/ccmagic:checkpoint
/ccmagic:complete-task
```

### Team Collaboration
Enable smooth handoffs and parallel work:
```
/ccmagic:handoff          # Developer A creates handoff
/ccmagic:context-load     # Developer B picks up work
/ccmagic:status           # Check team progress
/ccmagic:review           # Code review workflow
```

### Complex Projects
Manage multiple epics and features:
```
/ccmagic:plan enterprise-app
/ccmagic:create-features epic-001
/ccmagic:create-tasks
/ccmagic:start-task 001-02-005
```

## Best Practices

### For Maximum Productivity

1. **Initialize First**: Always run `/ccmagic:init` in new projects
2. **Regular Checkpoints**: Use `/ccmagic:checkpoint` to save progress frequently
3. **Clear Handoffs**: Create handoffs when switching contexts or developers
4. **Update Working State**: Keep `context/working-state.md` current
5. **Use Backlog**: Capture ideas without breaking flow with `/ccmagic:add-backlog`

### Workflow Tips

- Start with a single epic (`001-mvp`) and expand as needed
- Complete one task at a time to avoid context switching
- Use spikes for research that doesn't fit into features
- Document decisions in working-state files
- Review `/ccmagic:status` at the start of each session

## Plugin Structure

```
ccmagic/
├── .claude-plugin/
│   └── plugin.json            # Plugin manifest
├── skills/
│   ├── add-backlog/SKILL.md   # 40 skill directories
│   ├── analyze-impact/SKILL.md
│   ├── ...
│   └── verify/SKILL.md
├── docs/                      # Documentation
├── README.md
└── LICENSE
```

## Contributing

We welcome contributions! To add new skills:

1. Fork the repository
2. Create a new `skills/<name>/SKILL.md` file
3. Include comprehensive frontmatter (`description`, `allowed-tools`, `model`)
4. Add `disable-model-invocation: true` for action skills
5. Add `context: fork` for heavy/long-running skills
6. Test thoroughly with Claude Code
7. Update this README with your skill
8. Submit a pull request

### Contribution Guidelines
- Follow existing skill patterns and frontmatter conventions
- Keep skill descriptions concise (1 line) for context budget
- Document complex workflows in the SKILL.md body
- Extract templates to supporting files if SKILL.md exceeds 500 lines
- Test with various project types

## Documentation

Detailed documentation available in the `/docs` directory:
- [Getting Started Guide](docs/getting-started.markdown)
- [Team Collaboration Guide](docs/claude-code-team-guide.markdown)
- [Claude Code Quickstart](docs/claude-code-quickstart.markdown)
- [Directory Structure Reference](docs/directory-structure.markdown)
- [Context Systems Reference](docs/context-systems-reference.markdown)

## Legacy Slash Commands Format

Looking for the original slash commands version (root-level `.md` files installed to `~/.claude/commands/`)? It's preserved at the [v1.0.0 release](https://github.com/devondragon/ccmagic/releases/tag/v1.0.0):

```bash
git clone --branch v1.0.0 https://github.com/devondragon/ccmagic.git ~/.claude/commands/ccmagic
```

## License

Apache 2.0 License - See [LICENSE](LICENSE) file for details

## Links

- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Report Issues](https://github.com/devondragon/ccmagic/issues)
- [Feature Requests](https://github.com/devondragon/ccmagic/discussions)

## Why CCMagic?

CCMagic transforms Claude Code from a coding assistant into a complete project management system. It provides:

- **Plugin Architecture**: First-class Claude Code plugin with auto-invocation control and subagent isolation
- **Structured Organization**: Hierarchical task management that scales from solo to enterprise
- **Context Preservation**: Never lose track of what you were working on
- **Team Collaboration**: Smooth handoffs, blocker tracking, and clear communication
- **Claude Code Native**: Uses subagents, TodoWrite, and parallel execution for efficiency
- **Flexible Setup**: Light mode for simple projects, full mode for complex ones
- **Optional Enhancements**: PAL MCP tools enhance when available, graceful fallback otherwise
- **Real-time Visibility**: TodoWrite integration shows progress in Claude Code's UI

Start using CCMagic today and experience a new level of development productivity with Claude Code!

---

*Built by developers, for developers who want to maintain their sanity while building amazing things.*
