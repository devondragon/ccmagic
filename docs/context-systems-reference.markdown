# Context Documentation Systems Reference
## For AI Assistants & Human Developers

---

## Directory Naming Choice

Use **`/context`** as your top-level directory:
- Universal for all AI tools (Claude, Cursor, Windsurf, Copilot, etc.)
- Clear for human developers
- Short and memorable
- Not vendor-specific

```
project-root/
├── context/          # All project documentation & context
├── src/              # Source code
├── tests/            # Test files
└── ...
```

---

# System 1: Simple & Effective (Small-Medium Projects)
*Best for: Startups, MVPs, teams < 5 devs, projects < 50K LOC*

## Structure
```
project-root/
├── context/
│   ├── project.md           # What we're building & why
│   ├── conventions.md       # How we work (includes Git workflow)
│   ├── working-state.md     # Current progress + active task pointer
│   ├── backlog.md           # Future ideas & tech debt
│   └── tasks/
│       ├── current/         # Individual task files
│       │   ├── task-001-database-schema.md
│       │   └── task-002-user-registration.md
│       └── completed/       # Archived for reference
│           └── task-000-initial-setup.md
```

## Usage
```markdown
# Start of session
"Please read:
1. context/project.md - understand the project
2. context/conventions.md - learn our standards
3. context/working-state.md - see where we left off
4. Check working-state.md for active task, load only that task file"

# During development
"Add that idea to context/backlog.md"
"Move completed task to context/tasks/completed/"

# End of session
"Update context/working-state.md with progress and next steps"
```

## When This Works Best
- Single feature focus
- Rapid development
- Clear task boundaries
- Small, focused teams
- Projects that "fit in your head"
- Token-conscious development (only loads active task)

---

# System 2: Advanced & Structured (Large Projects)
*Best for: Enterprise, teams > 5 devs, multi-team projects, > 50K LOC*

## Structure
```
project-root/
├── context/
│   ├── project.md                 # Core project info
│   ├── conventions.md             # Team standards & Git workflow
│   ├── working-state.md           # Current progress tracker
│   ├── backlog.md                 # Global backlog & tech debt
│   ├── epics/                     # Epic documents
│   │   ├── epic-001-user-management.md
│   │   └── epic-002-payments.md
│   ├── features/                  # Feature-specific organization (epic-XXX-fNN-name)
│   │   ├── epic-001-f01-registration/
│   │   │   ├── overview.md
│   │   │   ├── working-state.md
│   │   │   └── tasks/
│   │   │       ├── task-001-schema.md
│   │   │       └── task-002-form.md
│   │   ├── epic-001-f02-login/
│   │   │   ├── overview.md
│   │   │   ├── working-state.md
│   │   │   └── tasks/
│   │   │       └── task-001-oauth.md
│   │   └── epic-002-f01-checkout/
│   │       ├── overview.md
│   │       ├── working-state.md
│   │       └── tasks/
│   ├── knowledge/                 # Persistent documentation & research
│   │   ├── architecture.md
│   │   ├── data-model.md
│   │   ├── business-rules.md
│   │   ├── api-contracts.md
│   │   ├── tech-debt.md
│   │   └── research-*.md          # Research findings from /ccmagic:research
│   └── sessions/                  # Historical records
│       ├── 2025-01-05-auth.md
│       └── handoffs/
│           └── 2025-01-05-handoff.md
```

## Progressive Loading Strategy
```markdown
# Minimal Context (Bug Fix)
"Read: context/project.md, context/working-state.md, specific task file"

# Standard Context (Feature Work)  
"Read: context/project.md, context/conventions.md, context/working-state.md, current task file"

# Full Context (Major Changes)
"Read all context/*.md files plus relevant knowledge/*.md files"

# Feature-Specific (Advanced Structure)
"Read: context/project.md, context/features/[feature]/overview.md, feature-specific task"
```

## When This Works Best
- Multiple parallel features
- Distributed teams
- Complex business domains
- Heavy compliance requirements
- Long-term maintenance needs
- Multiple AI tools being used
- Need feature isolation (each feature has own tasks/state)

---

# Migration Path: Simple → Advanced

## Level 1: Bare Minimum
```
context/
  project.md
  working-state.md
  tasks/
    current/
    completed/
```

## Level 2: Add Organization
```
context/
  project.md
  conventions.md
  working-state.md
  backlog.md
  tasks/
    current/
    completed/
```

## Level 3: Feature Separation (Simple)
```
context/
  [Level 2 files]
  epics/
    epic-001-mvp.md
  features/
    epic-001-f01-core/
      overview.md
      working-state.md
      tasks/
        task-001-setup.md
        task-002-feature.md
```

## Level 4: Multiple Features
```
context/
  [Core files]
  epics/
    epic-001-mvp.md
  features/
    epic-001-f01-core/
    epic-001-f02-auth/
    epic-001-f03-api/
      overview.md
      working-state.md
      tasks/
```

## Level 5: Full Enterprise Structure
```
context/
  [Core files]
  epics/
    epic-001-user-management.md
    epic-002-payments.md
  features/
    epic-001-f01-registration/
    epic-001-f02-login/
    epic-002-f01-checkout/
      overview.md
      working-state.md
      tasks/
  knowledge/
    architecture.md
    data-model.md
    business-rules.md
  sessions/
    handoffs/
```


---

# Universal Best Practices (Both Systems)

## 1. File Size Limits
- project.md: < 100 lines
- tasks.md: < 200 lines
- Architecture docs: < 300 lines
- No file > 500 lines ever

## 2. Update Frequency
- working-state/current: Every session
- tasks: Start of sprint
- backlog: Continuously
- project: When major changes
- conventions: When patterns establish

## 3. AI Tool Instructions

### For Claude Code:
```bash
# In project root
"Please read:
1. context/project.md
2. context/conventions.md  
3. context/working-state.md
4. Check working-state.md for 'Active Task', load only that task file from context/tasks/current/"
```

### For Cursor:
```bash
# Add to .cursorrules
"Always check context/ directory for project documentation"
```

### For GitHub Copilot:
```bash
# Add to workspace settings
"Context files located in /context directory"
```

### For Windsurf:
```bash
# In cascade file
"Reference /context for project documentation"
```

---

# Choosing Your System

## Use Simple System When:
- ✅ Team size < 5 developers
- ✅ Single product focus
- ✅ Codebase < 50K lines
- ✅ Rapid iteration needed
- ✅ Minimal compliance requirements
- ✅ Team is co-located
- ✅ Using single AI tool

## Use Advanced System When:
- ✅ Team size > 5 developers
- ✅ Multiple features in parallel
- ✅ Codebase > 50K lines
- ✅ Multiple teams involved
- ✅ Strict compliance needs
- ✅ Distributed team
- ✅ Multiple AI tools in use
- ✅ Long-term maintenance (> 2 years)
- ✅ Complex business domain
- ✅ Significant tech debt

## Hybrid Approach
You can also mix both:
- Use simple system for active development
- Use advanced structure for documentation
- Start simple, gradually add structure

---

# Key Differences Summary

| Aspect | Simple System | Advanced System |
|--------|--------------|-----------------|
| Files | 4 core + task files | 15-20+ files |
| Setup Time | 5 minutes | 30 minutes |
| Learning Curve | Immediate | 1-2 days |
| Best For | Small teams | Large teams |
| Context Loading | Progressive (load active task only) | Progressive with feature scope |
| Maintenance | Weekly | Daily |
| Feature Handling | Single feature focus | Parallel features |
| Tech Debt Tracking | backlog.md | backlog.md + knowledge/tech-debt.md |
| Session Memory | working-state.md | working-state.md + sessions/ |
| Task Organization | tasks/current/ and completed/ | features/epic-XXX-fNN-*/tasks/ |

---

# Remember

1. **Start Simple** - You can always add complexity later
2. **Document Consistently** - Pick a system and stick to it
3. **Review Regularly** - Stale docs are worse than no docs
4. **Tool Agnostic** - These work for any AI assistant or human
5. **Evolve Naturally** - Add structure when you feel the pain

The `/context` directory is your single source of truth for project understanding, regardless of who (or what) is reading it.