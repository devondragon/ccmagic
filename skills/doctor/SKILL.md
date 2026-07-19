---
name: doctor
user-invocable: true
allowed-tools: Read(*), Glob(*), Bash(*)
description: Diagnose CCMagic setup issues and validate installation
model: sonnet
context: fork
---

# ccmagic Doctor — Setup Health Check

Run diagnostics on the consuming project's ccmagic setup. Reports what's configured, what's missing, and what to do about each gap.

## Diagnostic Process

Run all sections, then produce the report at the end. Don't stop on the first failure — the user wants the full picture.

### 1. Project config files

Verify the non-planning context files ccmagic skills depend on:

```bash
test -f context/conventions.md && echo "OK   context/conventions.md (read by review, codex-review, pr-feedback, push, quick)" || echo "WARN context/conventions.md missing — run /ccmagic:init to bootstrap"
test -f context/branching.md && echo "OK   context/branching.md (read by pr, merge)" || echo "WARN context/branching.md missing — run /ccmagic:init to bootstrap"
test -d context/knowledge && echo "OK   context/knowledge/ exists" || echo "INFO context/knowledge/ missing — run /ccmagic:map-codebase to populate"
test -f context/knowledge/STACK.md && echo "OK   context/knowledge/STACK.md" || echo "INFO STACK.md missing — run /ccmagic:map-codebase"
test -f context/knowledge/ARCHITECTURE.md && echo "OK   context/knowledge/ARCHITECTURE.md" || echo "INFO ARCHITECTURE.md missing — run /ccmagic:map-codebase"
test -f context/knowledge/CONVENTIONS.md && echo "OK   context/knowledge/CONVENTIONS.md" || echo "INFO CONVENTIONS.md missing — run /ccmagic:map-codebase"
```

### 2. ccmagic project configuration

```bash
test -f .claude/ccmagic.local.md && echo "OK   .claude/ccmagic.local.md" || echo "INFO .claude/ccmagic.local.md missing — tracker will auto-detect"
```

If `.claude/ccmagic.local.md` exists, read its YAML frontmatter and report:
- Active `tracker:` value (`linear`, `github`, `jira`, or `auto`)
- `ticket_url_base` (or "not set")
- `ticket_id_regex` (or the default `[A-Z][A-Z0-9]+-[0-9]+`)
- `default_qa_workflow` (`true` / `false`)

If the file is missing entirely, note that tracker auto-detection will run on each ticket skill invocation — not broken, just not pinned.

### 3. Tracker integration availability

Probe for available tracker integrations:

```bash
# Linear MCP — check if any tool named mcp__*Linear*__get_issue is registered.
# (You cannot list MCP tools from bash directly; surface this as a guideline:
# the user should verify in their Claude Code MCP settings if the Linear server is connected.)

# GitHub CLI
command -v gh >/dev/null 2>&1 && {
  gh repo view --json nameWithOwner 2>/dev/null \
    && echo "OK   gh CLI installed and authenticated for $(gh repo view --json nameWithOwner -q .nameWithOwner)" \
    || echo "WARN gh CLI installed but not authenticated or not in a repo — run 'gh auth login'"
} || echo "INFO gh CLI not installed — GitHub tracker unavailable (install: brew install gh)"

# Atlassian (JIRA) MCP — same caveat as Linear; the user verifies via MCP settings.
```

For Linear and JIRA, surface this checklist in the report instead of trying to probe MCP from bash:

> **Linear MCP:** Verify in Claude Code MCP settings that a Linear server is connected. Tool names look like `mcp__claude_ai_Linear__*`, `mcp__plugin_linear_linear__*`, or (self-hosted Cyrus) `mcp__linear__*`. A server can be *registered but still connecting* at session start — that is a present MCP (auto-ticket loads its tools with a bounded retry), not a missing one.
>
> A missing Linear MCP is not automatically a defect. Headless harness runs use the **prompt-relay transport**: the ticket is injected directly into the prompt and the run's output is relayed back to the tracker as a comment, with no Linear MCP present in that environment at all (see `skills/auto-ticket/autonomous-contract.md` §7 and `docs/cyrus-deployment.md`). Doctor runs on a laptop and can't detect that environment — report "Linear MCP not found; may be running under prompt-relay" rather than flatly calling it broken.
>
> **JIRA (Atlassian) MCP:** Verify in Claude Code MCP settings that an Atlassian server is connected. Tool names look like `mcp__claude_ai_Atlassian__*` or `mcp__plugin_atlassian_atlassian__*`.

### 4. Commit hook

```bash
test -f "$(claude plugins show ccmagic --path 2>/dev/null)/hooks/post-tool-use-commit.sh" \
  && echo "OK   commit-format hook installed" \
  || echo "INFO commit-format hook not found via plugin path — check that ccmagic is installed as a plugin"
```

If the `claude plugins` CLI isn't available, fall back to a softer check: just note in the report that the hook ships with the plugin and runs automatically on `git commit` calls made by Claude Code.

### 5. Git configuration

```bash
git rev-parse --git-dir 2>/dev/null \
  && echo "OK   Git repository" \
  || echo "FAIL Not in a git repository — most ccmagic skills require git"

git config user.name >/dev/null 2>&1 && echo "OK   git user.name set" || echo "WARN git user.name not set"
git config user.email >/dev/null 2>&1 && echo "OK   git user.email set" || echo "WARN git user.email not set"
```

### 6. Branch convention

Read the active `ticket_id_regex` from `.claude/ccmagic.local.md` (default `[A-Z][A-Z0-9]+-[0-9]+`).

```bash
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
if [ -n "$CURRENT_BRANCH" ]; then
  if [[ "$CURRENT_BRANCH" =~ ^(feature|bugfix|hotfix|chore|release)/ ]]; then
    echo "OK   Current branch follows convention: $CURRENT_BRANCH"
  else
    echo "INFO Branch '$CURRENT_BRANCH' doesn't follow ccmagic prefixes (feature/, bugfix/, hotfix/, chore/, release/)"
  fi
fi
```

Then test the branch name against the ticket regex (or integer for GitHub) and report whether a ticket ID is detectable.

### 7. Skill availability

```bash
ls "$(claude plugins show ccmagic --path 2>/dev/null)/skills" 2>/dev/null | head -50
```

Compare against the expected skill list. If the `claude plugins` CLI isn't available, skip this check.

## Report Output

After all checks, produce a single report:

```markdown
# ccmagic Doctor Report

## Status
OK PASS | WARN ISSUES | FAIL CANNOT OPERATE

## Project setup
- {list of OK / WARN / INFO lines from sections 1-2}

## Tracker integration
- Active tracker: {linear | github | jira | auto}
- {Per-tracker status from section 3}

## Commit hook
- {OK / INFO from section 4}

## Git
- {lines from section 5}

## Branch
- {lines from section 6}

## Recommendations
For each WARN/FAIL/INFO above, suggest a concrete next step:
- `/ccmagic:init` to bootstrap missing context files
- `/ccmagic:map-codebase` to populate knowledge files
- `gh auth login` to authenticate the GitHub CLI
- Update `.claude/ccmagic.local.md` with the right tracker
- ...
```

Keep the recommendations actionable — each one should be a single command the user can run.

## Quick mode

If invoked as `/ccmagic:doctor --quick`, skip sections 3, 4, 6, 7 and run only the project-config check (sections 1-2).
