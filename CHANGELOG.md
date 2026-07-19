# Changelog

All notable changes to ccmagic are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.4.0] — 2026-07

Field-run hardening from two real-world `/ccmagic:auto-ticket` retrospectives — one run stalled silently at the CI wait, the other merged safely but only just, because its review-fix loop reasoned about instances of a bug rather than the defect class. See `docs/auto-ticket-field-hardening-design.md` for the full incident analysis.

### Fixed

- **The Step 4c CI wait** (`skills/auto-ticket/SKILL.md`, `skills/auto-ticket/autonomous-contract.md` §5) — previously specced as a sleep-based poll loop ("poll every `ci_poll_interval_seconds`"), which no orchestrator toolset could actually execute and produced a field-observed silent stall. Replaced with a bounded blocking watch: `gh pr checks --watch` invoked as a single Bash call at the maximum tool timeout, budgeted by invocation count rather than shell state (`CYCLES = ceil(ci_timeout_minutes / 10)`, since nothing persists across Bash calls), plus an evidence-based no-checks guard: an empty check set counts as "no CI configured" only when the repo has no workflow files and no required status checks; CI that exists but hasn't registered its checks yet is waited on via the head SHA's workflow run (`gh run watch`) or parked — never treated as a vacuous green. `finish-ticket`'s merge gate applies the same rule to an empty `statusCheckRollup` and still re-verifies CI status before merging, so it remains the backstop if the wait is ever skipped or misconfigured.
- **`finish-ticket` branch cleanup in linked worktrees** (`skills/finish-ticket/SKILL.md`) — `--delete-branch` was failing noisily on a worktree-per-ticket checkout. Linked-worktree detection now compares `git rev-parse --path-format=absolute --git-dir` against `--git-common-dir`; in a worktree, the merge runs without `--delete-branch`, the remote branch is deleted best-effort only once the merge is confirmed `MERGED`, and the local worktree is left in place without error — a normal solo-dev setup, not a failure. A second new error-handling path covers conflict resolution hitting "is already used by worktree at": re-run the conflict-resolution commands from that worktree path instead of failing.

### Added

- **Systemic-finding enumeration** (`skills/review/finding-schema.md`, `skills/review/agent-instructions.md`, `skills/review-ticket/SKILL.md`, `skills/auto-ticket/SKILL.md`) — an optional `systemic:` field on review findings for when an issue is one instance of a repeatable pattern; the reporting agent states the defect *class* and enumerates every instance across all reference mechanisms that could carry it (template attributes, ES-module imports, CSS `@import`/`url()`, manifests, config files, etc.), not just the mechanism of the first hit. The scoped all-clear rule is now universal across all review agents — an unscoped "no other instances" claim must be downgraded to name its search scope, since an unscoped claim is more dangerous than silence in a loop that acts on verdicts. `auto-ticket`'s Step 3 fix loop fixes a `systemic`-tagged finding as a whole class (fix every enumerated instance, re-run the enumeration search, then re-review) instead of point-fixing the reported line.
- **`work-ticket` invariant self-check and risk-ordered scoping** (`skills/work-ticket/SKILL.md`) — scope validation now requires identifying any invariant the change's safety depends on (especially one the change itself asserts in comments, docs, or the PR body) and verifying it holds repo-wide before shipping; a violated invariant is a gap to close, or `needs-human` in autonomous mode. Complex Feature scoping guidance now also prefers shipping the lower-risk slice first and requires flagging any new latent-failure mode the retained slice introduces (aggressive caching, destructive migrations, auth changes) explicitly in the PR body.
- **Delta re-reviews** (`skills/auto-ticket/autonomous-contract.md` §2, `skills/review-ticket/SKILL.md`) — the grounding block gains an optional `review_pass: {n}` field, set when `auto-ticket` re-invokes `review-ticket` from the Step 3 fix loop, plus a `previous_findings:` section listing what was just fixed. A fresh review subagent has no memory of the prior pass, so on `review_pass` ≥ 2 it verifies each prior finding fixed/not-fixed as a one-liner and posts a **delta report** — net-new findings in full, the prior report referenced rather than repeated — instead of a full fresh review. Review passes post their report as a PR comment via `gh pr comment` when a PR exists, so each pass leaves an artifact the next one can reference.
- **Idempotent run summary** (`skills/auto-ticket/SKILL.md` Step 6) — the run-summary template gains a `**Run:** {run_id}` line, and posting is skipped if a summary comment carrying that `run_id` already exists on the PR, so a same-run re-execution of Step 6 never double-posts.

### Changed

- All six `agents/auto-*.md` now declare explicit `tools:` allowlists instead of relying on prose alone to describe their capability boundary. Notably, `auto-review` structurally loses `Edit` — review can no longer mutate code, only report on it.
- `max_review_fix_passes` default raised **2 → 3** (`skills/auto-ticket/autonomous-contract.md` §5, `skills/auto-ticket/SKILL.md`, `docs/ccmagic.local.md.example`) — deliberate headroom so a systemic defect class is never left half-fixed for lack of a remaining pass.

## [3.3.0] — 2026-07

### Added

- **Prompt-relay transport** (`skills/auto-ticket/autonomous-contract.md` §7) — supports headless harnesses (e.g. [Cyrus](https://github.com/cyrusagents/cyrus)) that inject a Linear ticket directly into the prompt with no Linear MCP in the environment. Detection is content-presence — tracker resolves to `linear`, no `mcp__*Linear*__*` tool is present, and ticket content was passed in the invocation/grounding block — zero new config keys, and behavior is unchanged whenever an MCP is present. Under this transport, the contract's tracker-I/O ops branch: `fetch_ticket` reads title + description from the grounding block's `ticket_content:` section instead of calling the MCP; every `set_state` call becomes a no-op — the harness/tracker automation owns the transition, with the non-trivial moves (In Review/Done/needs-human) additionally reported as an intent via the handshake instead of performed directly; tracker writes collapse into a single consolidated final message (delimited by `=== FINAL MESSAGE TO RELAY (reproduce verbatim) ===`) rather than per-step comments; and follow-up tickets, which can't be created without an API, are listed under "Follow-ups to file" for a human to file manually. A park (`needs-human`) skips the state move entirely — that's never treated as a failure. The GitHub/PR half of the cycle (branch, push, PR, CI, merge via `gh`) is unaffected. See `docs/cyrus-deployment.md` for deployment prerequisites and the required prompt template.

### Changed

- **Grounding block** (contract §2) — now carries a `transport: {mcp | prompt-relay}` field on every sub-skill invocation, and under prompt-relay, a fenced `ticket_content:` section (title + description) since there's no MCP to fetch the ticket from.
- **Status handshake** (contract §3) — gains an optional `requested_state:` field, prompt-relay only: a sub-skill that would have transitioned ticket state reports the intended state here instead of performing the transition; the orchestrator folds it into the final summary as a `Requested state: {X}` intent line.
- **`skills/auto-ticket/SKILL.md` Notes** — corrected a stale note that claimed the autonomous cycle was already safe to run unmodified "from Cyrus's Dockerized worker" (which implicitly assumed a Linear MCP that doesn't exist in that container); it now documents the prompt-relay transport as the actual mechanism headless harnesses use, pointing to `docs/cyrus-deployment.md`.

## [3.2.0] — 2026-07

### Added

- **Per-step subagents for `/ccmagic:auto-ticket`** — each lifecycle step (work / review / pr-feedback / validate / finish / push) now runs in its own forked subagent on a best-fit model, keeping the orchestrator's context lean on long unattended runs. New thin wrapper agents live in `agents/auto-*.md`; the lifecycle skills' *logic* is reused unchanged (only three of them have their `model:` line tuned (work/review → `inherit`, push → `haiku`) — see Changed). Each step always runs in its own forked subagent.
- **Per-step model selection** — Balanced defaults (`opus` for work/review, `sonnet` for pr-feedback/finish/validate, `haiku` for push), overridable per repo with `model_<step>` keys. `auto-ticket` itself is now `context: fork`.

### Changed

- **`skills/auto-ticket/SKILL.md`** — now `context: fork`; every step routes through a `run_step` helper (forked-per-step or inline). The handshake contract is unchanged; it now returns across the subagent boundary.
- **Lifecycle-skill default models tuned** (part of the per-step model strategy, which removes the model-clobber risk at the source so per-step models are correct by construction): `work-ticket` and `review-ticket` now use `model: inherit` (scale to the session model instead of a pinned `sonnet`), and `push` now uses `model: haiku`. This also changes **interactive** use of those three skills — e.g. a human running `/ccmagic:push` now gets `haiku`. `pr-feedback`, `finish-ticket`, and `validate` stay `sonnet`.

## [3.1.0] — 2026-07

### Added

- **`/ccmagic:auto-ticket [TICKET-ID]`** — an autonomous end-to-end ticket driver. Given a ticket ID (or the current branch), it runs the full lifecycle unattended — `work-ticket → review-ticket → pr-feedback (looped) → finish-ticket` — invoking each sub-skill in autonomous mode, parsing its status handshake, and owning the single merge-or-park decision. Built for solo-dev projects and headless runners (e.g. Cyrus, Linear-triggered, Dockerized): **auto-merge with no human in the loop is intended**. The safety property is *not* "avoid merging" — it's that genuinely uncertain work is **parked** (moved to a needs-human state, commented, not merged) instead of guessed or stalled. Every run ends **merged** or **parked-needs-human**; it never hangs waiting for input.
- **`skills/auto-ticket/autonomous-contract.md`** — the shared contract the driver and sub-skills agree on: the autonomous signal, the grounding block, the status handshake vocabulary, and the single `route-and-stop` parking routine.
- **Autonomous mode (opt-in, additive) on five lifecycle skills** — `work-ticket`, `review-ticket`, `pr-feedback`, `finish-ticket`, and `push` each gained an "Autonomous mode" section describing what happens at every existing human-gate when an autonomous signal is set. Highlights:
  - **`work-ticket`** — proceeds with its own classification (recorded in the PR body), creates the PR without pausing, and treats a missing acceptance criterion as *not done* (keeps working, or parks — never commits a partial). Material implementation ambiguity → needs-human.
  - **`review-ticket`** — uses the inferred acceptance criteria without asking, applies drift rules automatically (out-of-scope stays but is flagged; missing AC = not-done; CRITICAL findings must be fixed), and emits a `clean | fixable-findings | needs-human` verdict.
  - **`pr-feedback`** — now *executes* its triage instead of only planning it: applies address-now fixes, replies to declined/question threads, files a follow-up ticket per deferred/out-of-scope item, and pushes. Conventions decide reviewer conflicts automatically; a genuine tie → needs-human.
  - **`finish-ticket`** — the Step 3 sanity check becomes a hard merge gate (mergeable + CI green + no unaddressed change-requests); anything short of that parks the ticket instead of merging. Trivial merge conflicts auto-resolve; business-logic conflicts → needs-human.
  - **`push`** — never commits a sensitive file unattended (skips it, or parks if it's genuinely required), and resolves the pre-push prompts (no upstream, behind remote) with safe defaults so an unattended run never hangs.
- **New `ccmagic.local.md` keys** (documented in `docs/ccmagic.local.md.example`): `autonomous` (bool, default `false`), `needs_human_state` (parked-ticket state), `needs_human_label` (fallback label, default `needs-human`), `max_feedback_passes` (int, default `3`), plus the other autonomous loop bounds `max_review_fix_passes` (`2`), `max_validate_attempts` (`2`), `ci_timeout_minutes` (`30`), and `ci_poll_interval_seconds` (`60`) — each has a built-in skill default and only needs setting to override.
- **User-level config file** — ccmagic config now resolves by precedence: an explicit arg / orchestrator grounding-block value → the project file `.claude/ccmagic.local.md` → the user file `~/.claude/ccmagic.local.md` → the built-in default. Personal defaults (e.g. a longer `ci_timeout_minutes`, or `autonomous: true`) can live once in the user file and be overridden per-repo.
- **`README.md` → Autonomous mode** section and a `docs/ccmagic.local.md.example` explainer covering the flow, the merge-or-park safety property, and how to turn it on.

### Changed

- **`pr-feedback`** — added `Skill(*)` to `allowed-tools` so its autonomous path can invoke `/ccmagic:push`. The interactive plan-only path is unchanged.
- **`/ccmagic:help`** and the README skill tables now list `auto-ticket` (24 skills total) and include an autonomous-workflow example.
- Autonomous behavior is strictly **additive** — every interactive path across the five modified skills is untouched; the new defaults are gated behind an explicit autonomous signal (`--autonomous` arg → orchestrator grounding block → `autonomous:` config, in that priority order).

## [3.0.3] — 2026-07

### Changed

- Add `user-invocable: true` to the three skills that omitted it (`browser-qa`, `design-explore`, `design-qa`), so all 23 skills consistently match the documented "all skills are user-invocable" convention.

### Housekeeping

- Stop tracking `.claude/settings.local.json` (a personal, machine-local Claude Code settings file) and add a `.gitignore` covering it plus editor swap/backup files. It should never have shipped in the repo or the plugin bundle.

## [3.0.2] — 2026-07

### Fixed

- Add the required `timeout` field (10s) to the PostToolUse hook entry in `hooks/hooks.json`. Claude Code treats the field as optional, but the marketplace/sandbox validator requires `timeout` (or `timeoutMs`) on every hook, which caused a `hook timeout or timeoutMs is required` error and a cascading plugin-manifest rejection.

## [3.0.1] — 2026-07

### Fixed

- Add the required `name` field to the YAML frontmatter of all 23 skills. The field matches each skill's kebab-case directory (e.g. `name: finish-ticket`). Claude Code's plugin loader infers the name from the directory, so the omission was silent locally, but the marketplace/sandbox validator requires an explicit `name` string — its absence caused `front matter must include a string name` errors and a cascading plugin-manifest rejection.

## [3.0.0] — 2026-05

**Breaking change.** ccmagic refocuses from project management to dev workflow. 23 planning/state-management skills have been removed; 3 new tracker-aware skills have been added; a non-blocking commit-format hook now ships with the plugin.

### Why this change

ccmagic v1–v2 grew into a 40-skill project-management surface: epics, features, tasks, spikes, backlogs, sessions, daily standups, checkpoints, handoffs, sync, status, progress. It worked, but in practice the maintainer ended up using other tools for the project-planning side of the loop:

- **[GSD](https://github.com/devondragon/gsd)** for milestone planning, roadmaps, phase-based execution, and the structured workflow side of large projects.
- **[Superpowers](https://github.com/anthropics/superpowers)** for shorter-lived feature work, brainstorming, plan execution, and test-driven discipline.

Both tools were doing the planning job better than ccmagic, but ccmagic kept its planning skills around for backward-compatibility. The result was a plugin pulling in two directions: half of the surface was duplicating what GSD/Superpowers already did, and the half that was genuinely useful (code review, push/pr/merge, debug, design QA, research) was buried under the planning verbs.

v3 strips the planning side and **goes all-in on the dev workflow loop**: pick up a ticket → branch → implement → review → PR → merge → close. The skills that survived are the ones that earned their keep on every single workday regardless of how the planning was being done.

### What replaces the removed skills

The intent is that ccmagic v3 + your planning tool of choice covers the full loop:

| If you used… | Now use… |
|---|---|
| `/ccmagic:plan`, `/ccmagic:create-features`, `/ccmagic:create-tasks` | GSD `/gsd:plan-phase` or Superpowers `brainstorming` skill |
| `/ccmagic:start-task`, `/ccmagic:current-task`, `/ccmagic:complete-task` | GSD `/gsd:execute-phase`, or use `/ccmagic:work-ticket {ID}` if work is tracker-driven |
| `/ccmagic:checkpoint`, `/ccmagic:handoff`, `/ccmagic:context-save`, `/ccmagic:context-load` | GSD `/gsd:pause-work` + `/gsd:resume-work`, or rely on Claude Code's native context management |
| `/ccmagic:status`, `/ccmagic:progress`, `/ccmagic:daily-standup` | GSD `/gsd:progress` + `/gsd:stats` |
| `/ccmagic:discuss-feature` | GSD `/gsd:discuss-phase` or Superpowers `brainstorming` |
| `/ccmagic:add-backlog`, `/ccmagic:blockers` | GSD backlog system, or your tracker (Linear, GitHub, JIRA) |
| `/ccmagic:verify` | `/ccmagic:review-ticket` (now checks AC against the diff), or GSD `/gsd:verify-work` |
| `/ccmagic:sync`, `/ccmagic:quick-start`, `/ccmagic:resume`, `/ccmagic:create-spike`, `/ccmagic:start-spike` | GSD equivalents, or drop them |

If you weren't using GSD or Superpowers, v3 is still useful — the tracker-aware skills (`work-ticket`, `review-ticket`, `finish-ticket`) and the dev verbs (`push`, `pr`, `review`, `debug`, etc.) cover most day-to-day work. You'll just lose ccmagic's own project-management story.

### Added

- **`/ccmagic:work-ticket {ID}`** — End-to-end ticket workflow. Detects your tracker (Linear / GitHub Issues / JIRA), looks up the ticket, classifies the work (Quick Fix / Complex Feature / Debugging), creates a branch, runs the right execution path, validates scope against the ticket, and opens a PR. Replaces the JIRA-only version that lived in the `general-dev-claude-plugin`.
- **`/ccmagic:review-ticket [ID]`** — Code review *grounded in the ticket's stated scope*. Fetches the ticket and acceptance criteria, runs `/ccmagic:review` with the ticket as the primary intent source, and adds an explicit Ticket-scope drift section: in-scope changes, out-of-scope changes (need justification), missing-from-ticket AC items.
- **`/ccmagic:finish-ticket [--qa]`** — Closes a ticket end-to-end after the PR is ready. Sanity-checks the PR (CI, reviews, scope alignment), confirms disposition (Done by default, QA opt-in), merges with the right strategy, and posts the merge back to the tracker.
- **Multi-tracker support** for the three skills above. Linear (via Linear MCP), GitHub Issues (via `gh` CLI), JIRA (via Atlassian MCP). Auto-detection cascade based on MCP availability, CLI availability, branch hints, and `.claude/ccmagic.local.md` configuration.
- **Commit-format hook** (`hooks/post-tool-use-commit.sh`) — Non-blocking PostToolUse hook that validates every commit's subject line against the conventional-commit format. Warns but never rejects, so it's safe on repos with non-conventional commit history.
- **`.claude/ccmagic.local.md`** — Per-project tracker config (which tracker, URL base, ticket ID regex, QA workflow toggle, GitHub repo). Template in `docs/ccmagic.local.md.example`. Created by `/ccmagic:init` and edited by `/ccmagic:settings`.

### Changed

- **`/ccmagic:review`** now has adaptive QUICK/DEEP routing. QUICK is an inline checklist pass; DEEP is the full multi-agent pipeline (4 core agents + conditional specialists + Codex CLI + MCP fallback + Critical/High verification). Default routing is biased toward DEEP — QUICK only fires for clearly trivial diffs (≤2 files, ≤50 lines, no risk paths, no new types, no error-handling changes). Override with `--quick` or `--deep`.
- **`/ccmagic:init`** is heavily slimmed. v2 created an epic/feature/task/spike/session/backlog directory tree. v3 creates only `context/conventions.md`, `context/branching.md`, `context/knowledge/`, and `.claude/ccmagic.local.md`. No planning state.
- **`/ccmagic:doctor`** rewritten to check the new surface: project config files, tracker integration availability, commit hook installation, branch convention compliance. v2 checked epic/feature/task directory health, which is no longer relevant.
- **`/ccmagic:help`** rewritten around the new 23-skill surface.
- **`/ccmagic:settings`** trimmed to tracker-related knobs (default tracker, QA workflow, ticket-ID regex override). Removed knobs for the deleted planning skills.
- **`.claude/CLAUDE.md`** consolidated. Now contains two parts: (1) ccmagic conventions documented for consuming projects (commit format, branch naming, ticket-ID regex), and (2) plugin-development notes for anyone editing ccmagic itself. The conventions live here (not at the plugin root) so they don't leak into consuming-project context.
- **Plugin description and keywords** updated to reflect the dev-workflow focus.

### Removed

- 23 project-management skills: `add-backlog`, `blockers`, `checkpoint`, `complete-task`, `context-load`, `context-save`, `create-features`, `create-spike`, `create-tasks`, `current-feature`, `current-task`, `daily-standup`, `discuss-feature`, `handoff`, `plan`, `progress`, `quick-start`, `resume`, `start-spike`, `start-task`, `status`, `sync`, `verify`.
- `skills/init/full-template.md` (the full-mode template that built the epic/feature/task tree).
- Planning-state references throughout the kept skills: `/ccmagic:status` follow-ups in `pr`/`merge`/`validate`/`test`, `context/working-state.md` updates in `push`, `context/backlog.md` offers in `debug`, `context/features/*/tasks/` lookups in `analyze-impact`/`test`/`review`/`codex-review`, `/ccmagic:init`/`/ccmagic:plan` next-step pointers in `map-codebase`.

### Migration from v2.x

Existing v2.x project directories (`context/features/`, `context/tasks/`, etc.) aren't auto-migrated — they're harmless if left in place but no v3 skill reads them. You can delete them, archive them, or leave them.

Kept files:
- `context/conventions.md` — coding standards (read by `review`, `codex-review`, `pr-feedback`, `push`, `quick`)
- `context/branching.md` — branch strategy (read by `pr`, `merge`)
- `context/knowledge/*.md` — architecture/stack/conventions (produced by `map-codebase`; read by `review`, `codex-review`, `analyze-impact`)

New files:
- `.claude/ccmagic.local.md` — tracker config (created by `/ccmagic:init`)

The recommended migration path:

1. Back up your v2 `context/` directory if you want to preserve historical planning data.
2. Run `/ccmagic:init` — it's idempotent and won't touch existing `conventions.md`/`branching.md`/`knowledge/` files; it'll just add `.claude/ccmagic.local.md` and any missing files.
3. Run `/ccmagic:doctor` to confirm the setup is healthy.
4. If you used `/ccmagic:map-codebase` before, you can re-run it to refresh `context/knowledge/` against the current state of the code.

### Repository structure

```
ccmagic/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── skills/
│   └── <name>/SKILL.md          # 23 skills
├── hooks/
│   ├── hooks.json
│   └── post-tool-use-commit.sh
├── docs/
│   └── ccmagic.local.md.example
├── .claude/
│   └── CLAUDE.md                # Conventions + dev notes (not auto-loaded)
├── README.md
├── CHANGELOG.md
└── LICENSE
```

---

## [2.3.1] and earlier

See git history. v2.x was a 40-skill project-management plugin centered on epics/features/tasks/spikes/sessions, with code-review and design-QA verbs alongside. The planning surface was the headline feature; v3 inverts that.
