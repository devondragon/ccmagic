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

Analyze each comment and categorize into:

1. **Address Now** - Valid concerns that should be fixed in this PR:
   - Bug fixes
   - Security issues
   - Logic errors
   - Missing error handling
   - Code clarity improvements
   - Style/convention violations
   - Test coverage gaps

2. **Defer** - Valid concerns better handled separately:
   - Large refactoring suggestions
   - Feature additions beyond scope
   - Architectural changes
   - Performance optimizations requiring significant work
   - Items needing discussion or design decisions

3. **Decline** - Comments that don't require action:
   - Already addressed
   - Based on misunderstanding
   - Style preferences without project convention backing
   - Out of scope for this change

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
3. Categorize each comment with clear reasoning
4. Present the categorization and plan
5. For deferred items, ask user preference before proceeding
6. Create TodoWrite entries for approved fixes

Be thorough in analysis but decisive in categorization. Default to addressing valid feedback unless there's a clear reason to defer.
