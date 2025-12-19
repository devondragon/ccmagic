---
allowed-tools: Read(*), Bash(*), Glob(*), Task(*), TodoWrite(*)
description: Comprehensive pre-commit validation with parallel checks
model: claude-sonnet-4-20250514
---

# Validate Command

Comprehensive pre-commit validation to ensure code quality, tests pass, and changes are ready for PR.

## Validation Pipeline

### Parallel Execution Strategy
Run INDEPENDENT checks simultaneously using multiple Bash tool calls in a single message:

```
# PARALLEL GROUP 1 (run simultaneously):
- Linting (eslint, pylint, etc.)
- Type checking (tsc, mypy, etc.)
- Format checking (prettier, black, etc.)
- Security scanning (npm audit, safety, etc.)

# SEQUENTIAL (after parallel group completes):
- Tests (may depend on compilation)
- Build verification (depends on all above)
```

**Critical**: Send multiple Bash tool calls in a SINGLE message for parallel execution.

## Check Categories (with dependencies):
1. **Syntax Check**: Ensure code compiles/parses
2. **Type Checking**: Validate type safety
3. **Linting**: Check code style and quality
4. **Format Check**: Verify code formatting
5. **Test Suite**: Run all tests
6. **Security Scan**: Check for vulnerabilities
7. **Documentation**: Verify docs are updated
8. **Build**: Ensure project builds successfully

## Implementation Steps

### 1. Detect Project Type and Tools

```bash
# Check for configuration files
ls -la | grep -E "package.json|pyproject.toml|Cargo.toml|go.mod|Makefile"

# Check for linter configs
ls -la | grep -E ".eslintrc|.pylintrc|.rubocop|rustfmt.toml"

# Check for formatter configs
ls -la | grep -E ".prettierrc|black.toml|.rustfmt"
```

### 2. Syntax and Compilation Checks

#### JavaScript/TypeScript
```bash
# TypeScript compilation
npx tsc --noEmit

# JavaScript syntax check
npx eslint --no-eslintrc --parser espree --no-config
```

#### Python
```bash
# Syntax check
python -m py_compile **/*.py

# AST validation
python -m ast **/*.py
```

#### Go
```bash
go build ./...
```

#### Rust
```bash
cargo check
```

### 3. Type Checking

```bash
# TypeScript
npx tsc --noEmit

# Python with mypy
mypy . --ignore-missing-imports

# Python with pyright
pyright

# Flow for JavaScript
npx flow check
```

### 4. Linting

```bash
# JavaScript/TypeScript
npm run lint || npx eslint .

# Python
pylint **/*.py || flake8 || ruff check

# Go
golangci-lint run || go vet ./...

# Rust
cargo clippy -- -D warnings
```

### 5. Code Formatting

```bash
# JavaScript/TypeScript
npx prettier --check . || npm run format:check

# Python
black --check . || autopep8 --diff -r .

# Go
gofmt -l . || go fmt ./...

# Rust
cargo fmt -- --check
```

### 6. Test Execution

```bash
# Run tests with coverage
npm test -- --coverage || pytest --cov || go test -cover ./... || cargo test

# Check coverage thresholds
# Fail if coverage < 80%
```

### 7. Security Scanning

```bash
# Node.js dependencies
npm audit || yarn audit

# Python dependencies
safety check || pip-audit

# General secrets scanning
gitleaks detect || trufflehog filesystem .

# SAST scanning
semgrep --config=auto
```

### 8. Documentation Checks

```bash
# Check if docs need updating
git diff --name-only main...HEAD | grep -E "\.md|\.rst|\.txt"

# Verify README is current
# Check if API docs need regeneration
# Validate markdown links
npx markdown-link-check README.md
```

### 9. Build Verification

```bash
# Node.js
npm run build || yarn build

# Python
python setup.py build || poetry build

# Go
go build ./...

# Rust
cargo build --release
```

## Validation Report Format

```markdown
# Validation Report
Timestamp: [ISO 8601 timestamp]

## Summary
✅ **PASSED** - All validation checks successful
-- OR --
❌ **FAILED** - 3 checks failed, must fix before commit

## Check Results

### ✅ Syntax Check
- All files parse correctly
- No syntax errors found

### ✅ Type Checking
- TypeScript: No type errors
- Strict mode: Enabled

### ⚠️ Linting (3 warnings)
- `src/auth/login.ts:45` - Missing return type
- `src/utils/helpers.ts:12` - Unused variable 'temp'
- `src/api/routes.ts:78` - Line too long (125 chars)

### ✅ Formatting
- All files properly formatted
- Using Prettier v2.8.0

### ✅ Tests (145/145 passing)
- Unit tests: 120/120 ✅
- Integration: 20/20 ✅
- E2E: 5/5 ✅
- Coverage: 87.3% (threshold: 80%)

### ✅ Security Scan
- No vulnerabilities found
- Dependencies up to date
- No secrets detected

### ⚠️ Documentation
- README needs updating for new API endpoints
- Changelog not updated

### ✅ Build
- Build successful in 45.2s
- Bundle size: 2.1MB (within limit)

## Required Actions
1. Fix linting warnings in 3 files
2. Update README with new endpoints
3. Add entry to CHANGELOG.md

## Recommendations
- Consider adding tests for uncovered lines
- Update deprecated dependencies (3 available)
- Add JSDoc comments to public APIs
```

## Smart Features

### 1. Parallel Execution (CRITICAL)
**Use multiple Bash tool calls in a SINGLE message** for parallel execution:

```
# In ONE message, call Bash tool FOUR times simultaneously:

Bash({ command: "npm run lint", description: "Run linting" })
Bash({ command: "npx tsc --noEmit", description: "Type check" })
Bash({ command: "npx prettier --check .", description: "Format check" })
Bash({ command: "npm audit --audit-level=high", description: "Security scan" })

# These run IN PARALLEL because they're in the same message
```

**After parallel checks complete, run sequential checks:**
```
Bash({ command: "npm test", description: "Run tests" })
# Then:
Bash({ command: "npm run build", description: "Build project" })
```

### 2. Incremental Validation
Only validate changed files when possible:
```bash
# Get changed files
git diff --name-only main...HEAD

# Run targeted validation
eslint --cache [changed-files]
```

### 3. Auto-fix Mode
Offer to automatically fix issues:
```bash
# Auto-fix linting
eslint --fix

# Auto-format code
prettier --write .

# Auto-fix imports
npx organize-imports-cli
```

### 4. Git Hooks Integration
Set up pre-commit hooks:
```bash
# Install husky
npx husky install

# Add pre-commit hook
npx husky add .husky/pre-commit "npm run validate"
```

## Configuration File

Save validation preferences in `.validation.json`:
```json
{
  "checks": {
    "syntax": true,
    "types": true,
    "lint": true,
    "format": true,
    "tests": true,
    "security": true,
    "docs": false,
    "build": true
  },
  "thresholds": {
    "coverage": 80,
    "maxWarnings": 10,
    "bundleSize": "5MB"
  },
  "autoFix": true,
  "parallel": true
}
```

## Integration with Other Commands

- Automatically run before `/pr.md`
- Include in `/merge.md` workflow
- Update `/status.md` with validation results
- Use with git pre-commit hooks

## Failure Handling

When validation fails:
1. Clearly identify what failed
2. Provide specific fix instructions
3. Offer auto-fix for simple issues
4. Create todos for complex fixes
5. Prevent commit/PR until fixed

## Execution

Begin validation immediately without confirmation. Run checks in optimal order (fail fast on critical issues). Provide real-time progress updates. Display clear, actionable results with specific file:line references for issues.