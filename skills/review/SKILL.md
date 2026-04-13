---
user-invocable: true
allowed-tools: Read(*), Edit(*), Bash(git:*, gh:*, codex:*, which:*), Glob(*), Grep(*), Agent(*), Task(*), TodoWrite(*), AskUserQuestion(*), mcp__pal__codereview(*)
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
| `--no-codex` | *(modifier)* | Skip Codex CLI review even if installed |
| `--all-specialists` | *(modifier)* | Force all conditional specialists, bypass adaptive gating |

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

## Step 2.5: Scope Drift Detection

Cross-reference the diff against stated intent to detect scope creep and missing requirements.

### Gather intent sources (in priority order)

1. **Plan file**: Check `~/.claude/plans/` for recent `.md` files referencing the current branch or repo. Read the most recent match.
2. **PR description**: `gh pr view --json body -q .body 2>/dev/null`
3. **Commit messages**: `git log --oneline main...HEAD`

If no intent source exists, skip this step silently.

### Analyze

From the intent source, extract the **stated goal** — what this branch is supposed to accomplish.

Compare against `git diff --name-only main...HEAD`:

**Scope creep** — files changed that are unrelated to the stated intent:
- Changes to modules not mentioned in the plan
- New features or refactors not in scope
- "While I was in there..." changes

**Missing requirements** — intent items with no evidence in the diff:
- Plan items not addressed
- Requirements mentioned but not implemented

### Output (informational, does not block)

```
Scope Check: [CLEAN | DRIFT DETECTED | REQUIREMENTS MISSING]
Intent: <1-line summary of what was requested>
Source: <plan file | PR description | commit messages>
Delivered: <1-line summary of what the diff actually does>
[If drift: list each out-of-scope change]
[If missing: list each unaddressed requirement]
```

This output appears before the main review findings. It gives context for interpreting the review — a finding in out-of-scope code is a stronger signal to revert than fix.

---

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

### Conditional Specialist Agents

After the 4 core agents are launched, detect scope signals from the diff and dispatch additional specialist agents in parallel. These are additive — they run alongside the core agents.

**Scope detection:**
```bash
# Detect what the diff touches
CHANGED=$(git diff --name-only main...HEAD)
HAS_TESTS=$(echo "$CHANGED" | grep -E '(test|spec|__tests__)' | head -1)
HAS_SOURCE=$(echo "$CHANGED" | grep -vE '(test|spec|__tests__|\.test\.|\.spec\.|_test\.)' | grep -E '\.(ts|js|py|rb|go|rs|java|kt|swift|php)$' | head -1)
HAS_MIGRATIONS=$(echo "$CHANGED" | grep -iE '(migrat|\.up\.sql|\.down\.sql|alembic|db/migrate)' | head -1)
HAS_BACKEND=$(echo "$CHANGED" | grep -iE '(model|service|controller|handler|endpoint|api|route|repo)' | head -1)
HAS_FRONTEND=$(echo "$CHANGED" | grep -iE '(component|page|hook|view|template|\.tsx|\.jsx|\.vue|\.svelte)' | head -1)
DIFF_LINES=$(git diff --stat main...HEAD | tail -1 | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+')
```

**Dispatch rules:**

| Specialist | Condition | Agent prompt |
|------------|-----------|--------------|
| **Testing** | `HAS_SOURCE` is non-empty (source code changed) | Testing Agent from agent-instructions.md |
| **Performance** | `HAS_BACKEND` or `HAS_FRONTEND` is non-empty | Performance Agent from agent-instructions.md |
| **Data Migration** | `HAS_MIGRATIONS` is non-empty | Data Migration Agent from agent-instructions.md |

Launch all matching specialists in a single message alongside the core agents (up to 7 total agents in parallel).

**Adaptive gating** (skip specialists that consistently produce zero findings):

If this project has a review history file at `context/review-stats.json`, read it before dispatching. The file tracks per-specialist hit rates:

```json
{"testing": {"dispatched": 8, "findings": 12}, "performance": {"dispatched": 8, "findings": 0}, "migration": {"dispatched": 3, "findings": 2}}
```

- If a specialist has 0 findings across 10+ dispatches, **skip it**. Print: `[specialist] auto-gated (0 findings in N reviews)`
- Exception: **Security** is never gated — it's an insurance policy
- Override: `--all-specialists` flag forces all specialists regardless of gating

After the review completes (Step 7), update `context/review-stats.json` with the dispatch and finding counts from this review.

---

### Full mode — module-based agents:

1. Launch **1 Explore agent per module** (capped at 6) covering all 4 concern areas within that module. Use the "Module Agent" prompt from agent-instructions.md.
2. After module agents complete, launch a **Cross-Module Agent** to check inter-module concerns.

## Step 3.5: Codex CLI Review (optional, parallel)

Check for Codex CLI availability:

```bash
which codex 2>/dev/null && echo "CODEX_AVAILABLE" || echo "CODEX_NOT_AVAILABLE"
```

**If Codex is available**, launch an adversarial review pass via Bash. This runs in the background alongside the Explore agents from Step 3 — it's an independent voice, not a replacement.

```bash
codex exec "Review the changes on this branch against the base branch. Run git diff main...HEAD to see the diff. Find ways this code will fail in production: edge cases, race conditions, security holes, resource leaks, failure modes, silent data corruption, logic errors that produce wrong results silently, error handling that swallows failures. Be adversarial. For each finding, output: severity (Critical/High/Medium/Low), confidence (0-100), file, line, issue, detail, suggestion. No compliments — just problems." -C "$(git rev-parse --show-toplevel)" -s read-only 2>/dev/null
```

Use a 5-minute timeout (`timeout: 300000`). Run via the Bash tool with `run_in_background: true` so it doesn't block the Explore agents.

**Processing Codex output:**

After Codex completes, parse its findings into the same finding schema:
- Tag each finding with `specialist: codex`
- Set `fixable` based on the fix-first classification rules in triage-instructions.md
- Findings enter the same deduplication and triage pipeline as all other findings

**Multi-model confirmation:** When a Codex finding matches a finding from an Explore agent (same file + overlapping line range + same issue type), apply the multi-specialist confirmation boost (+10 confidence, tag as `[MULTI-MODEL: codex + {agent}]`). Cross-model agreement is a strong signal.

**Error handling (all non-blocking):**
- Auth failure (stderr contains "auth", "login", "unauthorized"): `Codex authentication failed. Run 'codex login' to authenticate.`
- Timeout: `Codex timed out after 5 minutes — continuing without Codex findings.`
- Empty response or error: `Codex returned no findings — continuing.`
- Any failure: proceed with Explore agent findings only. Codex is additive, never blocking.

**If Codex is not available:** Print `Codex CLI not found — skipping cross-model review. Install: npm install -g @openai/codex` and continue. This is informational, not an error.

---

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
- **Agents**: 4 core + N specialists (testing, performance, migration — list which ran) [+ Codex CLI]
- **Confidence Threshold**: [threshold used]
- **Convention Sources**: [files loaded, or "none found"]
- **Findings**: X Critical, Y High, Z Medium, W Low, V Convention

## Scope Check
[Output from Step 2.5 — CLEAN / DRIFT DETECTED / REQUIREMENTS MISSING]

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

## Fixes Applied ({count})
[List of auto-fixed and user-approved fixes with commit hashes]
> `abc1234` fix(review): FINDING-003 — missing null check in user handler
> `def5678` fix(review): FINDING-007 — N+1 query in order listing

## Positive Findings
[Well-implemented patterns, good practices observed]

## Specialist Report
[Which specialists ran, which were skipped (scope), which were gated (0 findings in N+ reviews)]

## Overall Assessment
[Quality rating, key risks, actionable recommendation]
```

## Step 7: Fix-First & Task Integration

### 7a. Auto-fix mechanical findings

For findings marked `fixable: true` by triage (see triage-instructions.md Step 7):
- Apply each fix directly in source code
- Prefer minimal changes — one fix per finding
- Commit each fix atomically: `git commit -m "fix(review): FINDING-NNN — description"`
- Output per fix: `[AUTO-FIXED] file:line — issue → what was changed`

Skip auto-fix if the working tree was dirty at the start of the review (detected in Step 0).

### 7b. Batch-ask about judgment calls

For findings marked `fixable: false`, present via a single `AskUserQuestion`:

```
I auto-fixed N issues. M need your input:

1. [HIGH] file:line — issue description
   Suggested fix: what to change
   → A) Fix  B) Skip

2. [MEDIUM] file:line — issue description
   Suggested fix: what to change
   → A) Fix  B) Skip

RECOMMENDATION: Fix #1 because [reason]. Skip #2 because [reason].
```

Apply fixes for items where the user chose "Fix." Commit each individually.

If 0 fixable findings exist, skip 7a. If 0 judgment-call findings exist, skip 7b.

### 7c. Task integration

1. Create **TodoWrite** entries for all remaining (unfixed) findings, grouped by severity then by file:
   - Critical/High: one todo per finding
   - Medium: group related findings per file into one todo
   - Low/Convention: one summary todo per category

2. For Critical and High findings that weren't fixed, ask:
   > "**{count}** Critical/High findings remain unfixed. Create ccmagic tasks for tracking?"
   > - **Yes** — create tasks in `context/features/*/tasks/` grouped by related findings
   > - **No** — TodoWrite entries only
   > - **Pick** — select specific findings to create tasks for

Use `AskUserQuestion` for this decision.

### 7d. Update review stats

If `context/review-stats.json` exists (or conditional specialists were dispatched), update per-specialist dispatch and finding counts for adaptive gating in future reviews.

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
