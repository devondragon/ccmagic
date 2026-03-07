---
user-invocable: true
allowed-tools: Read(*), Write(*), AskUserQuestion(*)
description: Configure CCMagic preferences
model: haiku
disable-model-invocation: true
---

# CCMagic Settings

Configure persistent preferences for this project.

## Process

### 1. Load Current Settings

Check if `context/settings.md` exists. If so, read current configuration.

Display current settings (if any):
```
Current Settings:
- Workflow depth: [value]
- Git behavior: [value]
- Agent context: [value]
- Auto-verification: [value]
```

### 2. Gather Preferences

Use AskUserQuestion to configure each setting category:

#### Workflow Depth
```
How thorough should the workflow be?
```
Options:
- **Quick** - Minimal verification, fast commits. Good for rapid iteration.
- **Standard** (Recommended) - Normal verification, atomic commits. Balanced approach.
- **Thorough** - Full verification, code review prompts. Maximum quality gates.

#### Git Behavior
```
How should git commits be handled?
```
Options:
- **Auto-commit** (Recommended) - Commit automatically on task completion.
- **Prompt** - Ask before each commit.
- **Manual** - Never auto-commit, user handles git.

#### Commit Style
```
What commit message style do you prefer?
```
Options:
- **Conventional** (Recommended) - feat:, fix:, chore:, etc.
- **Simple** - Plain descriptive messages.
- **Ticket prefix** - Include ticket/issue numbers.

#### Agent Context
```
How should agents handle context?
```
Options:
- **Fresh** (Recommended) - Always spawn fresh agents for tasks. Clean context.
- **Reuse** - Reuse session context when possible. Faster but may accumulate noise.

#### Auto-Verification
```
When should verification commands run?
```
Options:
- **Automatic** (Recommended) - Run <verify> commands automatically after implementation.
- **Prompt** - Ask before running verification.
- **Skip** - Don't run automated verification (manual only).

### 3. Write Settings File

Save configuration to `context/settings.md`:

```markdown
# CCMagic Settings

Configured: [timestamp]

## Workflow
depth: [quick|standard|thorough]

## Git
auto_commit: [true|false|prompt]
commit_style: [conventional|simple|ticket]

## Agents
fresh_context: [true|false]

## Verification
auto_verify: [true|false|prompt]

---

## Setting Descriptions

### Workflow Depth
- **quick**: Minimal verification, fast commits
- **standard**: Normal verification, atomic commits
- **thorough**: Full verification with code review prompts

### Git Behavior
- **auto_commit: true**: Commit automatically on task completion
- **auto_commit: false**: Never auto-commit
- **auto_commit: prompt**: Ask before each commit

### Commit Style
- **conventional**: feat:, fix:, chore: prefixes
- **simple**: Plain descriptive messages
- **ticket**: Include ticket/issue numbers (format: [TICKET-123])

### Agent Context
- **fresh_context: true**: Spawn fresh agents for each task
- **fresh_context: false**: Reuse session context when possible

### Auto-Verification
- **auto_verify: true**: Run <verify> commands automatically
- **auto_verify: false**: Skip automated verification
- **auto_verify: prompt**: Ask before running
```

### 4. Confirm Settings

Display saved configuration:

```
Settings saved to context/settings.md

Active Configuration:
- Workflow: [depth]
- Git: [auto_commit] commits, [commit_style] style
- Agents: [fresh/reuse] context
- Verification: [auto/prompt/skip]

These settings will be used by:
- /ccmagic:start-task (agent spawning, verification)
- /ccmagic:complete-task (git commits)
- /ccmagic:verify (auto-run behavior)
- /ccmagic:quick (commit behavior)

Run /ccmagic:settings again to change.
```

## Notes

- Settings are project-specific (stored in context/)
- Other commands should read settings.md to respect preferences
- Defaults are used if settings.md doesn't exist
- Haiku model is sufficient for this configuration task
