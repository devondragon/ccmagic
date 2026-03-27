---
user-invocable: true
allowed-tools: Read(*), Bash(*), Glob(*), Grep(*), Task(*), TodoWrite(*)
description: Run tests with framework auto-detection, smart selection, coverage analysis, and failure diagnosis
argument-hint: "[test-pattern] [--coverage] [--watch] [--affected]"
model: sonnet
---

# Test Command

Run tests with smart selection, coverage gap analysis, and structured failure diagnosis.

> **Parallel execution:** Independent test suites (unit, integration, e2e) can run simultaneously when they have no shared state. Claude Code determines when this is safe.

## Step 0: Parse Arguments

Parse `$ARGUMENTS` to determine test mode and options:

| Argument | Effect |
|----------|--------|
| *(empty)* | Auto-detect and run full suite |
| `<pattern>` | Run tests matching pattern (file path or test name) |
| `--coverage` | Run with coverage instrumentation and analyze gaps |
| `--watch` | Suggest watch mode command (do not block the session) |
| `--affected` | Only run tests affected by changed files |

Multiple flags can be combined: `--affected --coverage src/auth`

## Step 1: Detect Testing Framework

Load `${CLAUDE_SKILL_DIR}/framework-commands.md` for comprehensive command reference.

Check for framework configuration files:

```bash
ls -la package.json vitest.config.* jest.config.* playwright.config.* cypress.config.* \
  pytest.ini pyproject.toml setup.cfg tox.ini \
  Cargo.toml go.mod Makefile Rakefile Gemfile \
  pom.xml build.gradle build.gradle.kts 2>/dev/null
```

### Detection priority:
1. **package.json** `scripts` section — look for `test`, `test:unit`, `test:integration`, `test:e2e`, `test:coverage`
2. **Dedicated config files** — `vitest.config.*`, `jest.config.*`, `playwright.config.*`, `pytest.ini`, etc.
3. **Build tool configs** — `Cargo.toml`, `go.mod`, `pom.xml`, `build.gradle`
4. **Makefile** — `test`, `test-unit`, `test-integration` targets
5. **CI workflows** — `.github/workflows/*.yml` for test commands as last resort

Record the detected framework, available test types (unit/integration/e2e), and coverage tool.

If no framework is detected:
> "No test framework detected. What command runs your tests? I can save it to CLAUDE.md for future use."

## Step 2: Determine Test Scope

### When `--affected` is set or changes are minimal

Identify changed files and map them to affected tests:

```bash
# Get changed files vs main branch
git diff --name-only main...HEAD 2>/dev/null || git diff --name-only HEAD~1
```

**Dependency analysis for test mapping:**
1. For each changed source file, find its direct test file (e.g., `src/auth.ts` -> `src/auth.test.ts`, `__tests__/auth.test.ts`)
2. Check imports — if `utils/helpers.ts` changed, find all test files that import from `utils/helpers`
3. Use Grep to trace import chains: `grep -r "from.*utils/helpers" --include="*.test.*"`

**Test type routing based on what changed:**
- **Utility/library files** (helpers, utils, models, types) -> unit tests
- **API routes, controllers, handlers** -> integration tests + unit tests
- **Config files, env changes, infrastructure** -> full suite
- **Test files only** -> run only those specific tests
- **Documentation, README, non-code** -> skip tests, report "no tests needed"

If more than 30 files changed or changes span more than 5 directories, run the full suite instead.

### When `--watch` is set

Detect and suggest the appropriate watch command from the framework reference. Print the command for the user but do not run it in blocking mode:

> "Watch mode available. Run this in a separate terminal:"
> ```
> [framework-specific watch command]
> ```

Then proceed with a single test run.

## Step 3: Execute Tests

### Execution strategy

Run test suites in parallel when they are independent:

**Parallel-safe combinations:**
- Unit tests + linting (if fast)
- Unit tests for different modules with no shared state
- Integration tests + unit tests (if integration uses isolated fixtures)

**Must run sequentially:**
- Tests that share a database or filesystem state
- E2e tests that depend on a running server started by integration tests

### Running the tests

Use the framework-specific commands from `${CLAUDE_SKILL_DIR}/framework-commands.md`.

For each test suite, capture:
1. Exit code
2. Full stdout/stderr output
3. Timing information

If `--coverage` is set, add the coverage flag from the framework reference.

### Timeout handling

If a test suite runs longer than 120 seconds with no output, check if it is hung. Do not kill long-running e2e tests prematurely — check if the framework has a timeout flag and suggest adding one.

## Step 4: Parse Results

Extract structured data from test output:

- **Pass count** — total tests that passed
- **Fail count** — total tests that failed
- **Skip count** — tests skipped or pending
- **Duration** — wall-clock time for each suite
- **Coverage percentage** — overall and per-file (if coverage was run)
- **Failed test names** — exact test identifiers for each failure

## Step 5: Failure Analysis

For each failed test, perform structured diagnosis:

### 5a. Classify the failure type

| Type | Indicators |
|------|------------|
| **Assertion failure** | Expected vs actual mismatch |
| **Runtime error** | TypeError, NullPointerException, panic |
| **Timeout** | Test exceeded time limit |
| **Setup/teardown** | beforeEach/afterEach or fixture failure |
| **Import/compile** | Module not found, syntax error |
| **Environment** | Missing env var, port in use, DB connection |
| **Flaky** | Passes on retry, timing-dependent |

### 5b. Read source context

For each failure (up to 5 failures):
1. Read the failing test file at the relevant line
2. Read the source file being tested
3. Identify the specific function or code path that failed

### 5c. Diagnose root cause

Based on the error message, test code, and source code:
- What is the test checking?
- What did the code actually produce?
- What is the most likely cause? (logic error, stale mock, missing implementation, breaking API change)
- What is the minimal fix?

## Step 6: Coverage Gap Analysis

Run only when `--coverage` is set or when all tests pass (automatically check coverage on green).

### 6a. Identify uncovered code in changed files

```bash
# Get changed files
git diff --name-only main...HEAD 2>/dev/null || git diff --name-only HEAD~1
```

Cross-reference changed files against the coverage report. For each changed file with less than 80% coverage:
1. Read the file
2. Identify functions/branches without coverage
3. Categorize as: missing unit test, missing edge case, untested error path, dead code

### 6b. Test quality assessment

For test files associated with changed code, check:
- **Empty assertions** — tests that run code but never assert (e.g., `expect` never called)
- **Trivial assertions** — testing only that a function exists or returns truthy
- **Missing edge cases** — only happy path tested, no error/boundary cases
- **Snapshot-only** — relying entirely on snapshots with no behavioral assertions

Report findings only for changed files, not the entire codebase.

## Step 7: Task Verification

Check if a current task exists with `<verify>` blocks:

1. Look for active task files: `context/features/*/tasks/*.md` or similar project structure
2. If a task file contains `<verify>` blocks, extract the verification commands
3. Run each verification command and report pass/fail
4. If no task context exists, skip this step silently

## Step 8: Generate Report

```markdown
# Test Results

## Summary
| Metric | Value |
|--------|-------|
| Passed | X |
| Failed | Y |
| Skipped | Z |
| Duration | Xs |
| Coverage | N% (if measured) |

## Test Suites Run
- [suite name]: X/Y passed (Zs)
- [suite name]: X/Y passed (Zs)

## Failed Tests (if any)
For each failure:
### `test.name.here`
- **File**: `path/to/test.ts:42`
- **Type**: [assertion failure | runtime error | ...]
- **Error**: [one-line error message]
- **Cause**: [diagnosed root cause]
- **Fix**: [specific suggestion]

## Coverage Gaps (if analyzed)
For each under-covered changed file:
### `path/to/file.ts` (62% covered)
- `functionName()` — no test coverage
- `handleError()` — error branch untested
- Lines 45-52 — unreachable code (potential dead code)

## Test Quality Concerns (if any)
- `path/to/test.ts:15` — assertion-free test (runs code but verifies nothing)
- `path/to/test.ts:30` — only tests happy path, missing error case

## Task Verification (if applicable)
- [x] verify block 1: description — PASSED
- [ ] verify block 2: description — FAILED (details)

## Recommendations
[Actionable next steps: fix failures, add missing tests, improve assertions]
```

## Step 9: Create Todos for Failures

If tests failed, create TodoWrite entries:
- One todo per failing test with the diagnosed cause and suggested fix
- Group related failures (same root cause) into a single todo
- For coverage gaps, create one summary todo listing functions needing tests

## Integration with Other Commands

- Run automatically as part of `/ccmagic:validate`
- Gate `/ccmagic:pr` on test passage
- Report results to `/ccmagic:status`

## Execution

Begin test execution immediately without confirmation. If tests pass quickly, include coverage analysis automatically. For failures, always read the failing test and source code before reporting — raw error output alone is not sufficient. Provide actionable diagnosis, not just error dumps.
