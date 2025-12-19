---
allowed-tools: Read(*), Bash(git:*), Glob(*), Task(*), TodoWrite(*), mcp__zen__codereview(*), mcp__pal__codereview(*)
description: Comprehensive code review using parallel exploration and expert analysis
model: sonnet
---

# Code Review Command

Perform a comprehensive code review of all changes on the current working branch compared to the main branch.

## Review Process

### Step 1: Parallel Exploration (Recommended)
Use the Task tool with multiple Explore agents to analyze changes in parallel:

```
Launch THREE parallel Task calls with subagent_type: "Explore":

1. Agent 1 - Code Quality Analysis:
   "Analyze code quality of changed files: naming, structure, DRY, SOLID principles.
    Files: [list from git diff --name-only]"

2. Agent 2 - Security & Performance:
   "Analyze changed files for security vulnerabilities (XSS, injection, auth issues)
    and performance concerns (N+1 queries, memory leaks, algorithm efficiency)."

3. Agent 3 - Architecture & Integration:
   "Analyze how changes integrate with existing codebase: breaking changes,
    API consistency, module coupling, test coverage."
```

### Step 2: Expert Analysis (if MCP tools available)
**Priority order (use first available):**
1. `mcp__zen__codereview` with model `o3` or `gemini-2.5-pro`
2. `mcp__pal__codereview` with model `gemini-2.5-pro`
3. If no MCP tools: synthesize findings from Explore agents above

### Step 3: Report Generation
Combine all findings into structured report (see Output Format below)

## Review Scope

Analyze the following aspects of the code changes:

### 1. Code Quality
- Code clarity and readability
- Proper naming conventions
- Code organization and structure
- DRY (Don't Repeat Yourself) violations
- SOLID principles adherence
- Over-engineering or unnecessary complexity

### 2. Performance
- Algorithm efficiency
- Database query optimization
- Memory usage patterns
- Potential performance bottlenecks
- Caching opportunities

### 3. Security
- Input validation and sanitization
- Authentication and authorization checks
- SQL injection vulnerabilities
- XSS vulnerabilities
- Sensitive data exposure
- Security best practices

### 4. Coding Standards
- Consistency with existing codebase style
- Proper use of language idioms
- Documentation completeness
- Test coverage
- Error handling

### 5. Architecture & Design
- Design pattern appropriateness
- Module coupling and cohesion
- API design consistency
- Scalability considerations
- Maintainability

## Implementation Steps

### 1. Gather Changes (run in parallel):
```bash
# These commands can run simultaneously
git diff main...HEAD                    # Full diff
git diff --name-only main...HEAD        # File list
git diff --stat main...HEAD             # Statistics
```

### 2. Launch Parallel Analysis
Use the Task tool to launch multiple Explore agents simultaneously:

```
# Send a SINGLE message with THREE Task tool calls:

Task 1: {
  subagent_type: "Explore",
  prompt: "Review code quality: [file list]. Check naming, structure, DRY, SOLID."
}

Task 2: {
  subagent_type: "Explore",
  prompt: "Security & performance review: [file list]. Check OWASP top 10, efficiency."
}

Task 3: {
  subagent_type: "Explore",
  prompt: "Architecture review: [file list]. Check integration, breaking changes, tests."
}
```

### 3. Expert Validation (Optional - use if available)
**If MCP tools available:**
- `mcp__zen__codereview`: Full analysis with external model
- `mcp__pal__codereview`: Alternative with comprehensive validation

```
mcp__zen__codereview or mcp__pal__codereview with:
  model: "gemini-2.5-pro" or "o3"
  review_type: "full"
  severity_filter: "all"
  relevant_files: [list of changed files]
```

**If no MCP tools:** Synthesize findings from Explore agents with standard analysis.

### 4. Categorize & Report
- Group findings by severity (Critical, High, Medium, Low)
- Provide specific, actionable recommendations
- Use TodoWrite to track issues that need fixing

## Output Format

Structure the review as follows:

```markdown
# Code Review Report

## Summary
- Branch: [current branch]
- Files Changed: [count]
- Lines Added/Removed: [+X/-Y]

## Critical Issues
[List any critical issues that must be fixed]

## High Priority Issues
[List high priority issues that should be fixed]

## Medium Priority Issues
[List medium priority improvements]

## Low Priority / Suggestions
[List minor improvements and suggestions]

## Positive Findings
[Highlight well-implemented features and good practices]

## Overall Assessment
[Provide overall quality rating and recommendations]
```

## Execution

When this command is invoked, immediately begin the review process without asking for confirmation. Be thorough but concise in the findings. Focus on actionable feedback that improves code quality, security, and maintainability.