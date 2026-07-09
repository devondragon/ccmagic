---
name: init
user-invocable: true
allowed-tools: Read(*), Write(*), Bash(git:*), Bash(mkdir:*), Bash(touch:*), AskUserQuestion(*)
description: Bootstrap ccmagic project config — conventions, branching strategy, knowledge directory, and tracker settings
model: sonnet
---

# Initialize ccmagic

Bootstrap the small set of non-planning project files ccmagic needs. Idempotent — if a file already exists, leave it alone.

## What this creates

| File | Purpose | Skills that read it |
|---|---|---|
| `context/conventions.md` | Coding standards | review, codex-review, pr-feedback, push, quick |
| `context/branching.md` | Branch strategy | pr, merge |
| `context/knowledge/` | Architecture/stack/conventions knowledge (populated by `/ccmagic:map-codebase`) | review, codex-review, analyze-impact |
| `.claude/ccmagic.local.md` | Per-project tracker config | work-ticket, finish-ticket, review-ticket |

## Process

### 1. Sanity checks

```bash
git rev-parse --git-dir >/dev/null 2>&1 || echo "ERROR: Not in a git repository. Run `git init` first."
```

If not in a git repo, stop and tell the user.

### 2. Check existing setup

For each file/directory above, check existence. Build a list of:
- **Missing** — will be created.
- **Present** — will be left alone (and listed in the report so the user knows).

If everything is already present, report that and exit cleanly. Offer `/ccmagic:settings` for tracker config tweaks.

### 3. Gather tracker config (interactive)

If `.claude/ccmagic.local.md` is missing, use `AskUserQuestion` to gather:

#### Tracker
- **auto** (Recommended) — detect at runtime
- **linear** — pin Linear (Linear MCP required)
- **github** — pin GitHub Issues (`gh` CLI required)
- **jira** — pin JIRA (Atlassian MCP required)
- **none** — no tracker; ticket-aware skills will be unavailable

If `none`, skip the URL/regex prompts.

#### Ticket URL base (skip if tracker is `none` or `auto`)

Ask for the URL prefix. Examples in the question text:
- Linear: `https://linear.app/yourteam/issue`
- JIRA: `https://your-org.atlassian.net/browse`
- GitHub: `https://github.com/{owner}/{repo}/issues`

#### Default QA workflow
- **No** (Recommended) — finish-ticket defaults to Done; `--qa` opts in
- **Yes** — finish-ticket defaults to the QA disposition

### 4. Write files

Create only the missing ones. Skip any that already exist.

#### `.claude/ccmagic.local.md`

```markdown
---
tracker: {chosen}
ticket_url_base: {url or omit}
ticket_id_regex: "[A-Z][A-Z0-9]+-[0-9]+"
default_qa_workflow: {true|false}
---

# ccmagic project settings

Configured by `/ccmagic:init`. See `docs/ccmagic.local.md.example` in the ccmagic plugin for all recognized keys.
```

#### `context/conventions.md`

```markdown
# Project Conventions

This file is read by ccmagic skills (`review`, `codex-review`, `pr-feedback`, `push`, `quick`) for project-specific guidance.

## Coding standards

- Language: {detected from the repo, or "TBD"}
- Style guide: {e.g. "Prettier + ESLint", "ruff + black", "gofmt"}
- Test framework: {detected, or "TBD"}

## Patterns

(Add patterns specific to this codebase. Examples: error handling style, naming conventions, module boundaries.)

## What ccmagic skills check against

- `/ccmagic:review` and `/ccmagic:codex-review` flag deviations from documented rules here.
- `/ccmagic:push` respects commit message conventions noted here.

> Tip: run `/ccmagic:map-codebase` to auto-extract conventions from the codebase into `context/knowledge/CONVENTIONS.md`. Use this file for *team-decided* conventions; the knowledge file for *observed* patterns.
```

If `package.json`, `pyproject.toml`, `go.mod`, etc. are present, auto-fill the Language/Test/Style fields where you can determine them. Otherwise leave "TBD" so the user fills in.

#### `context/branching.md`

```markdown
# Branching Strategy

Read by `/ccmagic:pr` and `/ccmagic:merge`.

## Strategy

Strategy: trunk-based | gitflow | github-flow

Primary Branch: main

## Conventions

- `feature/{TICKET-ID}-{slug}` — new features
- `bugfix/{TICKET-ID}-{slug}` — bug fixes
- `hotfix/{TICKET-ID}-{slug}` — production hotfixes
- `chore/{TICKET-ID}-{slug}` — maintenance
- `release/{version}` — release branches

## Merge strategy

- feature/bugfix/hotfix/chore → squash merge
- release/* → merge commit
```

#### `context/knowledge/`

```bash
mkdir -p context/knowledge
```

Leave the directory empty — `/ccmagic:map-codebase` populates it.

### 5. Report

```
ccmagic initialized.

Created:
  .claude/ccmagic.local.md
  context/conventions.md
  context/branching.md
  context/knowledge/

Already present (unchanged):
  {list any pre-existing files}

Next steps:
  /ccmagic:map-codebase   — populate context/knowledge/ with stack/architecture/conventions analysis (recommended for brownfield projects)
  /ccmagic:doctor         — verify the setup is healthy
  /ccmagic:work-ticket    — start your first ticket
```

## Notes

- Settings file (`.claude/ccmagic.local.md`) should be committed so the team shares tracker config, unless it contains secrets.
- Existing files are never overwritten — re-running `/ccmagic:init` is safe.
- For tracker config changes after the first run, use `/ccmagic:settings`.
