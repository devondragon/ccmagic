---
user-invocable: true
allowed-tools: Read(*), Bash(*), Glob(*), Grep(*), Task(*), TodoWrite(*), AskUserQuestion(*)
description: Multi-model code review (Codex + Gemini + Claude triage) with dimension-focused passes
argument-hint: "[branch|full|PR#] [--model MODEL] [--focus DIMENSION] [--threshold N]"
model: sonnet
context: fork
---

# Codex Review Command

Multi-model code review: Codex and/or Gemini CLI provide broad coverage across focused dimensions, Claude triages findings, adds its own review pass, and creates an actionable fix plan.

## Arguments

Parse `$ARGUMENTS`:

| Argument | Mode | Description |
|----------|------|-------------|
| *(empty)* | `branch` | Diff current branch vs main (default) |
| `branch` | `branch` | Explicit branch diff |
| `full` | `full` | Full codebase — module-aware chunking |
| `<number>` | `pr` | Review PR by number |
| `--model MODEL` | *(modifier)* | Codex model (default: `gpt-5.3-codex`, fallback: `gpt-5-codex`) |
| `--focus DIM` | *(modifier)* | Run only one dimension: `security`, `architecture`, `correctness`, `errors`, `tests`, `deps` |
| `--threshold N` | *(modifier)* | Confidence threshold, default 80 |

## Step 1: Verify Tool Installation

Check for available review tools:

```bash
# Check Codex
which codex 2>/dev/null && codex --version 2>/dev/null
# Check Gemini CLI
which gemini 2>/dev/null && gemini --version 2>/dev/null
```

**Tool availability determines the review strategy:**
- **Both available**: Run Codex + Gemini in parallel, Claude triages and reconciles. Multi-model agreement boosts confidence.
- **Codex only**: Run Codex passes, Claude triages.
- **Gemini only**: Run Gemini passes, Claude triages.
- **Neither**: Inform user and fall back to `/ccmagic:review`.

```
Neither Codex CLI nor Gemini CLI is installed.
  Codex: npm install -g @openai/codex (https://github.com/openai/codex)
  Gemini: npm install -g @anthropic-ai/gemini-cli

Falling back to Claude-only review...
```

## Step 2: Load Project Conventions

Read convention files (silent skip if missing):
1. `CLAUDE.md` in project root
2. `.claude/CLAUDE.md`
3. `context/conventions.md`

Collect into `{PROJECT_CONVENTIONS}` for the Claude triage pass and Claude-originated review.

## Step 3: Determine Scope and Discover Files

### Branch mode
```bash
git diff --name-only main...HEAD
git diff --stat main...HEAD
git log --oneline main...HEAD
git diff main...HEAD > /tmp/codex-review-diff.txt
```

### PR mode
```bash
gh pr diff {N} --name-only
gh pr view {N} --json title,body,baseRefName
gh pr diff {N} > /tmp/codex-review-diff.txt
```

### Full mode — Module-Aware Chunking

Instead of `head -200`, discover project structure and partition intelligently:

```bash
# 1. Detect project type from build configs
ls package.json go.mod Cargo.toml pyproject.toml pom.xml build.gradle 2>/dev/null
```

**Discover ALL relevant files** (expanded from source-only):

```bash
find . -type f \( \
  -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
  -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" \
  -o -name "*.rb" -o -name "*.swift" -o -name "*.kt" -o -name "*.scala" \
  -o -name "*.cs" -o -name "*.php" -o -name "*.vue" -o -name "*.svelte" \
  -o -name "pom.xml" -o -name "build.gradle" -o -name "build.gradle.kts" \
  -o -name "package.json" -o -name "Cargo.toml" -o -name "go.mod" \
  -o -name "pyproject.toml" -o -name "requirements*.txt" -o -name "Gemfile" \
  -o -name "Dockerfile" -o -name "docker-compose*.yml" \
  -o -name "*.tf" -o -name "*.tfvars" \
  -o -name "application.yml" -o -name "application.properties" \
  -o -name "*.env.example" -o -name ".env.example" \
  -o -name "*.yaml" -o -name "*.toml" \
\) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" \
  -not -path "*/dist/*" -not -path "*/build/*" \
  -not -path "*/__pycache__/*" -not -path "*/vendor/*" \
  -not -path "*/target/*" -not -path "*/.next/*" \
  -not -path "*/.terraform/*" \
  > /tmp/codex-review-files.txt
```

**Partition into modules** by top-level source directory:
```bash
# Group files by first meaningful directory (src/*, app/*, lib/*, cmd/*, pkg/*, etc.)
# Create one file list per module: /tmp/codex-module-{name}.txt
# Cap at 6 modules. Group smaller dirs together if >6.
```

Run separate Codex/Gemini passes **per module** and aggregate findings. This replaces the `head -200` cap with intelligent partitioning.

### File Prioritization (branch/PR modes)

Same tiering as the review skill:
- **Tier 1**: auth/security/crypto paths, API boundaries, new files, data access layers
- **Tier 2**: error handling, config, service/business logic
- **Tier 3**: tests, docs, CSS, small mods to established files

For >50 files, focus Codex/Gemini on Tier 1+2 only.

## Step 4: Run Multi-Dimension Review Passes

Load `${CLAUDE_SKILL_DIR}/codex-prompts.md` for dimension-specific prompt templates.

### Dimension Selection

**Default (no --focus):** Run all applicable dimensions:
- `security` — always
- `correctness` — always
- `errors` — always
- `architecture` — always for full mode, branch/PR if >10 files changed
- `tests` — always for full mode, branch/PR if test files exist
- `deps` — only for full mode or if dependency files changed

**With --focus:** Run only the specified dimension.

### Execution Strategy

For each dimension, run available tools in parallel:

**Codex pass:**
```bash
REVIEW_MODEL="${MODEL:-gpt-5.3-codex}"
FALLBACK_MODEL="${FALLBACK_MODEL:-gpt-5-codex}"

# Inject dimension-specific prompt and diff content via stdin
# (--base and [PROMPT] are mutually exclusive in codex; pipe diff instead)
cat /tmp/codex-{dimension}-prompt.txt /tmp/codex-review-diff.txt | \
  codex --model ${REVIEW_MODEL} --full-auto exec - \
  2>&1 | tee /tmp/codex-{dimension}-output.txt
```

**Gemini pass (if available):**
```bash
# Run same dimension prompt through Gemini for cross-model coverage
gemini --model gemini-2.5-pro -p "$(cat /tmp/codex-{dimension}-prompt.txt)" \
  2>&1 | tee /tmp/gemini-{dimension}-output.txt
```

**For full mode:** Run each dimension per module, then aggregate:
```bash
# Per module, per dimension
cat /tmp/codex-{dimension}-prompt.txt <(echo "Files to review:") /tmp/codex-module-{name}.txt | \
  codex --model ${REVIEW_MODEL} --full-auto exec - \
  2>&1 | tee /tmp/codex-{dimension}-{module}-output.txt
```

**Model fallback:** If primary model access fails (check for "model not found", "not available", "permission denied"), retry once with `FALLBACK_MODEL`.

### Parallel Execution

- Different dimensions are independent — run in parallel
- For full mode: different modules within the same dimension are independent — run in parallel
- Cap total concurrent external CLI calls at 4

## Step 5: Claude Triage

Load `${CLAUDE_SKILL_DIR}/codex-triage.md` for full triage instructions.

### 5a. Read all external outputs
```bash
cat /tmp/codex-*-output.txt /tmp/gemini-*-output.txt 2>/dev/null
```

### 5b. Load convention context
Apply `{PROJECT_CONVENTIONS}` from Step 2 when evaluating findings.

### 5c. Per-finding evaluation
For each finding, assess:
1. **Validity**: Read actual code. Is this real, mitigated, false positive, or convention-allowed?
2. **Severity**: Is the classification correct? Adjust with reasoning.
3. **Actionability**: Fix now, design decision, defer, or dismiss.

### 5d. Multi-model agreement scoring
- 3 models agree on same finding → confidence +15 (capped at 100)
- 2 models agree → confidence +10
- 1 model only → keep original confidence
- Models disagree → flag for user decision in Step 10

### 5e. Deduplicate
Same file + overlapping lines + same issue type → merge. Keep highest confidence, most specific detail.

### 5f. Apply confidence threshold
Drop findings below threshold (default 80, `--threshold N` override). Exception: Critical findings with confidence 60+ survive.

## Step 6: Claude-Originated Review Pass

After triaging external findings, Claude reviews areas where it has an advantage (full codebase access, convention knowledge). See Part 2 of `${CLAUDE_SKILL_DIR}/codex-triage.md`.

Launch parallel Explore agents for:

1. **Codebase Consistency** — Does new code follow established patterns? Are there existing utilities it should reuse? Duplicated logic?
2. **Convention Compliance** — Violations of explicit CLAUDE.md/conventions.md rules that Codex/Gemini wouldn't know about.
3. **Integration Completeness** — Missing exports, route registrations, middleware, DI bindings that peer code has.
4. **Cross-Cutting Gaps** — Inconsistencies across related files that per-file review misses.

Claude-originated findings are tagged with `source: claude` and enter the same severity/confidence pipeline. Skip anything already covered by a triaged external finding.

## Step 7: Verify Critical/High Findings

For all Critical and High findings from any source (Codex, Gemini, Claude), launch parallel verification Explore agents (capped at 4):
- Read actual code in full context
- Check for mitigation elsewhere
- Construct concrete triggering scenario
- Verdict: **CONFIRMED** / **MITIGATED** / **FALSE_POSITIVE**

Process verdicts:
- CONFIRMED → keep with "[Verified]" tag and source attribution
- MITIGATED → downgrade severity one level
- FALSE_POSITIVE → move to Dismissed section

## Step 8: Generate Report

```markdown
# Cross-Model Code Review

## Summary
- **Scope**: branch changes | full codebase | PR #X
- **Tools Used**: Codex ({model}) [+ Gemini] + Claude
- **Dimensions**: [list of passes run]
- **Files Analyzed**: N total (M prioritized)
- **Confidence Threshold**: [threshold]
- **Convention Sources**: [files loaded or "none"]
- **Findings**: X Critical, Y High, Z Medium, W Low

## Critical Issues ({count}) — Verified
For each:
> **[severity] [confidence]% [source: codex|gemini|claude|multi]** `file:line`
> **Issue**: one-line summary
> **Trigger**: concrete scenario
> **Verification**: CONFIRMED — [evidence]
> **Fix**: minimal safe change
> **Test**: specific test to add

## High Priority Issues ({count}) — Verified
[same format]

## Medium Priority Issues ({count})
[same format, without verification]

## Convention Violations ({count})
> **[confidence]% [source: claude]** `file:line`
> **Rule**: [quoted convention]
> **Violation**: what differs
> **Fix**: how to comply

## Low Priority / Suggestions ({count})
[grouped by file]

## Dismissed Findings ({count})
> ~~`file:line` — [issue] (source: {tool})~~
> **Dismissed**: [reason]

## Model Agreement
[Where models agreed vs disagreed, how disagreements were resolved]

## Positive Findings
[Good patterns observed]

## Overall Assessment
[Quality rating, key risks, recommendation]

## Raw Tool Output
<details>
<summary>Codex output (click to expand)</summary>

[raw codex output per dimension]

</details>

<details>
<summary>Gemini output (click to expand)</summary>

[raw gemini output per dimension, if used]

</details>
```

## Step 9: Task Integration

1. Create **TodoWrite** entries for all confirmed findings, grouped by severity then file:
   - Critical/High: one todo per finding with fix instructions
   - Medium: group related findings per file
   - Low/Convention: one summary todo per category

2. For Critical and High findings, ask via `AskUserQuestion`:
   > "**{count}** Critical/High findings confirmed. Create ccmagic tasks for tracking?"
   > - **Yes** — create tasks in `context/features/*/tasks/`
   > - **No** — TodoWrite entries only
   > - **Pick** — select specific findings

## Step 10: Handle Disputed Findings

For findings where models disagree or verification was uncertain:

Present both assessments via `AskUserQuestion`:
> **Disputed**: [issue at file:line]
> **Codex says**: [assessment]
> **Gemini says**: [assessment]  *(if applicable)*
> **Claude says**: [assessment]
> **Options**: Fix | Defer | Dismiss

Record decision in report.

## Execution

1. Check tool installation immediately
2. If neither installed → offer install or fall back to `/ccmagic:review`
3. Load project conventions
4. Determine scope and partition files (module-aware for full mode)
5. Run dimension-focused passes through available tools (parallel)
6. Claude triages with convention awareness and multi-model scoring
7. Claude runs supplementary review (codebase consistency, conventions, integration)
8. Verify Critical/High findings
9. Generate cross-model report
10. Create TodoWrite/task entries
11. Resolve disputed findings with user

**Key principle:** Multiple models catch different things. Codex and Gemini provide broad, independent coverage. Claude provides judgment, convention awareness, and codebase-wide context. Findings that survive multi-model agreement and verification are high-confidence signals worth acting on.
