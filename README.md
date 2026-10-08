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

25 skills organized by purpose:

### Tracker workflow

| Skill | Purpose |
|---|---|
| `/ccmagic:work-ticket {ID}` | End-to-end: lookup → classify (Quick Fix / Complex / Debug) → branch → implement → review → PR |
| `/ccmagic:review-ticket [ID]` | Code review grounded in the ticket's stated scope and acceptance criteria. Adds explicit in-scope / out-of-scope / missing-from-ticket section |
| `/ccmagic:finish-ticket [--qa]` | Sanity-check PR → merge (or hand off with `merge_owner: reeve`) → close ticket with summary comment |
| `/ccmagic:auto-ticket [ID]` | **Autonomous** end-to-end driver — runs work → review → pr-feedback (looped) → finish with no human in the loop, and either merges or parks the ticket for a human. See [Autonomous mode](#autonomous-mode) |

All four auto-detect the tracker (Linear MCP → GitHub CLI → Atlassian/JIRA MCP) or honor `tracker:` in `.claude/ccmagic.local.md`.

### Code review & quality

| Skill | Purpose |
|---|---|
| `/ccmagic:review [branch\|full\|PR#] [--quick\|--deep] [--fix]` | Adaptive code review — auto-routes QUICK (inline checklist) vs DEEP (4 core agents + specialists + Codex CLI + MCP + verification). Biased toward depth. Read-only: reports findings and changes nothing unless you pass `--fix`, which edits the working tree only and never commits or pushes. |
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
| `/ccmagic:spec-baseline [--capability <name>] [--check]` | OpenSpec baseline of current behavior: proposes a capability map (you confirm it), extracts behavior with read-only agents, writes `openspec/specs/<capability>/spec.md` and the evidence file `docs/openspec-baseline.md`, checks both, and opens a PR after your review; `--check` reports citations gone stale since the baseline. Writes only under `openspec/` and the evidence file |

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
/ccmagic:finish-ticket           # Merge (or hand off with merge_owner: reeve) + close ticket
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
  → pr-feedback loop  apply fixes · reply · note follow-ups · push · validate
                      · wait for CI + bot reviews · recompute "clean"   (× up to max_feedback_passes)
                      · re-review the pushed head when the pass pushed
  → finish-ticket    merge gate: mergeable + CI green + no unaddressed change-requests
  → summary          follow-ups filed or listed; posted to the PR and the ticket
```

The orchestrator is the only part of the run that reads or writes the tracker: it fetches the ticket once and passes its content to every step, and it applies the state changes (In Progress, In Review, Done or the hand-off state), links the PR, and files follow-ups that the steps report in their handshakes. Every follow-up a step reports is either filed or listed in the summary with the reason it wasn't.

The orchestrator never edits code. When the review returns fixable findings, or local validation fails, it sends them back to the work step's agent (`auto-work`, on opus) as a fix pass: that agent fixes systemic findings as a whole class, checks security fixes against the verifier's inputs, and leaves its changes for the push step to commit and push. Re-reviews post deltas rather than fresh full reports, and the CI wait is a bounded blocking watch (`gh pr checks --watch`), never a sleep loop.

### Merge, or park — never guess, never stall

For solo-dev projects, **auto-merge with no human in the loop is intended**. The safety property is *not* "avoid merging" — it's that when the work is genuinely uncertain or needs a human decision, the run **parks** the ticket instead of guessing or stalling:

- it does **not** merge,
- it moves the ticket to your configured `needs_human_state` (or applies `needs_human_label` if that state doesn't exist — always the case on GitHub Issues),
- it posts a comment on the PR and the ticket saying exactly what it's waiting on, and
- it exits cleanly.

Every autonomous run ends in exactly one of three states: **merged**, **handed-off** (only with `merge_owner: reeve`), or **parked-needs-human** (with a reason). There is no silent hang.

### Handing off to an external merge gate

A repo whose merges belong to an external gate sets `merge_owner: reeve`. The run implements, reviews, and addresses feedback as usual, then `finish-ticket` runs its merge gate as a preflight and hands the open PR off instead of merging, and the orchestrator updates the ticket: on Linear/JIRA it moves the ticket to `merge_handoff_state` (default `Awaiting Merge`); on GitHub Issues, which have no custom states, it applies the `awaiting-merge` label instead and leaves the issue open; under the prompt-relay transport it reports the requested state in the handshake rather than transitioning it directly. Every run summary now ends with a fenced JSON run record that such a gate can parse. The record is at `version: 2`, which names the `repo`, the `pr`, and the PR's `head_sha` beside the `ticket`, and the review report's handshake carries a `head:` line with the commit the review read, so the gate can tie both to the PR head it would merge. A push in the PR-feedback loop (a feedback fix or a validate fix) after the last clean review moves the PR head, so the run re-reviews the pushed head before finishing, within the existing `max_feedback_passes` and `max_review_fix_passes` limits, and parks rather than finish on a stale review. When the run can't read `repo` or the PR head, it writes a `version: 1` record instead, with a one-line `fallback_reason` naming the failed command and its first error line, and says so in its final message.

A ticket that Reeve generated from an OpenSpec change carries a `<!-- reeve:spec v1 -->` block in its description. On such a ticket only, the run adds a `spec:` section to the grounding block, checks the checkout first (`ccm-openspec-scope --precheck`), implements only that section's tasks from `openspec/changes/<change>/tasks.md` and ticks only their boxes (or, for the archive ticket, runs `openspec archive` (1.14.1 or a newer 1.x release, checked by `ccm-openspec-version`) by a fixed procedure and restores the worktree on any failure), checks the branch with `ccm-openspec-scope` before the first push and again before the merge or hand-off, reports the ticked task ids in a `tasks_done:` handshake line, and adds `"openspec": {"change", "section", "tasks_done"}` to the run record, which stays at `version: 2`. Every other ticket runs exactly as before.

### Turning it on

`/ccmagic:auto-ticket` always runs autonomously. To make the individual lifecycle skills default to autonomous when invoked directly, set config (or pass `--autonomous` per call):

```yaml
# .claude/ccmagic.local.md
autonomous: true               # default the lifecycle skills to autonomous
needs_human_state: Blocked     # where parked tickets go (falls back to the label below)
needs_human_label: needs-human # applied when the state doesn't exist / on GitHub
# merge_owner: reeve           # hand off to an external merge gate instead of merging
# merge_handoff_state: Awaiting Merge # tracker state a handed-off ticket moves to
max_feedback_passes: 3         # cap on the pr-feedback loop before parking
# Other autonomous loop bounds (skill defaults shown — set only to override):
# max_review_fix_passes: 3     # ticket-review fix loop
# max_validate_attempts: 2     # local /ccmagic:validate fix attempts
# ci_timeout_minutes: 30       # how long to wait for CI before parking on timeout
# ci_poll_interval_seconds: 60 # interval for the gh pr checks --watch CI wait
```

**Config precedence:** each key resolves highest-first — an explicit arg / grounding-block value → the project file `.claude/ccmagic.local.md` → the user file `~/.claude/ccmagic.local.md` → the built-in skill default. Put personal defaults (e.g. a longer `ci_timeout_minutes`) in the user file once and override them per-repo in the project file.

The autonomous signal is checked in priority order: **`--autonomous` arg → `autonomous: true` in the orchestrator's grounding block → `autonomous:` in `ccmagic.local.md` (project, then user)**. Absent all three, every skill runs its unchanged interactive path. Each autonomous sub-skill ends with a machine-readable status handshake (`clean | fixable-findings | needs-human | done`) that the orchestrator parses to decide the next step; the shared contract lives in `skills/auto-ticket/autonomous-contract.md`.

### Per-step subagents and models

By default `auto-ticket` runs each lifecycle step in its own **forked subagent** on a best-fit **model** — strong models where judgment matters, light ones for mechanical steps — which keeps the orchestrator's context lean on long unattended runs and puts the right model on each step:

| Step | Default model |
|---|---|
| work-ticket (and its review-fix and validate-fix passes) / review-ticket | `opus` |
| pr-feedback / finish-ticket / validate | `sonnet` |
| push | `haiku` |

Each step always runs in its own subagent — override any step's model with `model_<step>` (e.g. `model_pr_feedback: opus`) (the agent file `agents/auto-<step>.md` is the authoritative model source).

### Headless runners (Cyrus)

`auto-ticket` runs unattended inside headless harnesses like [Cyrus](https://github.com/cyrusagents/cyrus), which assigns a Linear issue, spins up a container with a fresh worktree, and runs the session. Cyrus provides the hosted Linear MCP, so runs go over the **`mcp` transport by default** — the ticket lifecycle reads and writes Linear directly via `mcp__linear__*`. The **prompt-relay transport** is the automatic fallback: for the brief window at session start before Cyrus's non-blocking MCP finishes connecting, and for any harness that injects the ticket into the prompt with no tracker MCP at all.

- **Transport selection is automatic** — by whether the Linear MCP is available, zero config keys.
- **One consolidated summary** (or parked note) reaches the tracker per run; the GitHub/PR half of the cycle is unaffected — `gh` still drives the branch, PR, and merge.

See `docs/cyrus-deployment.md` for the full deployment walkthrough, prerequisites, the build-time patches, and the required prompt template.

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

Linear is reachable over two transports: its MCP server (the default — including inside Cyrus, above), or **prompt-relay**, the automatic fallback for the session-start connect window and for headless harnesses that inject the ticket with no Linear MCP at all — see [Headless runners (Cyrus)](#headless-runners-cyrus).

## Hooks and scripts

Rules that have one right answer are enforced in code, not left to the skill text.

**Scripts** (`bin/`, on the Bash `PATH` while the plugin is enabled; skills call them by path). Each prints JSON and exits non-zero when the answer is "no":

| Script | Answers |
|---|---|
| `ccm-context` | Current branch, ticket ID parsed from it, open PR, worktree or primary checkout, base branch, and the resolved `ccmagic.local.md` config (project over user over defaults) |
| `ccm-ci-status` | Is CI green for this PR: `green`, `no-ci`, `failed`, `pending`, `not-registered`, `unreadable`. Falls back to the Actions and commit-status APIs when a fine-grained PAT gets HTTP 403 on check runs. `--watch --wait-key K` waits with a deadline that holds across repeated calls |
| `ccm-merge-gate` | May this PR merge: open, mergeable, CI green (or no CI), no reviewer whose latest review requests changes |
| `ccm-pr-threads` | A PR's review threads (grouped, with an `open` flag), reviews, and conversation comments; `--since-id H` marks reviewer comments newer than a high-water mark. A thread is handled when resolved, or when the author's last reply carries a `ccm-pr-reply` disposition marker; a `fixed` marker counts only once its commit is verified on the branch and touches the thread's file |
| `ccm-validate` | Do the project's checks pass: runs `format`, `lint`, `types`, `test`, and `build`, one command each from a `validate_<check>` config key or detected from `package.json`, `Makefile`, Gradle, Maven, `go.mod`, `Cargo.toml`, or `pyproject.toml`, and uses each command's exit code as the verdict (`pass`, `fail`, `nothing-to-run`). `--only` runs a subset and `--list` shows the commands without running them. Each check is bounded by `validate_timeout_seconds` (default 540, at most 7200). For checks longer than one 10-minute Bash call, `--start` runs them in a detached process, or `--start --attached` runs that worker in the foreground for a harness background task to own (a sandbox that ends a call's processes kills a detached run), and `--wait [SECONDS]` (default 480) waits for it by its heartbeat, printing the plain result when it finishes or `status: running` with exit 6 while it goes on; `/ccmagic:validate` uses `--start --attached` as a background Bash call when `validate_timeout_seconds` is above 540. A Gradle or Maven build (run through `./gradlew` or `./mvnw` when present) supplies `test` and `build` ahead of `package.json` and the `Makefile`, which still supply `format`, `lint`, and `types`. When the root `package.json` declares dependencies, a package under `dependencies` or `devDependencies` is not in `node_modules` (a bare `node_modules` directory does not count), and a check that will run goes through Node (a `package.json` script, or a command with `npm`, `npx`, `pnpm`, `yarn`, `bun`, `bunx`, or `node` as a command word), the first check is preceded by the install its lockfile calls for (`npm ci`, or `pnpm`, `yarn`, or `bun` when that tool is installed), and `--install` runs only that; with no lockfile, a missing tool, or a failed install, no check runs and the status is `environment`. Node only: no other ecosystem's dependencies are installed |
| `ccm-review-route` | Should `/ccmagic:review` run QUICK or DEEP for a branch range, PR, or pasted diff (`--diff-file -`): applies the Step 0.5 size, risk-path, new-type, and error-flow rules and prints the routing line. Also reports specialists gated by `context/review-stats.json` and updates that file with `--record name=N,...` |
| `ccm-post-review` | Posts a `/ccmagic:review-ticket` report to the PR only if it starts with the `# Ticket-Grounded Review: {TICKET-ID}` heading and ends with the fenced `status`/`head`/`reason`/`follow_ups` handshake, with `head` the checkout's full HEAD SHA; otherwise exits 1 listing the problems. Exits 3 without posting when HEAD is unreadable or the post fails |
| `ccm-external-review` | Runs the Codex and Gemini review passes in parallel under `timeout --kill-after=30 300` and reports each pass as `findings`, `empty`, `timed-out`, `auth-failed`, `unavailable`, or `failed`, with its output file. Used by `/ccmagic:review` Step 3.5 and `/ccmagic:codex-review` |
| `ccm-doctor` | The `/ccmagic:doctor` checks (project setup, config, plugin hooks and scripts, git, branch, skills, and `ccm-validate --list`) as JSON lines `{level, area, message, fix}`; exits 1 if any line is `FAIL` |
| `ccm-spec-block` | Is this ticket a Reeve spec ticket: reads the description on stdin and prints the `repo`, `change`, `section`, and `tasks` of a well-formed `<!-- reeve:spec v1 -->` block, or `null` with the reason (a prose mention of `reeve:spec`, a missing delimiter, or bad metadata is an ordinary ticket); exits 0 either way |
| `ccm-openspec-scope` | Does a Reeve spec ticket's branch keep to its OpenSpec section or archive: applies the file rules of Reeve's `openspec` merge gate check against the base branch tip (`outside-section`, `tasks-text`, `tasks-unchecked`, `not-moved`, `folder-content`, `outside-archive`, and the rest) and names the first that fails; `--worktree` includes uncommitted changes and new files under `openspec/`, and `--precheck` checks the checkout before any work |
| `ccm-openspec-version` | Is the installed OpenSpec CLI one the format rules were checked on: prints `{version, tested, status}` with status `ok`, `newer` (a later 1.x, usable with a warning), `too-old`, `unsupported`, or `missing`, and exits 0 only for `ok` and `newer`. The tested version lives in this script alone. |
| `ccm-finish-guard` | May an `/auto-ticket` run reach `finish-ticket`: reads the run's step history (the finish grounding block's `steps:` section) on stdin and passes only when the latest validate is `done`, the latest review `clean`, and no work-ticket or pr-feedback step ran after that validate; a missing or malformed history fails |
| `ccm-baseline-check` | Does an OpenSpec baseline hold up: every spec requirement and scenario has its line in `docs/openspec-baseline.md`, every `path:line` citation resolves, every cited test exists, names are unique and free of characters Reeve rewrites, no em or en dash, and nothing outside `openspec/` and the evidence file changed since the merge base with the default branch; `--stale` adds each citation whose lines a commit after the baseline commit touched. Used by `/ccmagic:spec-baseline` |
| `ccm-pr-reply` | Reply to a review thread with a disposition (`fixed --commit`, `declined`, `answered`, `deferred --ticket`); appends the marker, refuses an unpushed fix commit, and resolves the thread for `fixed` |

**Hooks** (`hooks/hooks.json`):

- `PreToolUse` guard (`hooks/pre-tool-use-guard.sh`). "Autonomous" means a `ccmagic:auto-*` agent or `autonomous: true`.

  | Rule | Autonomous | Interactive |
  |---|---|---|
  | `gh pr merge` while `ccm-merge-gate` fails | denied (always denied under `merge_owner: reeve`) | allowed, unless `merge_guard: on`; then denied until the user chooses to merge anyway (`CCMAGIC_MERGE_OVERRIDE=1`) |
  | Force push (`--force`, `-f`, `--force-with-lease`, `+refspec`) | denied | denied to `main`, `master`, `develop`, `release/*`, or the default branch; allowed to other branches |
  | Staging or committing a secret-shaped file (`.env`, private keys, credential files) | denied | denied until the user confirms (`CCMAGIC_ALLOW_SENSITIVE=1`); files under `## Always Include` in `context/commit-preferences.md` pass |
  | Commit subject not in conventional-commit format | denied, with the expected format | allowed; the PostToolUse hook warns |

- `PreToolUse` finish guard (`hooks/pre-tool-use-finish-guard.sh`, on `Agent` and `Task` calls): a call that starts the `ccmagic:auto-finish` step is denied unless `ccm-finish-guard` passes on the `steps:` section of its grounding block, so an `/auto-ticket` run whose latest validate returned `needs-human` can't merge or hand off. The denial tells the orchestrator to park. Every other call passes untouched.
- `SubagentStop` handshake check (`hooks/subagent-stop-handshake.sh`): a `ccmagic:auto-*` step agent whose final message doesn't end with a valid status handshake is sent back once to add it. The send-back message also covers the `SubagentHandback` tool: its message must carry the full report ending with the handshake. Its handshake validation lives in `hooks/lib-handshake.sh`, which `ccm-post-review` shares.
- `SubagentStop` orchestrator check (`hooks/subagent-stop-orchestrator.sh`): the forked `/auto-ticket` orchestrator is sent back once when it ran no step agent at all and still edited files, committed, pushed, opened a PR, or merged itself, and ended without a run summary or the prompt-relay final-message block. It is told to continue from Step 0, or to park when it already merged. Every other subagent passes untouched.
- `PostToolUse` commit-format check (`hooks/post-tool-use-commit.sh`): warns when a commit subject doesn't match the conventional-commit format in `.claude/CLAUDE.md`. It never rejects, so it's safe on repos with non-conventional history.

Tests: `tests/run.sh` (plain bash, with a `gh` stub fed recorded API output). CI runs it and shellcheck on every PR.

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
├── bin/
│   └── ccm-*                  # deterministic helpers the skills call
├── hooks/
│   ├── hooks.json
│   ├── pre-tool-use-guard.sh
│   ├── pre-tool-use-finish-guard.sh
│   ├── lib-commit.sh
│   ├── subagent-stop-handshake.sh
│   ├── subagent-stop-orchestrator.sh
│   └── post-tool-use-commit.sh
├── tests/
│   └── run.sh                 # tests for bin/ and hooks/
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
