---
name: review
user-invocable: true
allowed-tools: Read(*), Edit(*), Bash(git diff:*, git log:*, git status:*, git branch:*, git show:*, git rev-parse:*, git merge-base:*, git ls-files:*, git blame:*, gh pr view:*, gh pr diff:*, gh pr list:*, gh repo view:*, codex:*, which:*, command:*, timeout:*, gtimeout:*, echo:*, date:*, mktemp:*), Bash(${CLAUDE_SKILL_DIR}/../../bin/ccm-review-route *), Bash(${CLAUDE_SKILL_DIR}/../../bin/ccm-external-review *), Glob(*), Grep(*), Agent(*), Task(*), TodoWrite(*), AskUserQuestion(*), mcp__pal__codereview(*)
description: Use when the user asks for a code review of a change, diff, branch, or PR, including a diff pasted inline and phrasings like "review this before I open the PR", "can you code review this?", or "look over this change". Auto-routes between a fast inline checklist (QUICK) and the full multi-agent pipeline (DEEP), biased toward depth, with confidence scoring and convention awareness.
argument-hint: "[branch|full|PR#] [--quick|--deep] [--fix] [--threshold N]"
model: sonnet
---

# Code Review Command

Perform an adaptive code review that **auto-routes between QUICK and DEEP** based on the diff's size and risk profile, and **biases toward depth** — only clearly trivial changes get the QUICK pass.

- **QUICK** — Inline checklist pass done by this agent. Categories: correctness, security, performance, maintainability, testing, architecture, conventions. Output is grouped CRITICAL / WARNING / INFO with a PASS / PASS-WITH-WARNINGS / FAIL verdict. Fast, lightweight.
- **DEEP** — Full multi-agent pipeline: 4 core Explore agents + conditional specialists (testing, performance, migration) + optional Codex CLI cross-model pass + MCP fallback + Round-2 verification of Critical/High findings. Comprehensive, confidence-scored.

## This skill is read-only

**Never `git add`, `git commit`, `git push`, `gh pr create`, `gh pr merge`, or `gh pr comment` from this skill — in any mode, for any reason, including when a fix looks obviously correct or the user seems to want it landed.** Reviewing and landing are separate jobs; the user runs `/ccmagic:push` when they want the work committed. The `git` and `gh` grants in the frontmatter are deliberately narrowed to read-only subcommands so this cannot happen by accident. If you find yourself reaching for a write command, produce the finding instead.

The one permitted write is `--fix` (Step 7a), and it edits the **working tree only** — the user reviews the diff and commits it themselves. Without `--fix`, do not use `Edit` on source files at all.

> **Parallel execution:** Launch independent agents simultaneously, all of a batch in one message, each with `run_in_background: false`. Foreground agents in one message still run in parallel, and their results come back in that message. A background agent reports only through a completion notification, and when this skill runs inside a subagent (the `auto-review` step of `/ccmagic:auto-ticket`), that subagent returns to its caller as soon as it ends its turn, before any notification arrives: the review is lost and the step has no verdict. The one background task allowed is the Codex pass in an interactive run (Step 3.5).

## Step 0: Parse Arguments

Parse `$ARGUMENTS` to determine review mode and options:

| Argument | Mode | Description |
|----------|------|-------------|
| *(empty)* | `branch` | Diff current branch against main (default) |
| `branch` | `branch` | Explicit branch diff |
| `full` | `full` | Full codebase review — partition into modules |
| `<number>` | `pr` | Review PR by number (e.g., `42`) |
| `--quick` | *(override)* | Force QUICK inline checklist pass. |
| `--deep` | *(override)* | Force DEEP multi-agent pipeline. |
| `--fix` | *(modifier)* | Apply mechanical fixes to the working tree after reporting (Step 7a). Off by default — without it the review makes no code changes at all. Never commits or pushes, with or without the flag. |
| `--threshold N` | *(modifier)* | Confidence threshold for DEEP, default 80. Findings below this are dropped. |
| `--no-codex` | *(modifier)* | Skip Codex CLI review in DEEP mode even if installed |
| `--all-specialists` | *(modifier)* | Force all conditional specialists in DEEP, bypass adaptive gating |

If on `main` with no changes and no argument:
> "No branch changes detected. Use `/ccmagic:review full` for a full codebase review, or switch to a feature branch."

## Step 0.5: Auto-route between QUICK and DEEP

In branch and PR mode, always run the router script and act on its JSON. It applies the routing rules (QUICK only for at most 2 files and 50 changed lines, no risk-path match, no new type declaration, no error-flow change; `-h` prints them) and reads the review stats. Do not count files or lines or check paths yourself.

```bash
"${CLAUDE_SKILL_DIR}/../../bin/ccm-review-route"      # branch mode (main...HEAD)
"${CLAUDE_SKILL_DIR}/../../bin/ccm-review-route" 42   # PR mode
TMPPREFIX="${TMPDIR:-/tmp}/zsh"; "${CLAUDE_SKILL_DIR}/../../bin/ccm-review-route" --diff-file - <<'CCM_DIFF_END'
<the pasted diff, verbatim, when there is no checkout>
CCM_DIFF_END
```

The script is also on the Bash `PATH` as `ccm-review-route`; use the bare name if the `${CLAUDE_SKILL_DIR}` path doesn't resolve. The `TMPPREFIX=` assignment keeps zsh (the default macOS shell) writing its heredoc temp file under `$TMPDIR`; without it zsh uses `/tmp`, which a sandboxed Bash may refuse, and the heredoc fails before the script runs. It is harmless in bash. Keep its `gated` list for Step 3. Exit 3 means it couldn't read the diff: route DEEP and print `Routing → DEEP, reason: router failed: <error>`.

Then pick the route, first match wins:

1. **User override**: `--quick` → QUICK, `--deep` → DEEP, `full` mode → DEEP (no script run in full mode).
2. **Otherwise**: the script's `route`.

### Announce the routing decision

Print one line before any review work begins. This is non-negotiable; the user needs to know which review they got. Without an override, print the script's `line` field verbatim, for example:

```
Routing → DEEP, reason: 3 files (limit 2), 120 lines (limit 50), touches src/auth/login.ts (auth, login)
```

With an override, print `Routing → QUICK, reason: --quick override` (or `--deep override`, or `full mode`).

Print the same line again as the **first line of the final report** (QUICK output and the Step 6 report). The review runs inline, so tool calls separate the early announcement from the report, and a reader who sees only the report must still see which review they got.

**If QUICK was selected, skip ahead to the [QUICK execution](#quick-execution) section. If DEEP, continue with Step 1.**

## QUICK execution

If Step 0.5 selected QUICK, walk this checklist line by line against the diff. Don't skip categories. Work from the diff; when a finding depends on code outside the hunk, read only the lines around it (`Read` with `offset` and `limit`), not whole files.

Before reporting, read `${CLAUDE_SKILL_DIR}/finding-schema.md` and apply its **What NOT to Report** exclusions. Formatting and whitespace, import ordering, TODO/FIXME/HACK markers, and missing or removed comments and JSDoc (absent an explicit documented convention requiring them) are never CRITICAL or WARNING findings, and usually are not findings at all.

### Correctness
- Logic errors, edge cases (empty inputs, boundaries, unexpected types), null/undefined handling, off-by-one in loops/slices.

### Security
- Input validation, SQL injection (string concatenation in queries), XSS (unescaped output), CSRF on state-changing ops, authorization checks, sensitive data in logs/responses/source.

### Performance
- N+1 queries, unnecessary loops, missing indexes for new query patterns, memory leaks (unclosed resources, growing collections), caching opportunities.

### Maintainability
- Clear names, focused functions (~30 lines), reasonable cyclomatic complexity, DRY violations, dead code.

### Testing
- Coverage for new/changed code, edge-case and error-path coverage, appropriate mock use.

### Architecture
- SOLID, dependency direction, module boundaries, coupling.

### Conventions
- Read `CLAUDE.md`, `.claude/CLAUDE.md`, and `context/conventions.md` if present. Check the diff against any explicit documented rules. No conventions loaded → skip this category.

### Output

Group findings by severity:
- **CRITICAL** — must fix before merge (security, data loss, incorrect behavior).
- **WARNING** — should fix (perf issues, maintainability, missing tests for important paths).
- **INFO** — consider improving (style, minor naming, optional refactors).

For each finding include: severity, category, file/line(s), description, suggested fix.

Final verdict line. Only CRITICAL and WARNING findings decide the verdict; INFO findings never do:
- **PASS** — no CRITICAL and no WARNING findings. INFO-only reports are a PASS.
- **PASS WITH WARNINGS** — one or more WARNING findings, no CRITICAL; merge at reviewer's discretion.
- **FAIL** — one or more CRITICAL findings; address before merge.

After producing the report, **stop**. Do not continue into DEEP mode steps. (If another skill invoked this one, such as `/ccmagic:review-ticket` or `/ccmagic:work-ticket`, stopping ends the review only: go back to that skill's next step.)

If `--fix` was passed, apply mechanical fixes under the Step 7a rules (working tree only, clean-tree precondition, no commit) and then stop. Without `--fix`, QUICK ends at the report — change nothing.

---

## DEEP execution

If Step 0.5 selected DEEP, continue with the steps below. This is the comprehensive pipeline.

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
- The **Universal reporting rules (all agents)** and **Scratch programs** sections from agent-instructions.md, prepended verbatim

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

The Step 0.5 router output carries `gated`: specialists with 0 findings across 10+ dispatches in `context/review-stats.json` (security is never gated). Do not read or edit that file yourself.

- Skip each gated specialist and print: `[specialist] auto-gated (0 findings in N reviews)`, with N from its `dispatched`.
- Override: `--all-specialists` flag forces all specialists regardless of gating.

After the review completes, record the counts as in Step 7d.

---

### Full mode — module-based agents:

1. Launch **1 Explore agent per module** (capped at 6) covering all 4 concern areas within that module. Use the "Module Agent" prompt from agent-instructions.md.
2. Once the module agents have reported — or their deadline has passed, per the fan-in protocol in Step 3.9 — launch a **Cross-Module Agent** to check inter-module concerns. Do not block indefinitely on a module agent that never reports; proceed with the modules you have and mark the missing one `unavailable — did not report`.

## Step 3.5: Codex CLI Review (optional, parallel)

Load `${CLAUDE_SKILL_DIR}/codex-pass.md` and follow it. It covers running the pass with `ccm-external-review` and acting on the status it reports.

In short: run `"${CLAUDE_SKILL_DIR}/../../bin/ccm-external-review" --tools codex --dimensions adversarial` (bare name `ccm-external-review` also works; plugin `bin/` is on `PATH`) in the background alongside the Step 3 agents in an interactive run, or in the foreground with a 600000 ms timeout when running autonomously. The script checks availability, bounds the pass with `timeout --kill-after=30 300`, and classifies it by exit status; act on its `status` rather than re-deriving it. Codex is additive and never blocking — every failure mode continues the review with Explore agent findings only.

---

## Step 3.9: Collect agent results (fan-in)

Load `${CLAUDE_SKILL_DIR}/fan-in-protocol.md` and follow it at **every** fan-out in this skill — Step 3 (both modes), Step 3.5, and Step 5c.

In short: stamp a deadline when you dispatch a batch, not when you start to worry. When it expires, produce the report with whatever arrived and mark the rest `unavailable — did not report`. The deadline is absolute, never conditional on a majority having reported. While waiting, never poll with no-op commands, never `SendMessage` a completed agent, and never invent a missing agent's findings.

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
- Attempts to construct concrete triggering scenario, and for a security or invariant finding records the inputs and any fuzz or enumeration approach in `reproduction` (see `triage-instructions.md`)
- Returns verdict: **CONFIRMED** / **MITIGATED** / **FALSE_POSITIVE**
- Runs any scratch program under the limits in `## Scratch programs` of `agent-instructions.md` (60-second `timeout`, smallest input, cite rather than re-measure); pass it the measurements already in the finding

This is a fan-out like any other — apply the Step 3.9 collection protocol here too, with its own deadline stamped at dispatch. A verification agent that never reports must not hold the report hostage.

### 5d. Process verdicts
- CONFIRMED → keep with "[Verified]" tag; if the verifier returned a `reproduction`, put it on the finding
- MITIGATED → downgrade severity by one level, note the mitigation
- FALSE_POSITIVE → move to Dismissed Findings section
- **No verdict (agent did not report before the deadline)** → keep the finding at its original severity, tagged `[Unverified — verification agent did not report]`. Never silently drop a Critical/High finding because its verifier went missing, and never promote an unverified finding to `[Verified]`.

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
- **Coverage**: list any dimension that did not report as `unavailable — did not report`, and Codex as `findings | completed — 0 findings | timed out | unparseable | unavailable | auth failed | failed (exit N)`. If everything ran, say `full`. Never leave a dimension unlisted — an omission reads as "came back clean".
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
> **Reproduction**: [the finding's `reproduction` field, verbatim: invariant, triggering inputs, fuzz or enumeration approach; omit the line when absent]
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

## Fixes Applied ({count}) — only when `--fix` was passed
[Working-tree edits made under Step 7a. Omit this section entirely when `--fix` was not passed. Never list commit hashes here — this skill does not commit.]
> `src/handlers/user.ts:42` FINDING-003 — added the missing null check on `session.user`
> `src/orders/list.ts:88` FINDING-007 — batched the per-order lookup into one query
>
> Uncommitted. Review with `git diff`, then commit with `/ccmagic:push` or your own commit.

## Positive Findings
[Well-implemented patterns, good practices observed]

## Specialist Report
[Which specialists ran, which were skipped (scope), which were gated (0 findings in N+ reviews)]

## Overall Assessment
[Quality rating, key risks, actionable recommendation]
```

## Step 7: Follow-up

**Default (no `--fix`): steps 7a and 7b do not run.** The report is the deliverable. Go straight to 7c and 7d, make no code changes, and do not offer to apply the fixes — the user asks for `--fix` when they want them applied.

### 7a. Apply mechanical fixes — `--fix` only

Skip this step entirely unless `--fix` was passed.

Preconditions, both required:
- `--fix` present in `$ARGUMENTS`.
- Working tree clean — run `git status --porcelain` before touching any file. If it returns anything, apply nothing and say so: mixing your edits into the user's uncommitted work makes the two indistinguishable.

For findings marked `fixable: true` by triage (see triage-instructions.md Step 7):
- Apply each fix directly in source code with `Edit`
- Prefer minimal changes — one fix per finding
- Output per fix: `[FIXED] file:line — issue → what was changed`

**Stop at the working tree.** Do not `git add`, do not `git commit`, do not `git push`, do not open or update a PR. Close with:

```
N fixes applied to the working tree, uncommitted. Review with `git diff`, then commit when you're satisfied.
```

### 7b. Batch-ask about judgment calls — `--fix` only

Skip this step entirely unless `--fix` was passed. Without `--fix`, judgment-call findings are reported in Step 6 and tracked in 7c; do not open an `AskUserQuestion` about fixing them.

For findings marked `fixable: false`, present via a single `AskUserQuestion`:

```
I fixed N issues in the working tree. M need your input:

1. [HIGH] file:line — issue description
   Suggested fix: what to change
   → A) Fix  B) Skip

2. [MEDIUM] file:line — issue description
   Suggested fix: what to change
   → A) Fix  B) Skip

RECOMMENDATION: Fix #1 because [reason]. Skip #2 because [reason].
```

Apply fixes for items where the user chose "Fix." These also stay uncommitted.

If 0 fixable findings exist, skip 7a. If 0 judgment-call findings exist, skip 7b.

### 7c. Track remaining findings

Create **TodoWrite** entries for all remaining (unfixed) findings, grouped by severity then by file:
- Critical/High: one todo per finding
- Medium: group related findings per file into one todo
- Low/Convention: one summary todo per category

### 7d. Update review stats

If conditional specialists were dispatched, record one entry per dispatched specialist with its finding count, for example `"${CLAUDE_SKILL_DIR}/../../bin/ccm-review-route" --record testing=3,performance=0`. The script adds 1 dispatch and the findings to `context/review-stats.json`. Skip this when no specialist was dispatched.

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

This skill runs inline, so its report is the message the user reads. When another skill invoked it (`/ccmagic:review-ticket`, `/ccmagic:work-ticket`), the report goes back to that skill, which continues with its next step.

**End state:** a report. Without `--fix`, the repository is byte-for-byte unchanged when you finish. With `--fix`, the working tree carries the fixes and nothing is staged, committed, pushed, or turned into a PR. Committing and pushing belong to `/ccmagic:push`; merging belongs to `/ccmagic:merge`. A review that lands its own changes has destroyed the thing that makes it a review — an independent read of work someone else decided to keep.
