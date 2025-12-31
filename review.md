---
allowed-tools: Read(*), Bash(git:*), Glob(*), Task(*), TodoWrite(*), mcp__zen__codereview(*), mcp__pal__codereview(*)
description: Comprehensive code review using parallel exploration and expert analysis
model: sonnet
---

# Code Review Command

Perform a comprehensive code review of all changes on the current working branch compared to the main branch.

## Review Process

> **Parallel execution:** When operations are independent, run them simultaneously—exploring different code areas, reading unrelated files, or analyzing separate concerns. Claude Code will determine when this is safe and helpful.

### Step 1: Gather Changes and Analyze
1. Get changed files with `git diff --name-only main...HEAD`
2. Launch parallel Explore agents for independent analysis:
   - Code quality (naming, structure, DRY, SOLID)
   - Security & performance (OWASP, efficiency, memory)
   - Architecture & integration (breaking changes, tests)

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

### 1. Gather Changes
```bash
git diff --name-only main...HEAD        # File list
git diff --stat main...HEAD             # Statistics
```

### 2. Analyze and Report
- Launch parallel Explore agents for independent analysis (see Step 1 above)
- Use MCP tools if available for expert validation
- Group findings by severity (Critical, High, Medium, Low)
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