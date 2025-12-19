# CCMagic Directory Structure

## Overview

The CCMagic system uses a hierarchical context directory structure designed to maintain project clarity, enable efficient AI assistance, and support team collaboration. The structure follows a top-down organization from high-level epics to detailed tasks, with dedicated spaces for knowledge management and session tracking.

## Root Structure

```
project-root/
├── CLAUDE.md                    # AI assistant instructions and project-specific rules
├── context/                     # Main context directory (all project state lives here)
│   ├── project.md              # Project overview, tech stack, and key information
│   ├── conventions.md          # Coding standards and team agreements
│   ├── working-state.md       # Current sprint status and active work
│   ├── backlog.md             # Ideas, tech debt, and future improvements
│   ├── epics/                 # High-level feature groups and major initiatives
│   ├── features/              # Feature-specific directories matching epics
│   ├── spikes/                # One-off research and investigation tasks
│   ├── knowledge/             # Persistent technical documentation
│   └── sessions/              # Work session records and handoffs
```

## Directory Purposes

### `/context/` - Root Context Directory
**Purpose**: Central source of truth for all project state and documentation  
**Why**: Keeps all project context in one place, making it easy for both humans and AI to understand project state

### Core Files (Direct in `/context/`)

#### `project.md`
**Purpose**: High-level project overview  
**Contains**:
- What we're building and why
- Current phase/sprint information
- Technology stack details
- Project structure overview
- Development commands
- Important links (repos, staging, production)

#### `conventions.md`
**Purpose**: Team agreements on how to work  
**Contains**:
- Git workflow and branching strategy
- Commit message conventions
- Code style guidelines
- Naming conventions
- Testing standards
- Documentation requirements

#### `working-state.md`
**Purpose**: Current work status snapshot  
**Contains**:
- Active sprint/milestone
- Current task being worked on
- Branch information
- Progress checklist
- Key decisions log
- Environment status
- Next steps

#### `backlog.md`
**Purpose**: Capture ideas without losing focus  
**Contains**:
- Feature ideas (not yet scoped)
- Technical debt items
- Performance optimizations to consider
- Documentation needs
- Questions requiring research

### `/context/epics/`
**Purpose**: High-level feature groupings and major initiatives  
**Naming**: `epic-XXX-descriptive-name.md` (e.g., `epic-001-authentication.md`)  
**Contains**:
- Business value proposition
- User stories
- Success criteria
- Feature breakdown
- Technical approach
- Dependencies
- Effort estimates

**Example Structure**:
```
epics/
├── epic-001-authentication.md
├── epic-002-payment-processing.md
└── epic-003-admin-dashboard.md
```

### `/context/features/`
**Purpose**: Detailed implementation tracking for features within epics  
**Naming**: `epic-XXX-fNN-descriptive-name/` format  
**Why**: Supports one-to-many relationship between epics and features

**Structure Examples**:
```
features/
├── epic-001-f01-setup/           # First feature of epic-001
│   ├── overview.md               # Feature scope and architecture
│   ├── working-state.md         # Current progress and assignments
│   └── tasks/                   # Feature-specific tasks
│       ├── todo/                # Planned tasks
│       │   ├── task-003.md
│       │   └── task-004.md
│       ├── current/             # Active task (usually just one)
│       │   └── task-002.md
│       └── completed/           # Finished tasks
│           └── task-001.md
├── epic-001-f02-deployment/     # Second feature of epic-001
│   ├── overview.md
│   ├── working-state.md
│   └── tasks/
│       ├── todo/
│       ├── current/
│       └── completed/
└── epic-002-f01-login/          # First feature of epic-002
    ├── overview.md
    ├── working-state.md
    └── tasks/
        ├── todo/
        ├── current/
        └── completed/
```

**Naming Convention Breakdown**:
- `epic-XXX`: Parent epic number (e.g., `epic-001`)
- `fNN`: Feature number within epic (e.g., `f01`, `f02`)
- `descriptive-name`: Clear feature name (e.g., `login`, `setup`)

#### Feature Files Explained:

**`overview.md`**: Technical feature documentation
- Parent epic reference
- Feature scope and boundaries
- Architecture decisions
- Task summary and count
- Dependencies

**`working-state.md`**: Real-time progress tracking
- Feature status and timeline
- Task progress (in progress/ready/completed)
- Current focus areas
- Decision log
- Next sync schedule

**`tasks/`**: Feature-specific task directories
- **`todo/`**: Planned tasks not yet started
- **`current/`**: Active task (typically just one at a time)
- **`completed/`**: Finished tasks for reference
- Task files named: `task-XXX-description.md`
- Each task contains acceptance criteria, technical details, estimates

### `/context/spikes/`
**Purpose**: One-off research, investigation, and maintenance tasks not tied to features  
**Structure**:
```
spikes/
├── todo/                    # Planned investigations
│   └── spike-002-evaluate-caching.md
├── current/                 # Active research (usually just one)
│   └── spike-001-auth-libraries.md
└── completed/              # Finished investigations
    └── spike-000-deployment-research.md
```

**What Goes in Spikes**:
- Technical research and POCs
- Framework/library evaluations  
- Performance investigations
- Emergency hotfixes
- Dependency updates
- Learning/exploration tasks

**Spike File Format**:
- Spike ID and title
- Type (Research/Investigation/Maintenance)
- Time box (typically 4-8 hours max)
- Questions to answer
- Success criteria
- Findings/conclusions (when completed)

### `/context/knowledge/`
**Purpose**: Persistent technical documentation that spans features  
**Why**: Centralized reference that doesn't change with each task

**Standard Files**:
```
knowledge/
├── architecture.md      # System design and patterns
├── data-model.md       # Database schema and relationships
├── api-contracts.md    # API endpoints and contracts
├── business-rules.md   # Core business logic documentation
├── tech-debt.md        # Technical debt register with priorities
└── [domain-specific].md # Additional domain knowledge files
```

### `/context/sessions/`
**Purpose**: Track work sessions and enable smooth handoffs  
**Structure**:
```
sessions/
├── handoffs/           # Detailed handoff documents
│   └── 2024-01-15-auth-implementation.md
└── [date]-session.md   # Individual work session notes
```

**Session Files Include**:
- Task(s) worked on
- Progress made
- Decisions and discoveries
- Blockers encountered
- Next steps for continuation

## File Naming Conventions

### IDs and Numbering
- **Epics**: `epic-XXX-name` (e.g., `epic-001-authentication`)
- **Features**: `epic-XXX-fNN-name` (e.g., `epic-001-f01-login`, `epic-001-f02-registration`)
- **Tasks**: `task-XXX-description` within their feature's tasks directories
- **Spikes**: `spike-XXX-description` (e.g., `spike-001-auth-research`)
- **Sessions**: `YYYY-MM-DD-description` format

### Descriptive Names
- Use kebab-case for file names
- Be descriptive but concise
- Include relevant IDs for traceability

## Usage Patterns

### Starting New Work
1. Check `working-state.md` for current status
2. Select task from feature's `tasks/todo/` or spike from `spikes/todo/`
3. Move task to `current/` directory
4. Update working-state.md with task info
5. Work on implementation
6. Update progress in working-state.md

### Adding New Features
1. Create epic in `epics/epic-XXX-name.md` (if not exists)
2. Create feature directory `features/epic-XXX-fNN-name/`
3. Add overview.md and working-state.md
4. Break down into tasks in `features/epic-XXX-fNN-name/tasks/`
5. Multiple features can belong to the same epic

### Completing Tasks
1. Update task file with completion notes
2. Move from `current/` to `completed/` directory
3. Update working-state.md
4. Update feature working-state.md
5. Pick next task from `todo/` or create handoff

### Knowledge Management
- Document decisions in relevant working-state.md files
- Update knowledge base when discovering reusable patterns
- Keep architecture.md current with system changes
- Track tech debt actively in tech-debt.md

## Best Practices

### For Humans
1. **Update working-state.md frequently** - It's your primary communication tool
2. **Use backlog.md liberally** - Capture ideas without breaking flow
3. **Complete one task at a time** - Avoid context switching
4. **Document decisions** - Future you will thank present you

### For AI Assistants
1. **Always read working-state.md first** - Understand current context
2. **Load only active task files** - Minimize token usage
3. **Update files immediately** - Keep state synchronized
4. **Follow conventions.md strictly** - Maintain consistency
5. **Check CLAUDE.md for project-specific instructions**

## Scaling from Simple to Complex

### Light Mode (`/ccmagic:init --light`)
For solo developers and simple projects, use the `--light` flag:
```
context/
├── project.md           # Project overview
├── working-state.md     # Current status
└── backlog.md           # Ideas and future work
```

This minimal setup is ideal for:
- Solo developers
- Quick prototypes
- Learning CCMagic
- Simple single-feature projects

### Simple Project Start (Standard Init)
For a minimal but structured setup:
```
context/
├── epics/
│   └── epic-001-mvp.md           # Single epic for entire MVP
├── features/
│   └── epic-001-f01-core/        # Single feature containing all tasks
│       ├── overview.md
│       ├── working-state.md
│       └── tasks/
│           ├── todo/
│           │   ├── task-002-feature.md
│           │   └── task-003-deploy.md
│           ├── current/
│           │   └── task-001-setup.md
│           └── completed/
└── spikes/
    └── todo/
        └── spike-001-framework-choice.md
```

### Growing Project
As complexity increases, add more features to the epic:
```
context/
├── epics/
│   └── epic-001-mvp.md
└── features/
    ├── epic-001-f01-core/        # Core functionality
    ├── epic-001-f02-auth/        # Authentication (added later)
    └── epic-001-f03-api/         # API endpoints (added later)
```

### Mature Project
Multiple epics with multiple features each:
```
context/
├── epics/
│   ├── epic-001-user-management.md
│   ├── epic-002-payments.md
│   └── epic-003-analytics.md
└── features/
    ├── epic-001-f01-registration/
    ├── epic-001-f02-login/
    ├── epic-001-f03-profile/
    ├── epic-002-f01-checkout/
    ├── epic-002-f02-subscriptions/
    └── epic-003-f01-dashboard/
```

## Benefits of This Structure

### Clear Hierarchy
Epics → Features → Tasks creates natural organization and traceability

### Flexible Scaling
- Start with one epic, one feature
- Add features as scope grows
- Add epics as project matures
- No refactoring needed when scaling

### Separation of Concerns
- Persistent knowledge (knowledge/) vs active work (tasks/, features/)
- Global tasks vs epic-specific tasks
- Current work vs completed work

### Efficient Context Loading
AI assistants can quickly understand project state by reading key files in order:
1. `project.md` - What are we building?
2. `conventions.md` - How do we build?
3. `working-state.md` - What's happening now?
4. Active task file - What needs to be done?

### Team Collaboration
- Clear handoff documentation
- Consistent file locations
- Self-documenting structure
- Progress visible at multiple levels

## Example Workflow

### Developer Starting Their Day
```
1. Read context/working-state.md
2. Check feature working-state if working on epic
3. Load specific task file
4. Begin work following conventions.md
5. Update working-state.md with progress
```

### AI Assistant Helping with Task
```
1. Read CLAUDE.md for project rules
2. Read context/project.md for overview
3. Read context/working-state.md for current state
4. Load specific task from working-state
5. Follow conventions.md for implementation
6. Update working-state.md after changes
```

### Team Lead Reviewing Progress
```
1. Check context/working-state.md for sprint status
2. Review features/*/working-state.md for feature progress
3. Check completed/ for recently finished work
4. Review backlog.md for upcoming priorities
```

## Maintenance Guidelines

### Daily
- Update working-state.md with progress
- Move completed tasks to completed/

### Weekly
- Review and prioritize backlog.md
- Update feature working-states
- Archive old session files

### Per Sprint
- Create new epic/feature structures as needed
- Update project.md with phase changes
- Review and update tech-debt.md

### As Needed
- Update conventions.md when team agrees on new standards
- Enhance knowledge base when discovering patterns
- Create handoff documents for significant work

---

This structure scales from solo projects to large teams while maintaining clarity and enabling efficient AI assistance. The key is consistent usage and regular updates to keep the context fresh and valuable.