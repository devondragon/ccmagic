---
allowed-tools: Write(*), Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(mkdir*), Bash(mkdir:*), Bash(mkdir -p:*), Bash(touch:*), AskUserQuestion(*)
description: Initializes CCMagic context (use --light for minimal setup)
argument-hint: [--light | --full]
model: sonnet
disable-model-invocation: true
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

Read and follow the full mode template at `${CLAUDE_SKILL_DIR}/full-template.md` to create the complete CCMagic context structure.

---

## Initialization Complete!

**Complete CCMagic Structure Created**

### Next Steps:
1. Update `context/project.md` with your project details
2. Update `context/conventions.md` with your team standards
3. Create your first task in `context/tasks/current/`
4. Run `/ccmagic:start-task [id]` to begin development

### Quick Reference:
- **Check status:** Look at `context/working-state.md`
- **Add ideas:** Update `context/backlog.md`
- **Start work:** `/start-task [task-id]`
- **Save progress:** `/checkpoint`

Your CCMagic context structure is ready for use!
