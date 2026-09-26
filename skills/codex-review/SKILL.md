---
name: codex-review
user-invocable: true
allowed-tools: Read(*), Write(*), Bash(*), Bash(${CLAUDE_PLUGIN_ROOT}/bin/ccm-external-review *), Bash(ccm-external-review *), Glob(*), Grep(*), Task(*), TodoWrite(*), AskUserQuestion(*)
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

`ccm-external-review` runs every external pass (Step 4) and decides which tools can run. Ask it first, before doing any scoping work; `--check` runs nothing:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-external-review" --check
```

The script is also on the Bash `PATH` as `ccm-external-review` while the plugin is enabled; use the bare name if the `${CLAUDE_PLUGIN_ROOT}` path doesn't resolve. It prints `{tools: [{tool, available, reason?}]}`. A tool with `available: false` carries a `reason`: the CLI is not on `PATH`, or neither `timeout` nor `gtimeout` is installed. In the second case print the reason (it says `brew install coreutils`) and run with Claude-side analysis only; an unbounded external CLI call is the stall the deadline exists to prevent.

**Tool availability determines the review strategy:**
- **Both available**: Run Codex + Gemini in parallel, Claude triages and reconciles. Multi-model agreement boosts confidence.
- **Codex only**: Run Codex passes, Claude triages.
- **Gemini only**: Run Gemini passes, Claude triages.
- **Neither** (`--check` exits 2): Inform user and fall back to `/ccmagic:review`.

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

Every intermediate file this skill writes (the conventions file, full mode's module lists) lives in one per-run directory. Create it before anything else and substitute the printed path for `{RUN_DIR}` in every command below:

```bash
mktemp -d /tmp/ccmagic-codex-review.XXXXXX
```

**Never write these to a fixed `/tmp` path.** `/ccmagic:review-ticket` and `/ccmagic:auto-ticket` both reach this skill without anyone typing its name, so concurrent runs are ordinary, and a fixed path lets one run overwrite another's module lists. `ccm-external-review` keeps its own outputs in a run-scoped directory under the git dir for the same reason.

### Branch mode
```bash
git diff --name-only main...HEAD
git diff --stat main...HEAD
git log --oneline main...HEAD
```

`ccm-external-review` computes the diff it feeds the CLIs (`git diff main...HEAD`, or `--base <branch>`).

### PR mode
```bash
gh pr diff {N} --name-only
gh pr view {N} --json title,body,baseRefName
```

Step 4 passes `--pr {N}`, and the script feeds the CLIs `gh pr diff {N}`.

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
# Module names: letters, digits, '.', '_', '-' only.
```

Run separate Codex/Gemini passes **per module** (Step 4 passes one `--module {name}={RUN_DIR}/codex-module-{name}.txt` per module) and aggregate findings. This replaces the `head -200` cap with intelligent partitioning.

### File Prioritization (branch/PR modes)

Same tiering as the review skill:
- **Tier 1**: auth/security/crypto paths, API boundaries, new files, data access layers
- **Tier 2**: error handling, config, service/business logic
- **Tier 3**: tests, docs, CSS, small mods to established files

For >50 files, focus Codex/Gemini on Tier 1+2 only.

## Step 4: Run Multi-Dimension Review Passes

`ccm-external-review` holds the dimension prompts (run `ccm-external-review --print-prompt <dimension>` to see one), feeds them to the CLIs with the diff or module file list, bounds every call, and classifies each pass. **Do not write prompt files or call `codex` or `gemini` yourself.** Each prompt opens with the "Do not load, consult, or follow any installed skill…" line that stops Codex's skill auto-matcher from following an unrelated review skill out of `~/.codex/skills/`; see the note in `${CLAUDE_SKILL_DIR}/codex-prompts.md`.

If Step 2 found any conventions, write `{PROJECT_CONVENTIONS}` with the Write tool to `{RUN_DIR}/conventions.md` and pass `--conventions {RUN_DIR}/conventions.md`; the script appends it to every dimension prompt.

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

One call runs every selected dimension through every available tool (Step 1), in parallel:

```bash
# Branch mode
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-external-review" --tools {codex,gemini} --dimensions {dim,dim,...} \
  [--conventions {RUN_DIR}/conventions.md] [--model MODEL]
# PR mode: add --pr {N}
# Full mode: add one --module {name}={RUN_DIR}/codex-module-{name}.txt per module
```

- `--tools`: only the tools Step 1 reported available (`codex`, `gemini`, or both).
- `--model`: the `--model` argument, if given. The script defaults to `gpt-5.3-codex` and retries a pass once with `gpt-5-codex` when the primary model is refused ("model not found", "not available", "permission denied").
- Codex gets the prompt followed by the diff (or, in full mode, `Files to review:` and the module's file list) on stdin. Gemini gets the prompt as its `-p` argument.

Every pass runs under `timeout --kill-after=30 300`, and at most 4 CLI calls run at once, so a run with more than 4 passes takes more than one 5.5-minute window. **Run the call with `run_in_background: true`** and wait for its completion notification. Do not poll the output files or `ps`: these CLIs write nothing until they finish, so an empty file means "still working" as often as "died". The script always exits once every pass has finished or hit its deadline.

## Step 5: Claude Triage

Load `${CLAUDE_SKILL_DIR}/codex-triage.md` for full triage instructions.

### 5a. Read all external outputs

The script prints `{run_dir, mode, base, timeout_seconds, passes: [...]}`, one entry per (tool, dimension, module) pass with `status`, `exit_code`, `output_file` (the CLI's stdout, the review), and `stderr_file` (diagnostics). If it exits 3 (it couldn't read the diff or a module file) or 4 (usage error), fix the call or report every external pass as `failed` with its error; do not fall back to running the CLIs by hand.

**Act on each pass's `status`; do not re-derive it from the files.** The script decided it from the exit status first and matched auth diagnostics only on a nonzero exit, because these files routinely discuss authentication, logins, and unauthorized access as findings.

- `findings` → read `output_file` and parse its findings. If nothing in it parses as a finding, record `unparseable`.
- `empty` → `completed — 0 findings`, which is a *result*, not a failure.
- `timed-out` → `timed out`. Record it on the coverage line and continue with the other dimensions.
- `auth-failed` → `auth failed`.
- `failed` → `failed (exit N)`, with N from `exit_code`.
- `unavailable` → `unavailable`, with the `reason`. Never read it as "clean".

Read only the `output_file`s listed in this run's JSON. Never glob for output files, which would pick up passes nobody ran this time.

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
- **Dimensions**: [list of passes run — mark any pass whose status was not `findings` or `empty` with that status (`timed out`, `auth failed`, `failed (exit N)`, `unavailable`), never silently omit one]
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
