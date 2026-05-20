# ccmagic — dev workflow skills for Claude Code

A focused set of Claude Code skills for the day-to-day dev loop: **tracker-aware ticket lifecycle** (Linear, GitHub Issues, or JIRA), **code review** (adaptive depth, multi-model, ticket-grounded), **debugging**, **design/QA**, and supporting verbs (push, pr, merge, test, validate, research).

> **v3.0.0** — ccmagic was previously a project-management plugin (40 skills for epics/features/tasks/etc.). v3 removes the planning surface in favor of focusing on dev workflow. If you need project planning, use [GSD](https://github.com/devondragon/gsd) or [Superpowers](https://github.com/anthropics/superpowers). See [CHANGELOG.md](./CHANGELOG.md) for the full rationale, what was removed, what replaced it, and the migration path. Short summary at [Migration](#migration-from-v2x) below.

## Quick Start

### Installation

```shell
# Option 1: Marketplace (recommended)
/plugin marketplace add devondragon/ccmagic
/plugin install ccmagic@ccmagic
```

```bash
# Option 2: Direct
git clone https://github.com/devondragon/ccmagic.git ~/ccmagic
claude --plugin-dir ~/ccmagic
```

```bash
# Option 3: Project-local
git clone https://github.com/devondragon/ccmagic.git .claude/plugins/ccmagic
claude --plugin-dir .claude/plugins/ccmagic
```

### First-run setup

```
/ccmagic:init           # Bootstraps conventions.md, branching.md, .claude/ccmagic.local.md
/ccmagic:map-codebase   # Brownfield projects: extracts stack/architecture/conventions
/ccmagic:doctor         # Verify the install is healthy
```

`/ccmagic:init` asks which tracker you want (Linear / GitHub / JIRA / auto) and writes the answer to `.claude/ccmagic.local.md`. See `docs/ccmagic.local.md.example` for all configuration options.

## What ships in v3

23 skills organized by purpose:

### Tracker workflow

| Skill | Purpose |
|---|---|
| `/ccmagic:work-ticket {ID}` | End-to-end: lookup → classify (Quick Fix / Complex / Debug) → branch → implement → review → PR |
| `/ccmagic:review-ticket [ID]` | Code review grounded in the ticket's stated scope and acceptance criteria. Adds explicit in-scope / out-of-scope / missing-from-ticket section |
| `/ccmagic:finish-ticket [--qa]` | Sanity-check PR → merge → close ticket with summary comment |

All three auto-detect the tracker (Linear MCP → GitHub CLI → Atlassian/JIRA MCP) or honor `tracker:` in `.claude/ccmagic.local.md`.

### Code review & quality

| Skill | Purpose |
|---|---|
| `/ccmagic:review [branch\|full\|PR#] [--quick\|--deep]` | Adaptive code review — auto-routes QUICK (inline checklist) vs DEEP (4 core agents + specialists + Codex CLI + MCP + verification). Biased toward depth. |
| `/ccmagic:codex-review [branch\|full\|PR#]` | Multi-model cross-review: Codex + Gemini + Claude triage with dimension-focused passes |
| `/ccmagic:pr-feedback [PR#]` | Triage PR review comments, plan fixes for the valid ones |
| `/ccmagic:validate` | Pre-PR validation in parallel: lint, types, tests, build |
| `/ccmagic:test [pattern] [--coverage] [--watch] [--affected]` | Framework auto-detect, smart selection, coverage analysis, failure diagnosis |

### Git workflow

| Skill | Purpose |
|---|---|
| `/ccmagic:push` | Smart commit and push with logical grouping (validated by the conventional-commit hook) |
| `/ccmagic:pr [--draft]` | Create PR with platform detection (gh/glab) and a smart description |
| `/ccmagic:merge [PR#]` | Safely merge an approved PR (strategy-aware: squash for feature, merge commit for release) |

### Debugging & investigation

| Skill | Purpose |
|---|---|
| `/ccmagic:debug [description] \| resume <slug>` | Systematic debugging with scientific method, parallel investigation, persistent sessions |
| `/ccmagic:analyze-impact [file or name]` | Blast radius / dependency analysis. Three parallel agents trace inbound deps, outbound deps, test coverage |
| `/ccmagic:research <topic>` | Deep iterative research with parallel exploration, source evaluation, confidence scoring |

### Codebase knowledge

| Skill | Purpose |
|---|---|
| `/ccmagic:map-codebase` | Brownfield onboarding — three parallel agents produce STACK / ARCHITECTURE / CONVENTIONS knowledge files |

### Design & visual QA (require Chrome DevTools MCP)

| Skill | Purpose |
|---|---|
| `/ccmagic:design-explore [description] [--count N]` | Generate distinct design directions, compare in browser, pick a winner before building |
| `/ccmagic:design-qa [URL] [--quick\|--deep\|--diff]` | Visual polish audit, catches AI slop, fixes issues atomically |
| `/ccmagic:browser-qa [URL] [--quick\|--exhaustive]` | Systematic real-browser QA — find bugs, fix them, verify with screenshots |

### Quick utilities

| Skill | Purpose |
|---|---|
| `/ccmagic:quick "[task]"` | Ad-hoc task without ticket overhead |

### Meta

| Skill | Purpose |
|---|---|
| `/ccmagic:init` | Bootstrap project config (conventions.md, branching.md, knowledge/, ccmagic.local.md) |
| `/ccmagic:doctor` | Diagnose setup, tracker availability, hook installation, branch convention |
| `/ccmagic:settings` | Configure tracker, QA workflow, ticket-ID regex |
| `/ccmagic:help [skill-name]` | Skill reference |

## Typical workflows

### Working a ticket end-to-end

```
/ccmagic:work-ticket ENG-123     # Linear/JIRA, or use 42 for a GitHub issue
/ccmagic:review-ticket           # Pre-merge: scope drift + code review
/ccmagic:finish-ticket           # Merge + close ticket
```

### Quick task (no ticket)

```
/ccmagic:quick "rename FooBar to BarFoo across services"
/ccmagic:push
/ccmagic:pr
```

### Pre-PR check

```
/ccmagic:validate    # Lint, types, tests, build
/ccmagic:review      # Adaptive code review
```

### Onboarding ccmagic to a brownfield project

```
/ccmagic:init             # Bootstrap config
/ccmagic:map-codebase     # Populate knowledge files
/ccmagic:doctor           # Verify setup
```

## Configuration

ccmagic reads (and `/ccmagic:init` creates) these files in the consuming project:

| File | Purpose |
|---|---|
| `.claude/ccmagic.local.md` | Per-project tracker config (which tracker, URL base, QA workflow, etc.) |
| `context/conventions.md` | Project coding standards — read by review, codex-review, pr-feedback, push, quick |
| `context/branching.md` | Branch strategy — read by pr, merge |
| `context/knowledge/*.md` | Architecture / stack / conventions knowledge — produced by map-codebase; read by review, codex-review, analyze-impact |

See `docs/ccmagic.local.md.example` for the full config template.

## Tracker support

| Tracker | Integration | Auto-detection signal |
|---|---|---|
| **Linear** | Linear MCP server | `mcp__*Linear*__get_issue` registered |
| **GitHub Issues** | `gh` CLI | `command -v gh && gh repo view` |
| **JIRA** | Atlassian MCP server | `mcp__*atlassian*__*` registered |

The tracker-aware skills (`work-ticket`, `finish-ticket`, `review-ticket`) auto-detect, or honor a pinned `tracker:` in `.claude/ccmagic.local.md`. Multi-tracker projects are supported — set `tracker: auto` and let each invocation pick.

## Commit-format hook

ccmagic ships a `PostToolUse` hook (`hooks/post-tool-use-commit.sh`) that validates every commit's subject line against the conventional-commit format documented in `.claude/CLAUDE.md`. It's **non-blocking** — it warns but never rejects, so it's safe to install even on repos with non-conventional commit history.

## Migration from v2.x

Removed skills (now better served by GSD or Superpowers):

```
add-backlog, blockers, checkpoint, complete-task, context-load, context-save,
create-features, create-spike, create-tasks, current-feature, current-task,
daily-standup, discuss-feature, handoff, plan, progress, quick-start, resume,
start-spike, start-task, status, sync, verify
```

New skills:

```
work-ticket      (multi-tracker ticket lifecycle)
review-ticket    (code review grounded in ticket scope)
finish-ticket    (sanity-check + merge + close ticket)
```

The `context/` directory shape has changed:
- **Kept:** `context/conventions.md`, `context/branching.md`, `context/knowledge/`
- **Removed:** `context/features/`, `context/tasks/`, `context/epics/`, `context/spikes/`, `context/sessions/`, `context/backlog.md`, `context/working-state.md`

Existing v2.x project directories aren't auto-migrated — they're harmless if left in place but no v3 skill reads them.

## Plugin format

```
ccmagic/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── skills/
│   └── <name>/SKILL.md
├── hooks/
│   ├── hooks.json
│   └── post-tool-use-commit.sh
├── docs/
│   └── ccmagic.local.md.example
├── .claude/
│   └── CLAUDE.md           # Conventions + dev notes
├── README.md
├── CHANGELOG.md
└── LICENSE
```

## License

Apache-2.0 — see `LICENSE`.

## Author

Devon Hillard ([@devondragon](https://github.com/devondragon))
