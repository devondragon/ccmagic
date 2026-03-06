---
allowed-tools: Read(*), Bash(git:*, gh:*), Glob(*), Task(*), TodoWrite(*), AskUserQuestion(*)
description: Review PR comments and plan fixes for valid concerns
model: sonnet
---

# PR Feedback Command

Review comments on the current PR and create an actionable plan to address valid concerns.

## Arguments

$ARGUMENTS

If a PR number is provided, use it. Otherwise, detect the PR for the current branch.

## Process

### Step 1: Identify the PR

```bash
# If no PR number provided, get PR for current branch
gh pr view --json number,url,title --jq '.number'
```

### Step 2: Fetch All Comments

Retrieve all review comments, including:
- Review comments (line-level feedback)
- PR conversation comments
- Review summaries

```bash
# Get review comments
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --jq '.[] | {id, body, path, line, user: .user.login, created_at, in_reply_to_id}'

# Get PR conversation comments
gh api repos/{owner}/{repo}/issues/{pr_number}/comments --jq '.[] | {id, body, user: .user.login, created_at}'

# Get reviews with their state
gh pr view {pr_number} --json reviews --jq '.reviews[] | {author: .author.login, state, body}'
```

### Step 3: Categorize Comments

**Default bias: Address Now.** If a comment identifies a legitimate improvement, fix it in this PR. Non-blocking does not mean defer—clean PRs ship better code.

Analyze each comment and categorize into:

1. **Address Now** - The default for valid feedback. Includes:
   - Bug fixes, security issues, logic errors
   - Missing error handling or edge cases
   - Code clarity and readability improvements
   - Style/convention violations
   - Test coverage gaps or missing test cases
   - Refactoring to reduce code duplication (DRY violations)
   - Naming improvements
   - Documentation gaps for complex logic
   - Performance fixes that are straightforward
   - Any improvement that can be done in under ~30 minutes

2. **Defer** - Only for changes that genuinely don't belong in this PR:
   - Refactoring that would touch many files unrelated to this PR
   - New features beyond the PR's stated scope
   - Architectural changes requiring design discussion
   - Performance work needing benchmarking/profiling first
   - Changes that would significantly delay the PR with no clear end

3. **Decline** - Comments that don't require action:
   - Already addressed in the code
   - Based on misunderstanding of the code/requirements
   - Pure style preferences not backed by project conventions
   - Suggestions that would make the code worse

### Step 4: Create Fix Plan

For "Address Now" items:
1. Group related comments by file/area
2. Create a prioritized todo list using TodoWrite
3. Order by: blocking issues first, then by file to minimize context switching

### Step 5: Handle Deferred Items

For each "Defer" item, use AskUserQuestion to confirm the approach:
- Create a new issue/ticket
- Add to backlog
- Address in this PR anyway
- Dismiss with explanation

## Output Format

```markdown
## PR Comment Review: #{pr_number}

### Will Address Now ({count})
| Comment | File | Action |
|---------|------|--------|
| [summary] | [path:line] | [planned fix] |

### Recommend Deferring ({count})
| Comment | Reason | Suggested Action |
|---------|--------|------------------|
| [summary] | [why defer] | [create issue/backlog/etc] |

### No Action Needed ({count})
| Comment | Reason |
|---------|--------|
| [summary] | [why no action] |
```

## Execution

Begin immediately:
1. Fetch the PR and all comments
2. Read relevant code files to understand context
3. Categorize each comment—when in doubt, Address Now
4. Present the categorization and plan
5. For deferred items, ask user preference before proceeding
6. Create TodoWrite entries for approved fixes

**Bias toward action.** Reviewers took time to leave feedback—respect that by fixing legitimate issues rather than punting them. A PR that addresses all reasonable feedback ships cleaner code and builds reviewer trust. Only defer when the work truly doesn't fit this PR's scope.
