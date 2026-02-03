---
allowed-tools: Read(*), Bash(*), Glob(*), Task(*), TodoWrite(*), AskUserQuestion(*)
description: Use Codex CLI for review, then Claude triages findings and plans fixes
argument-hint: "[branch|full] [--model MODEL]"
model: sonnet
---

# Codex Review Command

Use OpenAI's Codex CLI to review code, then have Claude triage the findings and create an actionable fix plan.

## Arguments

$ARGUMENTS

**Scope options:**
- `branch` (default) - Review changes on current branch vs main
- `full` - Review the entire codebase
- `PR#` or just a number - Review a specific PR

**Optional flags:**
- `--model MODEL` - Specify Codex model (e.g., `--model o3`, `--model o4-mini`)

## Process

### Step 1: Verify Codex Installation

```bash
# Check if codex CLI is available
which codex || command -v codex
codex --version 2>/dev/null || echo "NOT_INSTALLED"
```

If Codex is not installed, inform the user:
```
Codex CLI is not installed. Install it with:
  npm install -g @openai/codex

Or see: https://github.com/openai/codex

Falling back to Claude-only review...
```

If not installed, fall back to running `/ccmagic:review` instead.

### Step 2: Determine Review Scope

Based on arguments:

**For `branch` (default):**
```bash
# Get the diff for Codex to review
git diff main...HEAD > /tmp/codex-review-diff.txt
git diff --name-only main...HEAD
```

**For `full`:**
```bash
# List all source files for full codebase review
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" -o -name "*.rb" -o -name "*.swift" -o -name "*.kt" \) -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/dist/*" -not -path "*/build/*" -not -path "*/__pycache__/*" -not -path "*/vendor/*" -not -path "*/target/*" > /tmp/codex-review-files.txt
```

**For PR number:**
```bash
gh pr diff {PR_NUMBER} > /tmp/codex-review-diff.txt
gh pr view {PR_NUMBER} --json title,body
```

### Step 3: Run Codex Review

Execute Codex with a focused review prompt. Capture output to a file for Claude to analyze.

**For branch/PR changes:**
```bash
codex --model ${MODEL:-o4-mini} --approval-mode full-auto "Review these code changes for bugs, security issues, performance problems, and code quality. Be specific about file:line locations. Focus on:
1. Bugs and logic errors
2. Security vulnerabilities (injection, XSS, auth issues)
3. Performance concerns
4. Error handling gaps
5. Code quality issues

Here are the changes:
$(cat /tmp/codex-review-diff.txt)" 2>&1 | tee /tmp/codex-review-output.txt
```

**For full codebase:**
```bash
codex --model ${MODEL:-o4-mini} --approval-mode full-auto "Review this codebase for architectural issues, code quality problems, security vulnerabilities, and areas needing improvement. Focus on:
1. Architectural concerns and design issues
2. Security vulnerabilities
3. Code duplication and DRY violations
4. Missing error handling
5. Performance anti-patterns
6. Dead code or unused exports

Review the following files:
$(cat /tmp/codex-review-files.txt | head -100)" 2>&1 | tee /tmp/codex-review-output.txt
```

### Step 4: Claude Triage of Codex Findings

Read the Codex output and perform critical analysis:

```bash
cat /tmp/codex-review-output.txt
```

For each finding from Codex, evaluate:

1. **Validity** - Is this a real issue?
   - Read the actual code to verify the concern
   - Check if it's already handled elsewhere
   - Determine if it's a false positive

2. **Severity Classification:**
   - **Critical** - Security vulnerabilities, data loss risks, crashes
   - **High** - Bugs affecting functionality, missing error handling
   - **Medium** - Code quality, performance concerns, maintainability
   - **Low** - Style issues, minor improvements, nice-to-haves
   - **Invalid** - False positives, already addressed, not applicable

3. **Actionability** - Can this be fixed in this PR/session?

### Step 5: Verification Deep Dive

For Critical and High severity items, use Task agents to verify:

```
Launch parallel Explore agents to:
1. Verify each Critical/High finding by reading the actual code
2. Check if the issue is already mitigated elsewhere
3. Understand the full context of the flagged code
```

### Step 6: Create Fix Plan

For valid findings that should be addressed:

1. Group by file to minimize context switching
2. Order by severity (Critical > High > Medium > Low)
3. Create TodoWrite entries with specific fix instructions
4. Note any findings that require design decisions

### Step 7: Handle Disputed Findings

For findings Claude disagrees with, use AskUserQuestion:
- Present the Codex finding
- Explain Claude's assessment
- Ask user to decide: Fix, Defer, or Dismiss

## Output Format

```markdown
# Codex Review Analysis

## Review Summary
- **Scope**: [branch changes | full codebase | PR #X]
- **Model Used**: [codex model]
- **Files Analyzed**: [count]
- **Total Findings**: [count]
- **Valid Findings**: [count]
- **False Positives**: [count]

## Findings by Severity

### Critical ({count})
| Finding | Location | Codex Says | Claude's Assessment | Action |
|---------|----------|------------|---------------------|--------|
| [issue] | file:line | [codex note] | [validation] | [fix plan] |

### High ({count})
| Finding | Location | Codex Says | Claude's Assessment | Action |
|---------|----------|------------|---------------------|--------|

### Medium ({count})
| Finding | Location | Codex Says | Claude's Assessment | Action |
|---------|----------|------------|---------------------|--------|

### Low ({count})
| Finding | Location | Codex Says | Claude's Assessment | Action |
|---------|----------|------------|---------------------|--------|

### Dismissed ({count})
| Finding | Location | Reason for Dismissal |
|---------|----------|---------------------|
| [issue] | file:line | [why invalid/already handled] |

## Recommended Actions

### Immediate Fixes (this session)
1. [Specific fix with file:line]
2. [Specific fix with file:line]

### Deferred Items
- [Item requiring design discussion]
- [Item out of current scope]

## Codex Raw Output
<details>
<summary>Full Codex output (click to expand)</summary>

[raw codex output]

</details>
```

## Execution

1. Check for Codex installation immediately
2. If not installed, ask user if they want to:
   - Install Codex now (`npm install -g @openai/codex`)
   - Fall back to Claude-only review (`/ccmagic:review`)
   - Cancel
3. Run Codex review with appropriate scope
4. Parse and triage all findings
5. Verify Critical/High items by reading actual code
6. Present categorized findings with Claude's assessment
7. Create TodoWrite entries for approved fixes
8. Ask about disputed findings before proceeding

**Key principle:** Codex provides broad coverage, Claude provides judgment. Not every Codex finding is valid—Claude's job is to separate signal from noise and create an actionable plan.
