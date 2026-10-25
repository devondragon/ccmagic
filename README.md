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

27 skills organized by purpose:

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
| `/ccmagic:review [branch\|full\|PR#] [--quick\|--deep] [--fix]` | Adaptive code review — auto-routes QUICK (inline checklist) vs DEEP (4 core agents + specialists + Codex CLI + MCP + verification). Biased toward depth. Read-only: reports findings and changes nothing unless you pass `--fix`, which edits the working tree only and never commits or pushes. Follows the repository's `REVIEW.md` (read from the merge base) and tags findings on lines the change did not touch as pre-existing, which never fail the review on their own. |
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
| `/ccmagic:propose <idea \| TICKET-ID \| document>` | Break an idea, a ticket, or a document such as a BRD into shippable increments. Reads the repository (on an OpenSpec repo, the current specs and the active changes), asks only what the code cannot answer, one question at a time, and stops for you to approve the split. With OpenSpec, writes each change folder under `openspec/changes/`, runs `openspec validate --strict`, `ccm-propose-check`, and, when the Reeve CLI is available, `reeve openspec render --grade`, then opens one PR per change after a second stop; it never merges. Without OpenSpec, drafts tickets in the form Reeve's intake grades well and, after you confirm, creates them in Linear's Backlog with blocking relations. For a document, records which of its requirements each change or ticket covers and lists the ones nothing covers |
| `/ccmagic:spec-polish <change> [--max-rounds N]` | Review an OpenSpec change in rounds before Reeve plans it. Each round a fresh read-only reviewer reads the change against the repository and lists every problem it finds; you accept or reject each finding and the session applies the accepted ones; `openspec validate --strict`, `ccm-propose-check`, and `reeve openspec render --grade` must pass after each round. It stops after two rounds in a row with nothing accepted, writes the polish record `openspec/changes/<change>/.reeve.yml` (rounds, clean rounds, files hash, rubric hash) that Reeve reads at planning, checks that Reeve reads it as polished, and commits after a final stop; it never merges. Run it on the proposal branch, before the change reaches the default branch |

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

Any other ticket, on a repository whose base branch has `openspec/specs/<capability>/spec.md`, carries its own spec delta when it changes specified behavior (RV-100). After implementing, `work-ticket` decides whether a requirement or scenario no longer holds or new observable behavior went unspecified; if so it writes `openspec/changes/<ticket>-<slug>/` (a `proposal.md` and the delta specs), checks it with `ccm-spec-delta`, runs `openspec archive` and strict validation, and commits the archived result with the code, so one PR carries both. It never creates or retires a capability, and parks when an active change already names the same requirement. The PR body gets a `## OpenSpec` section, the handshake a `spec_delta:` line, and the run record a `"spec_delta"` key (`"none"` or the archive folder's path). `review-ticket` reports a missing or wrong delta as a fixable finding, and `finish-ticket` runs `ccm-spec-delta scope` before the merge or hand-off. On a repository without `openspec/specs/` nothing changes.

The archive ticket of a Reeve requirements approval (RV-136) is the exception. Its description has the step line ``Run `openspec archive <change> --yes` at the repository root.``, and when `ccm-spec-delta approval` finds that line naming a change active at the base tip, `work-ticket` skips the spec delta: it runs `openspec archive <change> --yes` and strict validation, checks with `ccm-openspec-scope --approval` that the branch carries only the archive with every task still unchecked (Reeve's gate compares the archived folder with the change at the base tip), and reports the archive folder as `spec_delta`, which the run record carries with no `openspec` key. `review-ticket` and `finish-ticket` run the same check in place of `ccm-spec-delta scope`. A description that mentions `openspec archive` in any other form keeps the plain-ticket path.

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
# visual_checklist: on        # off drops unchecked visual criteria instead of listing them
```

**Config precedence:** each key resolves highest-first — an explicit arg / grounding-block value → the project file `.claude/ccmagic.local.md` → the user file `~/.claude/ccmagic.local.md` → the built-in skill default. Put personal defaults (e.g. a longer `ci_timeout_minutes`) in the user file once and override them per-repo in the project file.

The autonomous signal is checked in priority order: **`--autonomous` arg → `autonomous: true` in the orchestrator's grounding block → `autonomous:` in `ccmagic.local.md` (project, then user)**. Absent all three, every skill runs its unchanged interactive path. Each autonomous sub-skill ends with a machine-readable status handshake (`clean | fixable-findings | needs-human | done`) that the orchestrator parses to decide the next step; the shared contract lives in `skills/auto-ticket/autonomous-contract.md`.

### Per-step subagents and models

By default `auto-ticket` runs each lifecycle step in its own **forked subagent** on a best-fit **model** — strong models where judgment matters, light ones for mechanical steps — which keeps the orchestrator's context lean on long unattended runs and puts the right model on each step:

| Step | Default model |
|---|---|
| work-ticket (and its visual-fix, review-fix, and validate-fix passes) / review-ticket / visual | `opus` |
| pr-feedback / finish-ticket / validate | `sonnet` |
| push | `haiku` |

Each step always runs in its own subagent — override any step's model with `model_<step>` (e.g. `model_pr_feedback: opus`) (the agent file `agents/auto-<step>.md` is the authoritative model source).

### Visual checks with a UI harness

When a ticket's acceptance criteria ask for a screenshot or name a visible UI state, `auto-ticket` checks them against the running app if the repository has a UI harness, `.ccmagic/harness.compose.yml` (see [docs/harness.md](docs/harness.md)). After the PR opens, Step 2b runs the `auto-visual` step: `bin/ccm-harness` brings the app up for the ticket in Docker, seeds it, and takes one screenshot per criterion in a runner container, the step judges each screenshot, and unmet criteria go to a fix pass on the work step, up to three rounds before the run parks. The run summary's Visual check section lists each judgment; under the harness file's `evidence` setting (by default, on a private repository only) the screenshots are pushed to a `ccmagic-evidence/<ticket>` branch and linked from it. Without a harness, or when it cannot start, the criteria go on the summary's UAT checklist and the run continues.

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
| `REVIEW.md` or `.claude/REVIEW.md` | What matters when reviewing this repository: failure modes, paths to skip, a nit cap, required evidence. Read by review (and so review-ticket and auto-ticket) from the merge base of the change under review. Template: `docs/REVIEW.md.example` |
| `context/knowledge/*.md` | Architecture / stack / conventions knowledge — produced by map-codebase; read by review, codex-review, analyze-impact |

See `docs/ccmagic.local.md.example` for the full config template.

### REVIEW.md

`CLAUDE.md` and `context/conventions.md` say how to write code in a repository; `REVIEW.md` says what matters when reviewing it. `/ccmagic:review` loads `REVIEW.md`, else `.claude/REVIEW.md`, and passes it to every reviewer and verifier. It acts on four sections: `## Failure modes` (what a bad change looks like here; a finding that is one is raised in severity), `## Skip` (globs the reviewer does not read), `## Nit cap` (at most this many Low findings, highest confidence kept), and `## Evidence` (what a finding must show). Any other section is passed through as guidance. Copy `docs/REVIEW.md.example` to start one; this repository's own is `REVIEW.md`.

The review reads the file from the merge base of the change (`git show <merge-base>:REVIEW.md`), not from the checkout. On a PR the checkout is the PR's head, so reading it there would let a PR edit `REVIEW.md` to soften its own review. A change to `REVIEW.md` takes effect for the changes reviewed after it merges, and the report says when the change under review edits it. Without a merge base (no `main`, no git) the checkout's copy is used and the report says so.

Findings on lines the change did not add or modify are tagged pre-existing. They get their own report section, never fail the review or trigger an auto-ticket fix pass on their own (auto-ticket files them as follow-ups, one per systemic group), and the report summary starts with the introduced and pre-existing counts. A pre-existing Critical security finding still blocks, since merging ships it again: the review reports FAIL, and under auto-ticket the review returns `needs-human`, which parks the run with the finding named instead of trying to fix it in the PR.

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
| `ccm-ci-status` | Is CI green for this PR: `green`, `no-ci`, `failed`, `pending`, `not-registered`, `conflicting`, `unreadable`. Falls back to the Actions and commit-status APIs when a fine-grained PAT gets HTTP 403 on check runs. `--watch --wait-key K` waits with a deadline that holds across repeated calls. Checks listed under `ci.ignore` in `.reeve/policy.yml` on the base branch are advisory: reported in `advisory`, never failing or holding the result (RV-74) |
| `ccm-merge-gate` | May this PR merge: open, mergeable, CI green (or no CI), no reviewer whose latest review requests changes |
| `ccm-pr-threads` | A PR's review threads (grouped, with an `open` flag), reviews, and conversation comments; `--since-id H` marks reviewer comments newer than a high-water mark. A thread is handled when resolved, or when the author's last reply carries a `ccm-pr-reply` disposition marker; a `fixed` marker counts only once its commit is verified on the branch and touches the thread's file |
| `ccm-validate` | Do the project's checks pass: runs `format`, `lint`, `types`, `test`, and `build`, one command each from a `validate_<check>` config key or detected from `package.json`, `Makefile`, Gradle, Maven, `go.mod`, `Cargo.toml`, or `pyproject.toml`, and uses each command's exit code as the verdict (`pass`, `fail`, `nothing-to-run`). `--only` runs a subset and `--list` shows the commands without running them. Each check is bounded by `validate_timeout_seconds` (default 540, at most 7200). For checks longer than one 10-minute Bash call, `--start` runs them in a detached process, or `--start --attached` only prepares the run (writing its state with no result, so a `--wait` never reads an earlier run's) and `--attach RUN` then runs its worker in the foreground for a harness background task to own (a sandbox that ends a call's processes kills a detached run), and `--wait [SECONDS]` (default 480) waits for it by its heartbeat, printing the plain result when it finishes or `status: running` with exit 6 while it goes on; `/ccmagic:validate` prepares with `--start --attached` in an ordinary Bash call and runs `--attach` as a background Bash call when `validate_timeout_seconds` is above 540. A Gradle or Maven build (run through `./gradlew` or `./mvnw` when present) supplies `test` and `build` ahead of `package.json` and the `Makefile`, which still supply `format`, `lint`, and `types`. When the root `package.json` declares dependencies, a package under `dependencies` or `devDependencies` is not in `node_modules` (a bare `node_modules` directory does not count), and a check that will run goes through Node (a `package.json` script, or a command with `npm`, `npx`, `pnpm`, `yarn`, `bun`, `bunx`, or `node` as a command word), the first check is preceded by the install its lockfile calls for (`npm ci`, or `pnpm`, `yarn`, or `bun` when that tool is installed), and `--install` runs only that; with no lockfile, a missing tool, or a failed install, no check runs and the status is `environment`. Node only: no other ecosystem's dependencies are installed |
| `ccm-review-route` | Should `/ccmagic:review` run QUICK or DEEP for a branch range, PR, or pasted diff (`--diff-file -`): applies the Step 0.5 size, risk-path, new-type, and error-flow rules and prints the routing line. Also reports specialists gated by `context/review-stats.json` and updates that file with `--record name=N,...`; autonomous runs add `--local`, which records in the git common directory instead so the working tree stays clean |
| `ccm-review-guide` | `load`: the repository's `REVIEW.md` (or `.claude/REVIEW.md`) read from the merge base of `--base` (default `main`) and HEAD, or from the checkout without one, or `--file -` for a pasted copy, with its `## Failure modes`, `## Skip`, `## Nit cap`, and `## Evidence` sections parsed and `checkout_differs` set when the change edits it. `skip PATH...`: which paths its `## Skip` globs match. `locate LOCATION...`: whether each `file:line` finding is on a line the diff (`--range`, default `main...HEAD`, `--pr N`, or `--diff-file -`) added or modified, or is pre-existing |
| `ccm-post-review` | Posts a `/ccmagic:review-ticket` report to the PR only if it starts with the `# Ticket-Grounded Review: {TICKET-ID}` heading and ends with the fenced `status`/`head`/`reason`/`follow_ups` handshake, with `head` the checkout's full HEAD SHA; otherwise exits 1 listing the problems. Exits 3 without posting when HEAD is unreadable or the post fails |
| `ccm-external-review` | Runs the Codex and Gemini review passes in parallel under `timeout --kill-after=30 300` and reports each pass as `findings`, `empty`, `timed-out`, `auth-failed`, `unavailable`, or `failed`, with its output file. Used by `/ccmagic:review` Step 3.5 and `/ccmagic:codex-review` |
| `ccm-doctor` | The `/ccmagic:doctor` checks (project setup, config, plugin hooks and scripts, git, branch, skills, and `ccm-validate --list`) as JSON lines `{level, area, message, fix}`; exits 1 if any line is `FAIL` |
| `ccm-spec-block` | Is this ticket a Reeve spec ticket: reads the description on stdin and prints the `repo`, `change`, `section`, and `tasks` of a well-formed `<!-- reeve:spec v1 -->` block, or `null` with the reason (a prose mention of `reeve:spec`, a missing delimiter, or bad metadata is an ordinary ticket); exits 0 either way |
| `ccm-openspec-scope` | Does a Reeve spec ticket's branch keep to its OpenSpec section or archive: applies the file rules of Reeve's `openspec` merge gate check against the base branch tip (`outside-section`, `tasks-text`, `tasks-unchecked`, `not-moved`, `folder-content`, `outside-archive`, and the rest) and names the first that fails; `--worktree` includes uncommitted changes and new files under `openspec/`, `--precheck` checks the checkout before any work, and `--approval` checks a requirements approval's archive ticket by the archive rules without `tasks-unchecked` and reports the archive folder (RV-136) |
| `ccm-openspec-version` | Is the installed OpenSpec CLI one the format rules were checked on: prints `{version, tested, status}` with status `ok`, `newer` (a later 1.x, usable with a warning), `too-old`, `unsupported`, or `missing`, and exits 0 only for `ok` and `newer`. The tested version lives in this script alone. |
| `ccm-finish-guard` | May an `/auto-ticket` run reach `finish-ticket`: reads the run's step history (the finish grounding block's `steps:` section) on stdin and passes only when the latest validate is `done`, the latest review `clean`, and no work-ticket or pr-feedback step ran after that validate; a missing or malformed history fails |
| `ccm-baseline-check` | Does an OpenSpec baseline hold up: every spec requirement and scenario has its line in `docs/openspec-baseline.md`, every `path:line` citation resolves, every cited test exists, names are unique and free of characters Reeve rewrites, no em or en dash, and nothing outside `openspec/` and the evidence file changed since the merge base with the default branch; `--stale` adds each citation whose lines a commit after the baseline commit touched. Used by `/ccmagic:spec-baseline` |
| `ccm-spec-delta` | A plain ticket's spec delta (RV-100): `applies` (does the base have specs), `name` (the change name from the ticket and title, free of collisions), `collision` (requirements an active change also names), `check` (the folder before the archive: only `proposal.md` and existing capabilities' delta specs, names that exist, no dash or email address), `scope` (the branch after the archive, by the file rules of Reeve's gate, plus a replay of `openspec archive` on the merge base that the main specs must match byte for byte), `reopen` (undo the archive for a fix pass), and `approval` (is the ticket, its description on stdin, a Reeve requirements approval's archive ticket, RV-136) |
| `ccm-propose-check` | Do the change folders a `/ccmagic:propose` run wrote meet Reeve's planner and strict OpenSpec: only the new folders changed, each name is kebab-case, free of Reeve's refused words, and new (no active change or archive folder of that name), `proposal.md`, `tasks.md`, and `.openspec.yaml` exist with only known keys, `tasks.md` parses as Reeve parses it with every box empty and at most three sections, a delta for a capability with no spec has `## Purpose`, every MODIFIED, REMOVED, and RENAMED FROM name is in the current spec, and no em or en dash or written email address; `--probe-reeve` says whether the Reeve CLI and its config are there for render and `--grade`, without printing a secret |
| `ccm-spec-polish` | The polish record's files hash (Reeve's `polishFilesHash`: git blob SHAs of `tasks.md`, `proposal.md`, `.openspec.yaml`, and `specs/<capability>/spec.md`), writing the record, checking it as Reeve does (`none`, `malformed`, `unconverged`, `stale`, `polished`), and a preflight that refuses a change already on the default branch. Used by `/ccmagic:spec-polish` |
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
