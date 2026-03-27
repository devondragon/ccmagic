---
user-invocable: true
allowed-tools: Read(*), Bash(git:*, gh:*), Glob(*), Grep(*), Task(*), TodoWrite(*), AskUserQuestion(*), mcp__pal__codereview(*)
description: Comprehensive code review with validation, confidence scoring, and convention awareness
argument-hint: "[branch|full|PR#] [--threshold N]"
model: sonnet
context: fork
---

# Code Review Command

Perform a comprehensive, validated code review with confidence scoring and false-positive filtering.

> **Parallel execution:** Launch independent agents simultaneously. Claude Code determines when this is safe.

## Step 0: Parse Arguments

Parse `$ARGUMENTS` to determine review mode and options:

| Argument | Mode | Description |
|----------|------|-------------|
| *(empty)* | `branch` | Diff current branch against main (default) |
| `branch` | `branch` | Explicit branch diff |
| `full` | `full` | Full codebase review — partition into modules |
| `<number>` | `pr` | Review PR by number (e.g., `42`) |
| `--threshold N` | *(modifier)* | Confidence threshold, default 80. Findings below this are dropped. |

If on `main` with no changes and no argument:
> "No branch changes detected. Use `/ccmagic:review full` for a full codebase review, or switch to a feature branch."

## Step 1: Load Project Conventions

Read these files if they exist (silent skip if missing):
1. `CLAUDE.md` in project root
2. `.claude/CLAUDE.md`
3. `context/conventions.md`

Collect their content into a `{PROJECT_CONVENTIONS}` string. This is injected into every agent prompt via `${CLAUDE_SKILL_DIR}/agent-instructions.md`. If none found, agents use language-generic best practices only.

## Step 2: Gather Changes and Prioritize Files

### Branch mode
```bash
git diff --name-only main...HEAD
git diff --stat main...HEAD
git log --oneline main...HEAD
```

### Full mode
1. Detect build configs: `package.json`, `go.mod`, `Cargo.toml`, `pyproject.toml`, `pom.xml`, `build.gradle`
2. Partition source files into modules by top-level directory structure
3. Exclude: `node_modules/`, `vendor/`, `dist/`, `build/`, `.git/`, generated files
4. Cap at 6 modules. If more, group smaller modules together.

### PR mode
```bash
gh pr diff {N} --name-only
gh pr view {N} --json title,body,baseRefName
gh pr diff {N}
```

### File Prioritization (branch and PR modes)

Sort changed files into tiers for agent attention:

**Tier 1 — Always review individually:**
- Files matching: `auth`, `security`, `crypto`, `secret`, `token`, `password`, `permission`, `session`, `middleware`
- API boundary files (routes, controllers, handlers, endpoints)
- New files (not just modifications)
- Data access layers (models, repositories, DAOs, migrations)

**Tier 2 — Review if capacity:**
- Error handling modules
- Configuration files
- Service/business logic files

**Tier 3 — Summary pass only:**
- Test files (check for correctness but deprioritize)
- Documentation files
- CSS/style files
- Small modifications (<10 lines) to well-established files

For diffs with **>50 files**: agents focus on Tier 1 and 2. Tier 3 files get a brief summary pass only.

## Step 3: Launch Parallel Review Agents (Round 1)

Load `${CLAUDE_SKILL_DIR}/agent-instructions.md` for detailed agent prompts.
Load `${CLAUDE_SKILL_DIR}/finding-schema.md` for the output format agents must use.

### Branch/PR mode — 4 parallel Explore agents:

1. **Correctness Agent** — Logic errors, null access, race conditions, broken error propagation. Must construct concrete triggering scenarios. Ignores style, formatting, performance.

2. **Security Agent** — Injection with exploit path, auth bypasses, data exposure, insecure defaults. Must describe attacker's path with preconditions. Ignores internal code without user input.

3. **Convention Compliance Agent** — Checks changes against `{PROJECT_CONVENTIONS}` from Step 1. Only flags violations of explicit documented rules. Reports zero findings if no conventions were loaded.

4. **Architecture Agent** — Breaking API changes, circular deps, coupling violations, missing error handling at boundaries, integration gaps. Identifies impact scope and affected dependents.

Each agent receives:
- The file list (prioritized per Step 2)
- The actual diff or file contents
- The `{PROJECT_CONVENTIONS}` string
- Instructions to use the finding schema exactly

### Full mode — module-based agents:

1. Launch **1 Explore agent per module** (capped at 6) covering all 4 concern areas within that module. Use the "Module Agent" prompt from agent-instructions.md.
2. After module agents complete, launch a **Cross-Module Agent** to check inter-module concerns.

## Step 4: Expert Analysis (MCP Fallback)

**Priority order — use first available:**
1. `mcp__pal__codereview` with model `o3` — pass the diff and project conventions
2. `mcp__pal__codereview` with model `gemini-2.5-pro`
3. If no MCP tools available: skip this step

Merge MCP findings into the pool using the same finding schema. MCP findings enter the triage process like any other finding.

## Step 5: Triage and Validate (Round 2)

Load `${CLAUDE_SKILL_DIR}/triage-instructions.md` for the full triage process.

### 5a. Deduplicate
Same file + overlapping line range + same issue type → merge. Keep highest confidence, most specific detail.

### 5b. Apply confidence threshold
- Drop findings below threshold (default 80, or `--threshold N`)
- Exception: Critical findings with confidence 60+ survive

### 5c. Verify Critical and High findings
For each Critical/High finding that survived, launch a parallel **verification Explore agent** (capped at 4 concurrent):
- Reads actual code in context (not just the diff)
- Checks if issue is mitigated elsewhere (middleware, callers, error handlers)
- Attempts to construct concrete triggering scenario
- Returns verdict: **CONFIRMED** / **MITIGATED** / **FALSE_POSITIVE**

### 5d. Process verdicts
- CONFIRMED → keep with "[Verified]" tag
- MITIGATED → downgrade severity by one level, note the mitigation
- FALSE_POSITIVE → move to Dismissed Findings section

### 5e. Handle MCP vs Explore disagreements
If MCP and Explore agents disagree on a finding → flag for user decision in Step 8.

## Step 6: Generate Report

```markdown
# Code Review Report

## Summary
- **Scope**: branch changes | full codebase | PR #X
- **Branch**: [current branch or PR base]
- **Files Analyzed**: N total (M in Tier 1/2)
- **Confidence Threshold**: [threshold used]
- **Convention Sources**: [files loaded, or "none found"]
- **Findings**: X Critical, Y High, Z Medium, W Low, V Convention

## Critical Issues ({count}) — Verified
For each:
> **[severity] [confidence]%** `file:line`
> **Issue**: one-line summary
> **Detail**: explanation with triggering scenario
> **Verification**: CONFIRMED — [evidence]
> **Suggestion**: minimal fix

## High Priority Issues ({count}) — Verified
[same format]

## Medium Priority Issues ({count})
[same format, without verification section]

## Convention Violations ({count})
For each:
> **[confidence]%** `file:line`
> **Rule**: [quoted convention from CLAUDE.md/conventions.md]
> **Violation**: what the code does differently
> **Suggestion**: how to comply

## Low Priority / Suggestions ({count})
[grouped by file]

## Dismissed Findings ({count})
For each:
> ~~`file:line` — [original issue]~~
> **Dismissed**: [reason — FALSE_POSITIVE or below threshold]

## Positive Findings
[Well-implemented patterns, good practices observed]

## Overall Assessment
[Quality rating, key risks, actionable recommendation]
```

## Step 7: Task Integration

1. Create **TodoWrite** entries for all confirmed findings, grouped by severity then by file:
   - Critical/High: one todo per finding
   - Medium: group related findings per file into one todo
   - Low/Convention: one summary todo per category

2. For Critical and High findings, ask:
   > "**{count}** Critical/High findings confirmed. Create ccmagic tasks for tracking?"
   > - **Yes** — create tasks in `context/features/*/tasks/` grouped by related findings
   > - **No** — TodoWrite entries only
   > - **Pick** — select specific findings to create tasks for

Use `AskUserQuestion` for this decision.

## Step 8: Handle Disputed Findings

For findings where:
- Verification was uncertain (no clear CONFIRMED/FALSE_POSITIVE)
- MCP and Explore agents disagree
- Convention interpretation is ambiguous

Present both sides and ask the user via `AskUserQuestion`:
> **Disputed**: [issue summary at file:line]
> **Agent A says**: [assessment]
> **Agent B says**: [assessment]
> **Options**: Fix | Defer | Dismiss

Record the user's decision in the report.

## Execution

When invoked, immediately begin the review process without asking for confirmation. Be thorough but concise. Every finding must meet the confidence threshold and follow the finding schema. Quality over quantity — 5 verified, actionable findings beat 30 unvalidated observations.
