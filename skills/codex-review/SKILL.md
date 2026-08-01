---
name: codex-review
user-invocable: true
allowed-tools: Read(*), Write(*), Bash(*), Glob(*), Grep(*), Task(*), TodoWrite(*), AskUserQuestion(*)
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
# Check for a timeout binary to bound them with — GNU coreutils, absent from stock macOS
command -v timeout >/dev/null && echo "TIMEOUT_BIN=timeout" \
  || { command -v gtimeout >/dev/null && echo "TIMEOUT_BIN=gtimeout" || echo "TIMEOUT_BIN=none"; }
```

If `TIMEOUT_BIN=none`, print `No timeout/gtimeout found (brew install coreutils) — skipping external CLI passes.` and run with Claude-side analysis only. An unbounded external CLI call is the stall the deadline exists to prevent, so running without one is not an acceptable fallback. Otherwise substitute the resolved name wherever Step 4 writes `timeout`.

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

### Create a run-scoped workspace first

Every intermediate file this skill writes lives in one per-run directory. Create it before anything else and substitute the printed path for `{RUN_DIR}` in every command below:

```bash
mktemp -d /tmp/ccmagic-codex-review.XXXXXX
```

**Never write these to a fixed `/tmp` path.** Step 5a aggregates results with a `codex-*-output.txt` wildcard, and a wildcard over shared `/tmp` matches leftovers from every previous run — plus `codex-review-output.txt`, written by the separate `/ccmagic:review` skill. Unscoped, that glob silently ingests a stale dimension nobody ran this time, or another skill's adversarial pass, then feeds it into the multi-model agreement boost in Step 5d and inflates confidence on the strength of a file from last week. Concurrent runs are worse: `codex-review-diff.txt` is opened with `>`, so one run truncates the diff another is mid-way through piping to Codex — and since `/ccmagic:review-ticket` and `/ccmagic:auto-ticket` both reach this skill without anyone typing its name, concurrent runs are ordinary rather than hypothetical. Confining the glob to a fresh per-run directory makes all of it impossible by construction.

### Branch mode
```bash
git diff --name-only main...HEAD
git diff --stat main...HEAD
git log --oneline main...HEAD
git diff main...HEAD > {RUN_DIR}/codex-review-diff.txt
```

### PR mode
```bash
gh pr diff {N} --name-only
gh pr view {N} --json title,body,baseRefName
gh pr diff {N} > {RUN_DIR}/codex-review-diff.txt
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
  > {RUN_DIR}/codex-review-files.txt
```

**Partition into modules** by top-level source directory:
```bash
# Group files by first meaningful directory (src/*, app/*, lib/*, cmd/*, pkg/*, etc.)
# Create one file list per module: {RUN_DIR}/codex-module-{name}.txt
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

**Write each dimension's prompt to disk before you invoke anything.** The commands below feed the CLIs from `{RUN_DIR}/codex-{dimension}-prompt.txt`; that file does not create itself. For every dimension you selected, fill in its template from `codex-prompts.md` (substituting the project conventions gathered in Step 2) and write the result with the Write tool to `{RUN_DIR}/codex-{dimension}-prompt.txt`. Skipping this is not a no-op: `cat` on a missing prompt file fails, `set -o pipefail` propagates that failure, and the Gemini pass — which interpolates the file with `$(cat …)` — would otherwise send an empty prompt and get back a confidently useless review.

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

Substitute the `TIMEOUT_BIN` resolved in Step 1 for `timeout` in every command below.

**Codex pass:**
```bash
REVIEW_MODEL="${MODEL:-gpt-5.3-codex}"
FALLBACK_MODEL="${FALLBACK_MODEL:-gpt-5-codex}"

# Inject dimension-specific prompt and diff content via stdin
# (--base and [PROMPT] are mutually exclusive in codex; pipe diff instead)
set -o pipefail
cat {RUN_DIR}/codex-{dimension}-prompt.txt {RUN_DIR}/codex-review-diff.txt | \
  timeout --kill-after=30 600 codex --model ${REVIEW_MODEL} --full-auto exec - \
  > {RUN_DIR}/codex-{dimension}-output.txt 2>&1
echo "CLI_EXIT=$?" >> {RUN_DIR}/codex-{dimension}-output.txt
```

**Gemini pass (if available):**
```bash
# Run same dimension prompt through Gemini for cross-model coverage
timeout --kill-after=30 600 gemini --model gemini-2.5-pro -p "$(cat {RUN_DIR}/codex-{dimension}-prompt.txt)" \
  > {RUN_DIR}/gemini-{dimension}-output.txt 2>&1
echo "CLI_EXIT=$?" >> {RUN_DIR}/gemini-{dimension}-output.txt
```

**For full mode:** Run each dimension per module, then aggregate:
```bash
# Per module, per dimension
set -o pipefail
cat {RUN_DIR}/codex-{dimension}-prompt.txt <(echo "Files to review:") {RUN_DIR}/codex-module-{name}.txt | \
  timeout --kill-after=30 600 codex --model ${REVIEW_MODEL} --full-auto exec - \
  > {RUN_DIR}/codex-{dimension}-{module}-output.txt 2>&1
echo "CLI_EXIT=$?" >> {RUN_DIR}/codex-{dimension}-{module}-output.txt
```

**Every external CLI call carries `timeout`.** These tools write nothing until they finish, so an empty output file means "still working" exactly as often as it means "died" — without an enforced deadline there is no way to tell, and a single slow dimension stalls the whole review indefinitely. Never conclude a CLI died from an empty file or from its absence in `ps`. `--kill-after=30` is not decoration: bare `timeout` sends only `SIGTERM`, which the child may trap or ignore, so the follow-up `SIGKILL` is what turns the deadline into a guarantee.

**The exit code has to survive to be read.** Write the CLI's output to the file with `>` and record the status with `echo "CLI_EXIT=$?"` — do **not** end these commands with `| tee file`. A pipeline reports the status of its *last* command, so `timeout 600 codex … | tee out.txt` yields `tee`'s exit 0 and a genuine timeout becomes indistinguishable from a clean run. Where a pipeline is structural (the `cat … | codex` stdin feed above), `timeout` is already the last element, so its status does survive — but `set -o pipefail` is still needed to catch a failing `cat`, which would otherwise feed Codex an empty prompt and report success. `CLI_EXIT=124` means the deadline was hit: record that dimension as `timed out` and carry on with the rest.

**Model fallback:** If primary model access fails (check for "model not found", "not available", "permission denied"), retry once with `FALLBACK_MODEL`.

### Parallel Execution

- Different dimensions are independent — run in parallel
- For full mode: different modules within the same dimension are independent — run in parallel
- Cap total concurrent external CLI calls at 4

## Step 5: Claude Triage

Load `${CLAUDE_SKILL_DIR}/codex-triage.md` for full triage instructions.

### 5a. Read all external outputs

```bash
cat {RUN_DIR}/codex-*-output.txt {RUN_DIR}/gemini-*-output.txt 2>/dev/null
```

**Classify each file by its `CLI_EXIT=` line before you read a single finding.** That line is the last thing in every output file and it is the only reliable statement about whether the pass succeeded; the findings above it are meaningless if the run died halfway. Per file:

- `CLI_EXIT=0` → the pass completed. Parse its findings. If there are none, that dimension is `completed — 0 findings`, which is a *result*, not a failure.
- `CLI_EXIT=124` → `timed out`. Record it on the coverage line and continue with the other dimensions.
- `CLI_EXIT=` non-zero, with an authentication diagnostic (`not logged in`, `unauthorized`, `authentication failed`, `run codex login`) → `auth failed`.
- `CLI_EXIT=` non-zero, cause unclear → `failed (exit N)`.
- No `CLI_EXIT=` line at all → the command never finished writing. Treat as `unavailable`, never as "clean".

**Branch on the exit status first, never on keywords alone.** These files hold the models' *findings* as well as their diagnostics, and review findings routinely discuss authentication, logins, and unauthorized access. Grepping the whole file for `auth` without checking the status first throws away a successful review as an auth failure — and the more findings the pass produced, the likelier the misfire.

**An empty output file is NOT a failure signal.** These CLIs buffer and write nothing until they finish, so a 0-byte file means "still working" exactly as often as it means "died". Never conclude a pass failed from an empty file, an empty `BashOutput`, or the absence of the process in `ps`. Only a recorded `CLI_EXIT=` status, a reported completion, or an error in the file itself is evidence.

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

Launch parallel Explore agents for the areas below. **This is a fan-out, so it needs a fan-in** — follow `${CLAUDE_PLUGIN_ROOT}/skills/review/fan-in-protocol.md`: stamp a deadline at dispatch, and when it expires, proceed with whatever reported and mark the rest `unavailable — did not report` on the Coverage line. The same applies to the verification agents in Step 7. Bounding the external CLI calls but not these joins would leave the stall intact, just one step over.

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
- **Dimensions**: [list of passes run — mark any that hit `timeout` (`CLI_EXIT=124`) or produced no output as `timed out` / `no output`, never silently omit one]
- **Coverage**: per external CLI, one of `findings | completed — 0 findings | timed out | unparseable | unavailable | auth failed | failed (exit N)` — e.g. `Codex: findings; Gemini: unavailable`. If every selected dimension ran on every available CLI, say `full`. A dimension left off this line reads as "came back clean", which is exactly the failure this line exists to prevent.
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

Create **TodoWrite** entries for all confirmed findings, grouped by severity then file:
- Critical/High: one todo per finding with fix instructions
- Medium: group related findings per file
- Low/Convention: one summary todo per category

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
