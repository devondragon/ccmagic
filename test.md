# Test Command

Run comprehensive test suite for the current changes and ensure code quality before committing or creating a PR.

## Test Execution Strategy

1. **Detect Testing Framework**: Automatically identify the testing framework used in the project
2. **Run All Test Levels**: Execute unit, integration, and e2e tests if available
3. **Coverage Analysis**: Generate and review test coverage reports
4. **Performance Tests**: Run performance benchmarks if configured

## Implementation Steps

### 1. Framework Detection
Check for test configuration in:
- `package.json` (scripts section for Node.js projects)
- `Makefile` (test targets)
- `pytest.ini`, `tox.ini` (Python projects)
- `Cargo.toml` (Rust projects)
- `go.mod` (Go projects)
- `.github/workflows` (CI test commands)

### 2. Test Execution Order
1. **Unit Tests First**: Run isolated unit tests
2. **Integration Tests**: Test component interactions
3. **E2E Tests**: Full system tests (if not too time-consuming)
4. **Smoke Tests**: Quick validation of critical paths

### 3. Smart Test Selection
- If changes are minimal, run only affected test suites
- Use `git diff` to identify changed files
- Map changed files to their test files
- Run full suite if changes are extensive

## Test Commands by Framework

### JavaScript/TypeScript
```bash
# Check for test scripts
npm run test || yarn test || pnpm test

# With coverage
npm run test:coverage || npm test -- --coverage

# Watch mode for development
npm run test:watch
```

### Python
```bash
# Pytest
pytest -v --cov=. --cov-report=term-missing

# Django
python manage.py test

# Unittest
python -m unittest discover
```

### Go
```bash
go test ./... -v -cover
```

### Rust
```bash
cargo test --all
```

## Output Format

```markdown
# Test Results

## Summary
✅ Passed: [X/Y tests]
❌ Failed: [X tests]
⏭️ Skipped: [X tests]
⏱️ Duration: [X seconds]

## Coverage
Overall: [X%]
- Files with <80% coverage: [list]

## Failed Tests
[If any tests failed, list them with error details]

## Recommendations
[Suggest fixes for failures or areas needing more tests]
```

## Failure Handling

If tests fail:
1. Parse error output to identify root causes
2. Suggest specific fixes based on error types
3. Offer to automatically fix simple issues (imports, types)
4. Create a todo list for complex failures

## Integration with Other Commands

- Run automatically before `/pr.md`
- Include in `/validate.md` workflow
- Update status in `/status.md` after completion

## Execution

Begin test execution immediately without confirmation. If no test framework is detected, ask user for the test command to use and offer to save it to CLAUDE.md for future use.