---
allowed-tools: Read(*), Bash(git:*), Glob(*), Grep(*), Task(*), TodoWrite(*), mcp__pal__analyze(*)
description: Analyze blast radius and dependencies for a file or feature
argument-hint: [file-path or feature-name]
model: claude-sonnet-4-20250514
---

# Analyze Impact Command

Analyze the blast radius and dependencies for a specific file, feature, or set of changes. Helps understand what might break before making changes.

## Arguments

**$ARGUMENTS**

If no argument provided, analyze currently staged or uncommitted changes.

## Implementation

### Step 1: Identify Target

Determine what to analyze:
- If file path provided: Analyze that specific file
- If feature name provided: Find related files in `context/features/`
- If no argument: Analyze `git diff --name-only` (uncommitted changes)

### Step 2: Parallel Dependency Analysis

Use the Task tool to launch multiple Explore agents simultaneously:

```
# Send a SINGLE message with THREE parallel Task calls:

Task 1: {
  subagent_type: "Explore",
  prompt: "Find all files that IMPORT or DEPEND ON [target files].
           Trace the dependency graph outward. List all affected files."
}

Task 2: {
  subagent_type: "Explore",
  prompt: "Find all files that [target files] IMPORT or DEPEND ON.
           Trace the dependency graph inward. Identify core dependencies."
}

Task 3: {
  subagent_type: "Explore",
  prompt: "Find all TESTS that cover [target files].
           Identify test files, test functions, and coverage areas."
}
```

### Step 3: Expert Analysis (if MCP tools available)

If `mcp__pal__analyze` is available:
```
mcp__pal__analyze with:
  analysis_type: "architecture"
  relevant_files: [target files and dependencies]
  step: "Analyze impact and blast radius of changes to these files"
```

### Step 4: Generate Impact Report

## Impact Report Format

```markdown
# Impact Analysis Report
**Target**: [file/feature being analyzed]
**Generated**: [timestamp]

## Summary
- **Direct Dependencies**: X files depend on this
- **Indirect Dependencies**: Y files affected transitively
- **Test Coverage**: Z test files cover this code
- **Risk Level**: [Low/Medium/High/Critical]

## Dependency Graph

### Files That Import This (Dependents)
Files that will break if this file's exports change:

| File | Import Type | Risk |
|------|-------------|------|
| `src/components/UserProfile.tsx` | Named import: `useAuth` | High |
| `src/pages/Login.tsx` | Default import | Medium |

### Files This Imports (Dependencies)
Files that this code relies on:

| File | Import Type | Stability |
|------|-------------|-----------|
| `src/utils/api.ts` | Named import | Stable |
| `src/types/user.ts` | Type import | Stable |

## Test Coverage

### Direct Tests
Tests that specifically test this file:
- `tests/auth/useAuth.test.ts` - 15 test cases
- `tests/integration/auth.test.ts` - 8 test cases

### Indirect Tests
Tests that exercise this code through other paths:
- `tests/e2e/login.test.ts` - Uses auth flow

### Coverage Gaps
Areas with insufficient test coverage:
- Error handling in `refreshToken()`
- Edge case: expired session

## Breaking Change Analysis

### Public API Surface
Exports that other files depend on:
```typescript
export function useAuth(): AuthContext  // 12 dependents
export type AuthState = {...}           // 8 dependents
export const AUTH_EVENTS = {...}        // 3 dependents
```

### Safe Changes
These modifications are unlikely to break dependents:
- Internal implementation changes
- Adding new exports
- Performance optimizations

### Risky Changes
These modifications may break dependents:
- Changing function signatures
- Modifying return types
- Removing or renaming exports

## Recommendations

### Before Making Changes:
1. [ ] Run affected tests: `npm test -- --grep "auth"`
2. [ ] Review all dependent files listed above
3. [ ] Consider feature flag for breaking changes
4. [ ] Update types if changing API surface

### After Making Changes:
1. [ ] Run full test suite
2. [ ] Check for TypeScript errors in dependents
3. [ ] Update documentation if API changed
4. [ ] Consider deprecation warnings for removed APIs

## Related Context Files
- Feature: `context/features/001-02-authentication/`
- Architecture: `context/knowledge/architecture.md`
- API Contracts: `context/knowledge/api-contracts.md`
```

## Quick Analysis Mode

For quick checks, run a simplified analysis:

```bash
# Find direct imports (grep-based, fast)
grep -r "from.*[target-file]" --include="*.ts" --include="*.tsx" --include="*.js"

# Find test files
find . -name "*.test.*" -o -name "*.spec.*" | xargs grep -l "[target-name]"
```

## Integration Points

- **Before refactoring**: Understand what might break
- **Before deleting code**: Ensure nothing depends on it
- **Planning features**: Understand integration complexity
- **Code review**: Assess change risk

## Usage Examples

```bash
# Analyze a specific file
/ccmagic:analyze-impact src/auth/useAuth.ts

# Analyze a feature
/ccmagic:analyze-impact authentication

# Analyze current changes
/ccmagic:analyze-impact
```

## Execution

Begin analysis immediately. Use parallel Explore agents for efficiency. Focus on actionable insights that help developers understand change risk before modifying code.
