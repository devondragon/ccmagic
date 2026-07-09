# Changelog

All notable changes to ccmagic are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
