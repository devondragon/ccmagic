---
user-invocable: true
allowed-tools: Read(*), Bash(git:*, gh:*), Glob(*), Grep(*), Task(*), TodoWrite(*), AskUserQuestion(*), Edit(*)
description: Review PR comments and plan fixes for valid concerns
model: sonnet
argument-hint: "[PR#]"
---

# PR Feedback Command

Review comments on a pull request, verify each against the actual code, and create a grouped fix plan for valid concerns.

> **Philosophy:** Bias toward action. Reviewers took time to leave feedback — respect that by fixing legitimate issues rather than punting them. But never blindly accept or reject: read the code first.

## Step 0: Parse Arguments

$ARGUMENTS

If a PR number is provided, use it. Otherwise, detect the PR for the current branch:
```bash
gh pr view --json number,url,title,baseRefName --jq '{number, url, title, baseRefName}'
```

If no PR is found, stop with: "No PR found for the current branch. Provide a PR number or push your branch first."

Store `{PR_NUMBER}`, `{PR_URL}`, `{PR_TITLE}`, and `{BASE_BRANCH}` for later use.

## Step 1: Load Project Conventions

Read these files if they exist (silent skip if missing):
1. `CLAUDE.md` in project root
2. `.claude/CLAUDE.md`
3. `context/conventions.md`

Collect into `{PROJECT_CONVENTIONS}`. These are used in Step 4 to evaluate whether reviewer suggestions align with or contradict project rules.

## Step 2: Fetch PR Comments and Threads

Retrieve all feedback in three categories:

```bash
# Review comments (line-level) — includes thread structure via in_reply_to_id
gh api repos/{owner}/{repo}/pulls/{PR_NUMBER}/comments \
  --jq '.[] | {id, body, path, line, original_line, diff_hunk, user: .user.login, created_at, updated_at, in_reply_to_id}'

# PR conversation comments (general discussion)
gh api repos/{owner}/{repo}/issues/{PR_NUMBER}/comments \
  --jq '.[] | {id, body, user: .user.login, created_at}'

# Reviews with state (APPROVED, CHANGES_REQUESTED, COMMENTED)
gh pr view {PR_NUMBER} --json reviews \
  --jq '.reviews[] | {author: .author.login, state, body}'
```

### Thread Reconstruction

Group line-level comments into threads using `in_reply_to_id`:
- A root comment (no `in_reply_to_id`) starts a thread
- Replies chain onto the root
- Read the **full thread** before evaluating any comment in it — earlier replies may already address the concern or provide context that changes the meaning

### Identify the PR Author

```bash
gh pr view {PR_NUMBER} --json author --jq '.author.login'
```

Filter out the PR author's own comments from the triage list (they are context, not feedback to address). Keep them visible in threads for context.

## Step 3: Classify Comment Severity

Load `${CLAUDE_SKILL_DIR}/triage-guide.md` for detailed classification criteria.

Assign each reviewer comment a severity level:

| Severity | Meaning | Action required |
|----------|---------|----------------|
| **must-fix** | Blocking — bugs, security, data loss, broken API contract | Fix before merge |
| **should-fix** | Valid improvement — error handling, edge cases, clarity, naming, test gaps | Fix in this PR (default for valid feedback) |
| **style/preference** | Optional — subjective style, alternative approaches, taste | Fix only if project conventions agree |
| **question** | Needs response only — reviewer asks for clarification | Reply, no code change |

**Default bias: should-fix.** When uncertain whether feedback is valid, classify as should-fix. Only downgrade after verification in Step 4.

## Step 4: Verify Each Comment Against Code

This is the critical step. For every comment classified must-fix, should-fix, or style/preference:

### 4a. Read the Actual Code

Read the file and surrounding context at the location the reviewer referenced. Do not rely solely on the diff hunk in the comment — read the full function/block.

### 4b. Check Reviewer's Claim

- **Is the concern factually accurate?** Does the code actually do what the reviewer claims?
- **Is it already handled?** Check callers, error boundaries, middleware, guards, try/catch blocks
- **Is there a test covering this?** Search for test files that exercise the flagged code path
- **Does the project convention agree?** Check `{PROJECT_CONVENTIONS}` — if the reviewer suggests a pattern and the project explicitly uses a different one, the convention wins

### 4c. Assign Final Verdict

After verification, each comment gets one of:

| Verdict | Meaning |
|---------|---------|
| **address-now** | Valid, fix in this PR |
| **defer** | Valid but out of scope — would touch unrelated files, needs design discussion, or requires benchmarking |
| **decline** | Invalid — already handled, based on misunderstanding, contradicts conventions, or would make code worse |
| **respond** | No code change needed — answer the reviewer's question |

### 4d. Detect Conflicting Reviewer Feedback

When two reviewers give contradictory feedback on the same code (e.g., reviewer A says "add error handling here" and reviewer B says "this error handling is unnecessary"):

1. Present both positions clearly
2. Note which aligns with project conventions (if applicable)
3. Use `AskUserQuestion` to let the user decide:
   > **Conflicting feedback on `{file}:{line}`**
   > - **{reviewer_a}**: {summary of position A}
   > - **{reviewer_b}**: {summary of position B}
   > - **Convention alignment**: {which side conventions support, or "no convention applies"}
   > Choose: **A** | **B** | **Skip both**

## Step 5: Group Fixes by File

Batch all address-now comments that touch the same file or concern area. This minimizes context switching during implementation.

### Grouping Rules

1. **Same file** — comments on different lines of the same file become one fix group
2. **Same concern across files** — if multiple comments flag the same pattern (e.g., "add input validation" in 3 different handlers), group them as a single concern
3. **Dependent fixes** — if fixing comment A requires also changing code referenced by comment B, group them

### Priority Ordering

Within each group, order by:
1. must-fix items first
2. should-fix items second
3. style/preference items last

Across groups, order by:
1. Groups containing must-fix items
2. Groups with the most comments (highest reviewer concern density)
3. Remaining groups by file path (alphabetical for predictability)

## Step 6: Create Fix Plan with TodoWrite

Create structured TodoWrite entries for all address-now items, grouped by file:

**For must-fix and should-fix items:**
- One todo per fix group (file-level granularity)
- Format: `PR #{PR_NUMBER}: {file} — {summary of fixes}`
- Include the specific line numbers and what to change

**For style/preference items (approved):**
- One summary todo grouping all style fixes
- Format: `PR #{PR_NUMBER}: Style fixes — {count} items`

**For respond items:**
- One todo for all responses needed
- Format: `PR #{PR_NUMBER}: Reply to {count} reviewer questions`

**For defer items:**
- Ask user preference via `AskUserQuestion` before creating todos:
  > **{count} comments marked for deferral:**
  > {list with one-line summaries}
  > For each: **Create issue** | **Add to backlog** | **Address in this PR anyway** | **Dismiss**

## Step 7: Present Report

```markdown
## PR Comment Triage: #{PR_NUMBER} — {PR_TITLE}

**Comments analyzed**: {total} from {reviewer_count} reviewers
**Convention sources**: {files loaded, or "none found"}

### Must-Fix ({count}) — Blocking
| # | File:Line | Reviewer | Issue | Planned Fix |
|---|-----------|----------|-------|-------------|
| 1 | `path:line` | @user | summary | what to change |

### Should-Fix ({count}) — Valid, Non-Blocking
| # | File:Line | Reviewer | Issue | Planned Fix |
|---|-----------|----------|-------|-------------|

### Style/Preference ({count}) — Optional
| # | File:Line | Reviewer | Issue | Convention Says |
|---|-----------|----------|-------|-----------------|

### Questions to Answer ({count})
| # | Reviewer | Question | Suggested Response |
|---|----------|----------|--------------------|

### Declined ({count}) — No Action
| # | File:Line | Reviewer | Comment | Reason |
|---|-----------|----------|---------|--------|

### Deferred ({count}) — Out of Scope
| # | File:Line | Reviewer | Comment | Reason |
|---|-----------|----------|---------|--------|

### Fix Groups (Implementation Order)
1. **{file}** — {count} fixes: {one-line summary}
2. **{file}** — {count} fixes: {one-line summary}
...
```

## Step 8: Post-Fix Validation

After presenting the plan, suggest validation steps:

> **Recommended next steps after implementing fixes:**
> 1. `/ccmagic:validate` — Run pre-commit checks to catch regressions
> 2. `/ccmagic:test` — Run tests to verify fixes don't break existing behavior
> 3. `gh pr view {PR_NUMBER} --comments` — Review to confirm all threads addressed

## Execution

Begin immediately when invoked:

1. **Fetch** — Get the PR, all comments, and review state
2. **Load conventions** — Read project convention files
3. **Reconstruct threads** — Group comments into conversation threads
4. **Classify** — Assign severity to each comment (must-fix / should-fix / style / question)
5. **Verify** — Read actual code for every actionable comment. Check if the concern is valid, already handled, or contradicts conventions
6. **Detect conflicts** — Flag contradictory reviewer feedback and ask user to decide
7. **Group** — Batch verified fixes by file for efficient implementation
8. **Plan** — Create TodoWrite entries grouped by file
9. **Report** — Present the full triage with fix groups
10. **Suggest validation** — Recommend post-fix checks

**Bias toward action.** Reviewers took time to leave feedback — respect that by fixing legitimate issues rather than punting them. A PR that addresses all reasonable feedback ships cleaner code and builds reviewer trust. Only defer when the work truly doesn't fit this PR's scope. But always verify first: read the code, check the conventions, and confirm the concern is real before committing to a fix.
