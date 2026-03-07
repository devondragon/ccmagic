# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

It is NOT read automatically in this location and must be specifically referenced, however this is the only way to avoid it showing up as a slash command to consuming projects.

## Repository Overview

This is the **ccmagic** project - a Claude Code Plugin providing 40 skills for comprehensive project management. Skills help developers maintain organized project context, track work progress, and enable smooth handoffs between development sessions.

## Architecture

### Plugin Format
CCMagic is a Claude Code Plugin (v2.0+) with this structure:

```
ccmagic/
├── .claude-plugin/
│   └── plugin.json            # Plugin manifest (name, version, description)
├── skills/
│   ├── <name>/SKILL.md        # 40 skill directories, each with SKILL.md
│   └── init/
│       ├── SKILL.md           # Skill definition
│       └── full-template.md   # Supporting file (referenced via ${CLAUDE_SKILL_DIR})
├── docs/                      # Documentation
├── README.md            # Installation and usage
└── LICENSE
```

### Skill Frontmatter
Each `SKILL.md` uses YAML frontmatter with these fields:
- `description` (required): One-line description
- `allowed-tools` (required): Tool access list
- `model`: haiku | sonnet | opus
- `argument-hint`: Expected arguments
- `context: fork`: Runs in subagent isolation (for heavy skills)

### Skill Categories
- **All skills are user-invocable and model-invocable** (see note below)
- **Forked** (`context: fork`): `map-codebase`, `review`, `codex-review`, `validate`, `analyze-impact`, `research`, `daily-standup`, `handoff`, `doctor`

> **Note:** `disable-model-invocation: true` is intentionally NOT used because it is broken
> for plugin skills (see [#22345](https://github.com/anthropics/claude-code/issues/22345),
> [#24042](https://github.com/anthropics/claude-code/issues/24042)). Re-evaluate when fixed upstream.

## Development Commands

### Testing Locally
```bash
# Test the plugin locally
claude --plugin-dir ./

# Verify all skills appear
# Then test representative skills: status, init, review, push, research
```

## Important Conventions

### When Modifying Skills
1. Maintain backward compatibility - existing projects rely on these skills
2. Test skills in isolation before committing
3. Update relevant documentation in `/docs` when changing skill behavior
4. Follow the existing skill directory naming pattern (kebab-case)
5. Keep SKILL.md under 500 lines - extract templates to supporting files
6. Reference supporting files via `${CLAUDE_SKILL_DIR}/filename.md`

### When Adding New Skills
1. Create a new `skills/<name>/SKILL.md` file
2. Include comprehensive frontmatter configuration
3. Do NOT use `disable-model-invocation: true` (broken for plugin skills, see note above)
4. Add `context: fork` for heavy/long-running skills
5. Keep descriptions concise (1 line) for context budget
6. Document the skill in README.md
7. Consider which tools the skill needs in `allowed-tools`

### Frontmatter Fields Reference
```yaml
---
description: Brief one-line description
allowed-tools: Read(*), Bash(git:*), Glob(*)
model: sonnet
argument-hint: [expected-args]
context: fork                    # For heavy skills
---
```

### Git Workflow
- Branch from `main` for new features
- Use descriptive commit messages
- Test skills thoroughly before creating PRs
- Update documentation alongside code changes

## Notes for Development

- Skills should be self-contained and not depend on external state
- Use appropriate model selections in frontmatter for skill complexity
- Keep skill prompts focused on single responsibilities
- Document complex workflows in the skill body itself
- Consider token usage when designing skills that read many files
- `$ARGUMENTS` works in skills for dynamic values
- `${CLAUDE_SKILL_DIR}` references supporting files in the skill directory
- `${CLAUDE_SESSION_ID}` available for session-specific operations
