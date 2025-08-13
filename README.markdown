# ccmagic - Advanced Project Management Commands for Claude Code

A powerful collection of custom slash commands that transform Claude Code into a comprehensive project management system. Maintain organized context, track work progress, manage features and tasks, and enable seamless handoffs between development sessions.

## 🚀 Quick Start

### Installation

#### Option 1: Global Installation (User-wide)

1. Navigate to your Claude commands directory:
   ```bash
   cd ~/.claude/commands/
   ```

2. Clone the ccmagic repository:
   ```bash
   git clone https://github.com/devondragon/ccmagic.git
   ```

3. Start using commands with the `/ccmagic:` prefix in Claude Code!

#### Option 2: Project-local Installation

For team projects or when you want CCMagic versioned with your codebase:

**Using Git Submodule (Recommended for version control):**
```bash
# From your project root
git submodule add https://github.com/devondragon/ccmagic.git .claude/commands/ccmagic
git commit -m "Add CCMagic as submodule"

# Team members can initialize after cloning
git submodule update --init --recursive
```

**Using Direct Copy (Simpler, no submodule complexity - but no updates):**
```bash
# From your project root
mkdir -p .claude/commands

# Download and extract (using curl)
curl -L https://github.com/devondragon/ccmagic/archive/main.tar.gz | \
  tar -xz -C .claude/commands --strip-components=1

# Or using wget
wget -qO- https://github.com/devondragon/ccmagic/archive/main.tar.gz | \
  tar -xz -C .claude/commands --strip-components=1

# Optional: Track commands in your project's git
git add .claude/commands/
git commit -m "Add CCMagic commands to project"

# Or ignore them if you prefer team members to install separately
echo ".claude/commands/" >> .gitignore
```

**Note:** Project-local commands take precedence over global commands. This allows teams to:
- Pin specific CCMagic versions per project
- Customize commands for project needs
- Ensure all team members use the same command versions

### Your First Command

Initialize a new project with the CCMagic context system:
```
/ccmagic:init
```

This creates a complete project management structure in your repository's `context/` directory.

## 📋 Available Commands

### Project Setup & Planning
| Command         | Description                                   | Example                  |
| --------------- | --------------------------------------------- | ------------------------ |
| `/ccmagic:init` | Initialize complete CCMagic context structure | `/ccmagic:init`          |
| `/ccmagic:plan` | Interactive project planning session          | `/ccmagic:plan saas-app` |
| `/ccmagic:help` | Get help with CCMagic commands                | `/ccmagic:help`          |

### Task Management
| Command                    | Description                      | Example                             |
| -------------------------- | -------------------------------- | ----------------------------------- |
| `/ccmagic:create-features` | Create new features for an epic  | `/ccmagic:create-features epic-001` |
| `/ccmagic:create-tasks`    | Break down features into tasks   | `/ccmagic:create-tasks`             |
| `/ccmagic:start-task`      | Start working on a specific task | `/ccmagic:start-task 001-01-003`    |
| `/ccmagic:current-task`    | View current active task         | `/ccmagic:current-task`             |
| `/ccmagic:complete-task`   | Mark task as completed           | `/ccmagic:complete-task 001-01-003` |
| `/ccmagic:checkpoint`      | Save current progress            | `/ccmagic:checkpoint`               |

### Features & Epics
| Command                    | Description                        | Example                          |
| -------------------------- | ---------------------------------- | -------------------------------- |
| `/ccmagic:current-feature` | View current feature status        | `/ccmagic:current-feature`       |
| `/ccmagic:create-spike`    | Create research/investigation task | `/ccmagic:create-spike`          |
| `/ccmagic:start-spike`     | Begin working on a spike           | `/ccmagic:start-spike spike-001` |

### Project Status & Documentation
| Command                | Description                   | Example                |
| ---------------------- | ----------------------------- | ---------------------- |
| `/ccmagic:status`      | Check project and task status | `/ccmagic:status`      |
| `/ccmagic:handoff`     | Create detailed handoff notes | `/ccmagic:handoff`     |
| `/ccmagic:add-backlog` | Add items to project backlog  | `/ccmagic:add-backlog` |

### Context Management
| Command                 | Description                | Example                 |
| ----------------------- | -------------------------- | ----------------------- |
| `/ccmagic:context-save` | Save current context state | `/ccmagic:context-save` |
| `/ccmagic:context-load` | Load saved context state   | `/ccmagic:context-load` |

### Development Workflow
| Command             | Description           | Example             |
| ------------------- | --------------------- | ------------------- |
| `/ccmagic:test`     | Run project tests     | `/ccmagic:test`     |
| `/ccmagic:validate` | Validate code changes | `/ccmagic:validate` |
| `/ccmagic:review`   | Perform code review   | `/ccmagic:review`   |

### Git Integration
| Command          | Description                 | Example          |
| ---------------- | --------------------------- | ---------------- |
| `/ccmagic:pr`    | Create pull request         | `/ccmagic:pr`    |
| `/ccmagic:merge` | Merge changes               | `/ccmagic:merge` |
| `/ccmagic:sync`  | Sync with remote repository | `/ccmagic:sync`  |

## 🏗️ CCMagic Context System

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
│   ├── knowledge/             # Technical docs
│   │   ├── architecture.md
│   │   ├── data-model.md
│   │   └── api-contracts.md
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

## 🎯 Use Cases

### Solo Developer
Start simple with one epic and one feature:
```
/ccmagic:init
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

## 💡 Best Practices

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

## 🛠️ Creating Custom Commands

Add new commands by creating `.md` files in the repository root:

### Example Command Structure
```markdown
---
description: Brief description of the command
argument-hint: expected arguments
allowed-tools: Tool1, Tool2
model: claude-sonnet-4-20250514
---

# Command Title

Your command prompt here using:
- $ARGUMENTS for dynamic values
- Markdown for formatting
```

### Available Tools
Commands can request access to:
- `Write(*)` - File writing
- `Read(*)` - File reading
- `Bash(git:*)` - Git commands
- `Glob(*)` - File pattern matching
- `LS(*)` - Directory listing
- `TodoWrite(*)` - Task management
- And many more...

## 📚 Documentation

Detailed documentation available in the `/docs` directory:
- [Getting Started Guide](docs/getting-started.markdown)
- [Directory Structure Reference](docs/directory-structure.markdown)
- [Context Systems Reference](docs/context-systems-reference.markdown)
- [Claude Code Quickstart](docs/claude-code-quickstart.markdown)
- [Team Collaboration Guide](docs/claude-code-team-guide.markdown)

## 🤝 Contributing

We welcome contributions! To add new commands:

1. Fork the repository
2. Create a new `.md` file for your command
3. Test thoroughly with Claude Code
4. Update this README with your command
5. Submit a pull request

### Contribution Guidelines
- Follow existing command patterns
- Include comprehensive frontmatter
- Document complex workflows
- Test with various project types
- Update relevant documentation

## 📝 License

MIT License - See [LICENSE](LICENSE) file for details

## 🔗 Links

- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Report Issues](https://github.com/devondragon/ccmagic/issues)
- [Feature Requests](https://github.com/devondragon/ccmagic/discussions)

## 🎉 Why CCMagic?

CCMagic transforms Claude Code from a coding assistant into a complete project management system. It provides:

- **Structured Organization**: Hierarchical task management that scales
- **Context Preservation**: Never lose track of what you were working on
- **Team Collaboration**: Smooth handoffs and clear communication
- **AI Optimization**: Efficient context loading for Claude Code
- **Flexibility**: Works for solo projects to enterprise teams

Start using CCMagic today and experience a new level of development productivity with Claude Code!

---

*Built by developers, for developers who want to maintain their sanity while building amazing things.*
