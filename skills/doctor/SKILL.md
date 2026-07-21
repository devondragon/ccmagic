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
CFG=.claude/ccmagic.local.md
if [ -f "$CFG" ]; then
  echo "OK   $CFG present — resolved settings:"
  # Read a key from the YAML frontmatter (ignoring commented # lines);
  # print the value, or the $2 default when the key is absent/blank.
  cfg() { local v; v=$(grep -E "^\s*$1\s*:" "$CFG" 2>/dev/null | grep -v '^\s*#' | head -1 | sed -E "s/^\s*$1\s*:\s*//" | sed -E 's/\s*#.*$//' | tr -d '"' | xargs); echo "${v:-$2}"; }
  echo "     tracker            = $(cfg tracker 'auto (default)')"
  echo "     ticket_url_base    = $(cfg ticket_url_base 'not set')"
  echo "     ticket_id_regex    = $(cfg ticket_id_regex '[A-Z][A-Z0-9]+-[0-9]+ (default)')"
  echo "     default_qa_workflow= $(cfg default_qa_workflow 'false (default)')"
  echo "     github_repo        = $(cfg github_repo 'auto-detect via gh')"
  echo "     autonomous         = $(cfg autonomous 'false (default)')"
  echo "     needs_human_label  = $(cfg needs_human_label 'needs-human (default)')"
else
  echo "INFO $CFG missing — tracker auto-detects on each ticket skill invocation (not broken, just not pinned)"
fi
```

Echo the values the parse produced verbatim into the report's **Tracker integration** section — a blank `tracker` in the config resolves to `auto`, and blank optional keys fall back to the defaults shown above. Feed the resolved `tracker` value into section 3 so the report probes the right integration, and the resolved `ticket_id_regex` into section 6.

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
if [ -n "$CLAUDE_PLUGIN_ROOT" ] && [ -f "$CLAUDE_PLUGIN_ROOT/hooks/post-tool-use-commit.sh" ]; then
  echo "OK   commit-format hook installed ($CLAUDE_PLUGIN_ROOT/hooks/post-tool-use-commit.sh)"
elif [ -n "$CLAUDE_PLUGIN_ROOT" ]; then
  echo "WARN CLAUDE_PLUGIN_ROOT set but hooks/post-tool-use-commit.sh missing — reinstall the ccmagic plugin"
else
  echo "INFO CLAUDE_PLUGIN_ROOT not set — can't locate the plugin dir from here; the hook ships with the plugin and runs automatically on git commits"
fi
```

`$CLAUDE_PLUGIN_ROOT` is the plugin root exported to plugin skills (the same variable `hooks/hooks.json` uses). If it isn't set, fall back to the note above rather than reporting a false failure.

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
if [ -n "$CLAUDE_PLUGIN_ROOT" ] && [ -d "$CLAUDE_PLUGIN_ROOT/skills" ]; then
  echo "OK   $(ls "$CLAUDE_PLUGIN_ROOT/skills" | wc -l | tr -d ' ') skills present:"
  ls "$CLAUDE_PLUGIN_ROOT/skills" | sort | column -c 80 2>/dev/null || ls "$CLAUDE_PLUGIN_ROOT/skills" | sort
else
  echo "INFO CLAUDE_PLUGIN_ROOT not set — skipping skill inventory"
fi
```

Compare against the expected skill list. If `$CLAUDE_PLUGIN_ROOT` isn't set, skip this check.

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
