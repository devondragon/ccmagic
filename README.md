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

24 skills organized by purpose:

### Tracker workflow

| Skill | Purpose |
|---|---|
| `/ccmagic:work-ticket {ID}` | End-to-end: lookup → classify (Quick Fix / Complex / Debug) → branch → implement → review → PR |
| `/ccmagic:review-ticket [ID]` | Code review grounded in the ticket's stated scope and acceptance criteria. Adds explicit in-scope / out-of-scope / missing-from-ticket section |
| `/ccmagic:finish-ticket [--qa]` | Sanity-check PR → merge → close ticket with summary comment |
| `/ccmagic:auto-ticket [ID]` | **Autonomous** end-to-end driver — runs work → review → pr-feedback (looped) → finish with no human in the loop, and either merges or parks the ticket for a human. See [Autonomous mode](#autonomous-mode) |

All four auto-detect the tracker (Linear MCP → GitHub CLI → Atlassian/JIRA MCP) or honor `tracker:` in `.claude/ccmagic.local.md`.

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

### Working a ticket fully autonomously

```
/ccmagic:auto-ticket ENG-123     # Runs the whole cycle unattended:
                                 # work → review → pr-feedback (looped) → finish.
                                 # Merges if clean + CI green; otherwise parks the
                                 # ticket for a human with a clear note. Never hangs.
```

See [Autonomous mode](#autonomous-mode) for how it decides between merge and park.

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

## Autonomous mode

ccmagic's ticket lifecycle can run **fully unattended** — from Claude Code on your laptop, or headless from a Linear-triggered worker (e.g. Cyrus in Docker). `/ccmagic:auto-ticket {ID}` is the orchestrator; the five lifecycle skills it calls (`work-ticket`, `review-ticket`, `pr-feedback`, `finish-ticket`, `push`) each gained an **opt-in, additive** autonomous path.

### The flow

```
auto-ticket {ID}
  → work-ticket      implement, self-review, open PR
  → review-ticket    scope-drift + code review; fix CRITICAL findings, re-review
  → pr-feedback loop  apply fixes · reply · file follow-ups · push · validate
                      · wait for CI + bot reviews · recompute "clean"   (× up to max_feedback_passes)
  → finish-ticket    merge gate: mergeable + CI green + no unaddressed change-requests
  → summary          posted to the PR and the ticket
```

### Merge, or park — never guess, never stall

For solo-dev projects, **auto-merge with no human in the loop is intended**. The safety property is *not* "avoid merging" — it's that when the work is genuinely uncertain or needs a human decision, the run **parks** the ticket instead of guessing or stalling:

- it does **not** merge,
- it moves the ticket to your configured `needs_human_state` (or applies `needs_human_label` if that state doesn't exist — always the case on GitHub Issues),
- it posts a comment on the PR and the ticket saying exactly what it's waiting on, and
- it exits cleanly.

Every autonomous run ends in exactly one of two states: **merged**, or **parked-needs-human (with a reason)**. There is no silent hang.

### Turning it on

`/ccmagic:auto-ticket` always runs autonomously. To make the individual lifecycle skills default to autonomous when invoked directly, set config (or pass `--autonomous` per call):

```yaml
# .claude/ccmagic.local.md
autonomous: true               # default the lifecycle skills to autonomous
needs_human_state: Blocked     # where parked tickets go (falls back to the label below)
needs_human_label: needs-human # applied when the state doesn't exist / on GitHub
max_feedback_passes: 3         # cap on the pr-feedback loop before parking
# Other autonomous loop bounds (skill defaults shown — set only to override):
# max_review_fix_passes: 2     # ticket-review fix loop
# max_validate_attempts: 2     # local /ccmagic:validate fix attempts
# ci_timeout_minutes: 30       # how long to wait for CI before parking on timeout
# ci_poll_interval_seconds: 60 # how often to poll CI status
```

**Config precedence:** each key resolves highest-first — an explicit arg / grounding-block value → the project file `.claude/ccmagic.local.md` → the user file `~/.claude/ccmagic.local.md` → the built-in skill default. Put personal defaults (e.g. a longer `ci_timeout_minutes`) in the user file once and override them per-repo in the project file.

The autonomous signal is checked in priority order: **`--autonomous` arg → `autonomous: true` in the orchestrator's grounding block → `autonomous:` in `ccmagic.local.md` (project, then user)**. Absent all three, every skill runs its unchanged interactive path. Each autonomous sub-skill ends with a machine-readable status handshake (`clean | fixable-findings | needs-human | done`) that the orchestrator parses to decide the next step; the shared contract lives in `skills/auto-ticket/autonomous-contract.md`.

### Per-step subagents and models

By default `auto-ticket` runs each lifecycle step in its own **forked subagent** on a best-fit **model** — strong models where judgment matters, light ones for mechanical steps — which keeps the orchestrator's context lean on long unattended runs and puts the right model on each step:

| Step | Default model |
|---|---|
| work-ticket / review-ticket | `opus` |
| pr-feedback / finish-ticket / validate | `sonnet` |
| push | `haiku` |

Each step always runs in its own subagent — override any step's model with `model_<step>` (e.g. `model_pr_feedback: opus`) (the agent file `agents/auto-<step>.md` is the authoritative model source).

### Headless / prompt-relay (Cyrus)

`auto-ticket` also runs inside headless harnesses that inject the ticket into the prompt and relay the session's output back to the tracker — with no tracker MCP in that environment at all. No tracker-MCP config is needed for this: detection is automatic (content-presence, zero config keys), and every Linear write collapses into one consolidated final summary (or parked note) relayed back as a comment. The GitHub/PR half of the cycle is unaffected — `gh` still drives the branch, PR, and merge. See `docs/cyrus-deployment.md` for a full deployment walkthrough, prerequisites, and the required prompt template.

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

The tracker-aware skills (`work-ticket`, `finish-ticket`, `review-ticket`, `auto-ticket`) auto-detect, or honor a pinned `tracker:` in `.claude/ccmagic.local.md`. Multi-tracker projects are supported — set `tracker: auto` and let each invocation pick.

Linear is reachable over two transports: its MCP server (default, above), or **prompt-relay** for headless harnesses with no Linear MCP in the environment — see [Headless / prompt-relay (Cyrus)](#headless--prompt-relay-cyrus).

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
├── agents/
│   └── auto-*.md              # per-step wrapper agents for auto-ticket
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
