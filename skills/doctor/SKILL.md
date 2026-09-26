---
name: doctor
user-invocable: true
allowed-tools: Read(*), Glob(*), Bash(*), Bash(${CLAUDE_PLUGIN_ROOT}/bin/ccm-doctor *), Bash(ccm-doctor *)
description: Diagnose CCMagic setup issues and validate installation
model: sonnet
context: fork
---

# ccmagic Doctor — Setup Health Check

Run diagnostics on the consuming project's ccmagic setup. Reports what's configured, what's missing, and what to do about each gap.

## Diagnostic Process

Run all steps, then produce the report at the end. Don't stop on the first failure — the user wants the full picture.

### 1. Run the checks script

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-doctor"
```

The script is also on the Bash `PATH` as `ccm-doctor` while the plugin is enabled; use the bare name if the `${CLAUDE_PLUGIN_ROOT}` path doesn't resolve. In quick mode (below) run it with `--quick`.

It prints one JSON object per line: `{level, area, message, fix}`, where `level` is `OK`, `WARN`, `INFO` or `FAIL`, and `fix` is one next step or `null`. The areas are:

| Area | What it checks |
|---|---|
| Project setup | `context/conventions.md`, `context/branching.md`, `context/knowledge/` and its STACK, ARCHITECTURE and CONVENTIONS files |
| Configuration | whether `.claude/ccmagic.local.md` exists, and the resolved settings as `KEY = VALUE` lines (`(default)` marks a value no config file sets) |
| Hooks and scripts | every hook and `bin/ccm-*` file in the plugin, `jq`, and `timeout`/`gtimeout` |
| Git | inside a repository, `user.name`, `user.email` |
| Branch | the ccmagic branch prefix, and whether a ticket ID parses from the branch (the same parse the ticket skills use) |
| Skills | the skills present, and any skill `/ccmagic:help` lists that is missing |
| Validation | `ccm-validate --list`: one line per check with its command, or "disabled in config", or "not configured" |

Exit code 1 means at least one `FAIL` line; 0 means none. Report the lines as the script printed them. Don't re-run the checks by hand or second-guess a level. If `jq` is missing the script prints a single `FAIL` line and stops; report that and tell the user to install `jq` first.

Take the `tracker = ...` value from the Configuration lines into step 2, so the report probes the right integration.

### 2. Tracker integration availability

The script can't see MCP servers; you can. Check your own tool list:

- **Linear MCP:** tools named `mcp__claude_ai_Linear__*`, `mcp__plugin_linear_linear__*`, or (self-hosted Cyrus) `mcp__linear__*`. A server can be *registered but still connecting* at session start — that is a present MCP (auto-ticket loads its tools with a bounded retry), not a missing one.
- **JIRA (Atlassian) MCP:** tools named `mcp__claude_ai_Atlassian__*` or `mcp__plugin_atlassian_atlassian__*`.

A missing Linear MCP is not automatically a defect. Headless harness runs use the **prompt-relay transport**: the ticket is injected directly into the prompt and the run's output is relayed back to the tracker as a comment, with no Linear MCP present in that environment at all (see `skills/auto-ticket/autonomous-contract.md` §7 and `docs/cyrus-deployment.md`). Doctor runs on a laptop and can't detect that environment — report "Linear MCP not found; may be running under prompt-relay" rather than flatly calling it broken.

For GitHub Issues, probe the CLI:

```bash
command -v gh >/dev/null 2>&1 && {
  gh repo view --json nameWithOwner 2>/dev/null \
    && echo "OK   gh CLI installed and authenticated for $(gh repo view --json nameWithOwner -q .nameWithOwner)" \
    || echo "WARN gh CLI installed but not authenticated or not in a repo — run 'gh auth login'"
} || echo "INFO gh CLI not installed — GitHub tracker unavailable (install: brew install gh)"
```

Weight the findings by the resolved tracker: with `tracker = linear`, a missing Linear MCP matters and a missing Atlassian MCP doesn't; with `auto`, report what is available.

## Report Output

After all checks, produce a single report:

```markdown
# ccmagic Doctor Report

## Status
OK PASS | WARN ISSUES | FAIL CANNOT OPERATE

## Project setup
- {Project setup and Configuration lines, except the KEY = VALUE settings}

## Tracker integration
- Active tracker: {linear | github | jira | auto}
- {The KEY = VALUE settings from Configuration}
- {Per-tracker status from step 2}

## Hooks and scripts
- {Hooks and scripts lines}

## Git
- {Git lines}

## Branch
- {Branch lines}

## Skills
- {Skills lines}

## Validation
- {Validation lines}

## Recommendations
For each WARN/FAIL/INFO above, give its `fix` as a concrete next step, for example:
- `/ccmagic:init` to bootstrap missing context files
- `/ccmagic:map-codebase` to populate knowledge files
- `gh auth login` to authenticate the GitHub CLI
- Update `.claude/ccmagic.local.md` with the right tracker
- ...
```

Status is FAIL if any line is `FAIL`, else WARN if any line is `WARN` (including step 2), else PASS. Keep the recommendations actionable — each one should be a single command the user can run. Group repeated fixes (several "not configured" Validation checks, several missing plugin files) into one recommendation.

## Quick mode

If invoked as `/ccmagic:doctor --quick`, run `ccm-doctor --quick` (Project setup and Configuration only) and skip step 2.
