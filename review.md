# Code Review Command

Perform a comprehensive code review of all changes on the current working branch compared to the main branch.

## Review Process

1. First, check if zen MCP tools are available
2. If zen tools are available, use `mcp__zen__codereview` with model `o3` or `gemini-2.5-pro` for thorough analysis
3. If zen tools are not available, perform deep analysis using available tools

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

1. **Gather Changes**: Run `git diff main...HEAD` to see all changes
2. **Identify Modified Files**: Run `git diff --name-only main...HEAD`
3. **Analyze Each File**: 
   - If zen tools available: Use `mcp__zen__codereview` with:
     ```
     model: "o3" or "gemini-2.5-pro"
     review_type: "full"
     severity_filter: "all"
     relevant_files: [list of changed files]
     ```
   - Otherwise: Read each file and perform manual analysis with deep thinking
4. **Categorize Issues**: Group findings by severity (Critical, High, Medium, Low)
5. **Provide Recommendations**: Offer specific, actionable improvements

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