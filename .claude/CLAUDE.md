# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

It is NOT read automatically in this location and must be specifically referenced. This is intentional — it avoids the file leaking into consuming projects' context.

Two audiences live here:

1. **ccmagic project conventions** — commit format, branch names, ticket-ID regex. The bash commit-format hook hardcodes the regex; this section is human documentation of what the hook enforces.
2. **ccmagic plugin development notes** — for anyone editing this repo.

---

# Part 1 — ccmagic conventions (suggested defaults)

These are **suggested** defaults for git workflow, branch naming, commit messages, and PRs. They are not mandates — consuming projects can override per-project in `.claude/ccmagic.local.md`.

## Conventional commit types

The valid `{TYPE}` values used in commit messages, PR titles, and the format hook:

```
feat, fix, docs, style, refactor, test, chore, perf, ci
```

If you add or remove a type, also update `CCM_COMMIT_PATTERN` in `hooks/lib-commit.sh` (the regex is hardcoded there; both commit hooks use it).

## Ticket-ID format

ccmagic supports three trackers; the ticket ID format depends on which one a project uses:

- **Linear / JIRA:** `[A-Z][A-Z0-9]+-[0-9]+` — e.g. `ENG-123`, `PROJ-456`, `MCF1-789`.
- **GitHub Issues:** plain integers — e.g. `42`, `#42`.

Teams without a tracker can omit the ticket ID entirely. The detection logic in `/ccmagic:work-ticket`, `/ccmagic:finish-ticket`, and `/ccmagic:review-ticket` handles all three.

## Project-level configuration

Project-specific values (active tracker, ticket URL base, GitHub repo, QA workflow toggle, etc.) live in an optional file at `.claude/ccmagic.local.md` in the consuming repo. Skills read this file if present; otherwise they auto-detect or fall back to placeholders. See `docs/ccmagic.local.md.example` in this plugin for the template.

## Branch naming convention

Branch names include a ticket ID (if your team uses one) and a short kebab-case description.

| Prefix | Purpose | Example (Linear/JIRA) | Example (GitHub) |
|--------|---------|----------------------|------------------|
| `feature/{TICKET-ID}-short-description` | New features | `feature/ENG-123-add-product-search` | `feature/42-add-product-search` |
| `bugfix/{TICKET-ID}-short-description` | Bug fixes | `bugfix/PROJ-456-fix-cart-total` | `bugfix/43-fix-cart-total` |
| `hotfix/{TICKET-ID}-short-description` | Production hotfixes | `hotfix/PROJ-789-patch-auth-bypass` | `hotfix/44-patch-auth-bypass` |
| `release/{version}` | Release branches | `release/2.4.0` | `release/2.4.0` |
| `chore/{TICKET-ID}-short-description` | Maintenance tasks | `chore/MCF1-101-upgrade-deps` | `chore/45-upgrade-deps` |

Teams without a formal ticket system can drop the `{TICKET-ID}` segment.

## Commit message standards

**Format:**

```
{TYPE}({scope})!?: [TICKET-ID] {description}

[optional body]
```

**Rules:**

- **Type:** see [Conventional commit types](#conventional-commit-types).
- **Scope:** module or component name. Optional — if scope isn't obvious or the change is cross-cutting, omit the parentheses entirely (`feat: add ...`).
- **Breaking-change marker:** append `!` after the type or scope to flag a breaking change (Conventional Commits 1.0). Optional.
- **Ticket ID:** include if your team uses one (either format). Otherwise omit it.
- **Description:** imperative mood, no period at the end, max 72 characters.
- **Body:** optional, wrap at 72 characters, explain *why* not *what*.

**Examples:**

```
feat(catalog): ENG-123 add configurable product price override
fix(checkout): #42 prevent duplicate order submission
feat(api)!: drop deprecated /v1 endpoints
docs(api): add endpoint documentation for returns
refactor(auth): extract token validation into shared service
chore: bump minor deps
```

The commit-format hook (`hooks/post-tool-use-commit.sh`) validates the subject line post-commit. It's non-blocking — it warns but never rejects. In autonomous runs (`ccmagic:auto-*` agents or `autonomous: true`) the PreToolUse guard (`hooks/pre-tool-use-guard.sh`) denies a non-conforming commit before it is made. Git-generated subjects (merge, revert, fixup!/squash! autosquash markers, initial commit) are skipped silently.

## PR standards

- **Title** follows the same commit message format: `{TYPE}({scope})!?: [TICKET-ID] {description}`
- **Description** should include: what changed, why, how to test, link to tracking ticket (if applicable).
- Have at least **1 reviewer** assigned
- All **CI checks must pass** before merge
- Use **squash merge** for feature branches
- Use **merge commit** for release branches

## Git flow

- `main` is the production-ready branch. No direct commits.
- `develop` is the integration branch (when used). No direct commits.
- Feature branches are created from `develop` or `main` depending on the project's branching model.
- All changes reach `main` or `develop` through pull requests only.
- **Never force-push** to shared branches.

---

# Part 2 — ccmagic plugin development notes

These notes are for someone working on the ccmagic plugin itself.

## Repository overview

This is the **ccmagic** project — a Claude Code plugin providing dev workflow skills: tracker-aware ticket lifecycle (Linear, GitHub Issues, JIRA), code review, debugging, design/QA, and meta utilities. (Project-management / planning skills were removed in v3.0.0 — that concern is now better served by GSD or Superpowers.)

## Plugin format

```
ccmagic/
├── .claude-plugin/
│   ├── plugin.json            # Plugin manifest
│   └── marketplace.json       # Marketplace metadata
├── skills/
│   └── <name>/SKILL.md        # Skill directories, each with SKILL.md
├── agents/
│   └── auto-*.md              # per-step wrapper agents for auto-ticket
├── bin/
│   ├── ccm-lib.sh             # shared helpers (sourced; config parsing)
│   └── ccm-*                  # deterministic helpers skills call; print JSON
├── hooks/
│   ├── hooks.json             # PreToolUse guard, SubagentStop handshake, PostToolUse commit format
│   ├── pre-tool-use-guard.sh  # merge gate, force push, secrets, commit format
│   ├── lib-commit.sh          # commit-subject parsing and pattern (sourced)
│   ├── subagent-stop-handshake.sh  # auto-* agents must end with the status handshake
│   └── post-tool-use-commit.sh
├── tests/
│   ├── run.sh                 # plain-bash tests for bin/ and hooks/
│   └── stubs/gh               # gh stub fed recorded API output
├── docs/
│   └── ccmagic.local.md.example  # Template for per-project config
├── .claude/CLAUDE.md          # ← you are here (dev notes + conventions)
├── README.md                  # Installation and usage
└── LICENSE
```

## Skill frontmatter

Each `SKILL.md` uses YAML frontmatter:

```yaml
---
description: Brief one-line description
allowed-tools: Read(*), Bash(git:*), Glob(*)
model: sonnet                  # haiku | sonnet | opus
argument-hint: [expected-args]
context: fork                  # For heavy skills (subagent isolation)
---
```

- **All skills are user-invocable and model-invocable.**
- `context: fork` skills: `map-codebase`, `review`, `codex-review`, `validate`, `analyze-impact`, `research`, `doctor`, `design-explore`, `design-qa`, `browser-qa`, `auto-ticket`.
- Do **not** use `disable-model-invocation: true` — it's broken for plugin skills (see [#22345](https://github.com/anthropics/claude-code/issues/22345), [#24042](https://github.com/anthropics/claude-code/issues/24042)). Re-evaluate when fixed upstream.

## Testing locally

Scripts and hooks: `bash tests/run.sh` (add a case there for any change to `bin/` or `hooks/`), and `shellcheck -x bin/ccm-* hooks/*.sh tests/run.sh tests/stubs/gh`. CI runs both, with Ubuntu's shellcheck 0.9.0, which flags some rules newer versions don't; to match it locally: `docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:v0.9.0 -x bin/ccm-* hooks/*.sh tests/run.sh tests/stubs/gh`. CI's jq is 1.7; to run the tests as CI does: `docker run --rm -v "$PWD:/src:ro" ubuntu:24.04 bash -c 'apt-get update -qq && apt-get install -y -qq jq git perl >/dev/null && cp -r /src /w && cd /w && git config --global --add safe.directory "*" && bash tests/run.sh'`.

When a rule has exactly one right answer (a CI verdict, a config value, a merge precondition), put it in a `bin/ccm-*` script or a hook, and have the skill call the script and act on its JSON. Keep judgment in the skill. Skills reference scripts as `"${CLAUDE_SKILL_DIR}/../../bin/ccm-<name>"`, grant that path in `allowed-tools`, and say the bare name works too (plugin `bin/` is on `PATH`), for contexts where the variable isn't expanded.

```bash
# Test the plugin locally
claude --plugin-dir ./

# Verify all skills appear
# Then test representative skills: doctor, init, review, work-ticket, push
```

## When modifying skills

1. Maintain backward compatibility — existing projects rely on these skills.
2. Test skills in isolation before committing.
3. Update relevant documentation in `/docs` and `README.md` when changing skill behavior.
4. Follow the existing skill directory naming pattern (kebab-case).
5. Keep `SKILL.md` under 500 lines — extract supporting content if needed and reference via `${CLAUDE_SKILL_DIR}/filename.md`.

## When adding new skills

1. Create `skills/<name>/SKILL.md`.
2. Include comprehensive frontmatter.
3. Add `context: fork` for heavy/long-running skills.
4. Keep descriptions concise (1 line) for context budget.
5. Document the skill in `README.md` and add it to the `help` skill listing.

## Notes for development

- Skills should be self-contained and not depend on external state.
- Use appropriate model selections in frontmatter for skill complexity.
- Keep skill prompts focused on single responsibilities.
- Consider token usage when designing skills that read many files.
- `$ARGUMENTS` works in skills for dynamic values.
- `${CLAUDE_SKILL_DIR}` references supporting files in the skill directory.
- `${CLAUDE_PLUGIN_ROOT}` references the plugin root (used in `hooks/hooks.json`).
