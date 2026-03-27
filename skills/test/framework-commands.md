# Framework Test Commands Reference

Comprehensive test commands per framework, including coverage, watch mode, parallel execution, and affected-only flags.

---

## JavaScript / TypeScript

### Vitest
```bash
# Run all tests
npx vitest run

# Run specific file or pattern
npx vitest run src/auth.test.ts
npx vitest run --grep "should authenticate"

# Coverage
npx vitest run --coverage

# Watch mode
npx vitest

# Affected only (changed files)
npx vitest run --changed

# Parallel (default, configure with --pool)
npx vitest run --pool=threads
```

### Jest
```bash
# Run all tests
npx jest

# Run specific file or pattern
npx jest src/auth.test.ts
npx jest --testNamePattern="should authenticate"

# Coverage
npx jest --coverage

# Watch mode
npx jest --watch

# Affected only (changed since last commit)
npx jest --changedSince=main
npx jest --onlyChanged

# Parallel (default, limit with --maxWorkers)
npx jest --maxWorkers=4
```

### Mocha
```bash
# Run all tests
npx mocha

# Run specific file or pattern
npx mocha "src/**/*.test.ts" --grep "should authenticate"

# Coverage (via nyc/c8)
npx c8 mocha
npx nyc mocha

# Watch mode
npx mocha --watch

# Parallel
npx mocha --parallel --jobs 4
```

### Playwright (E2E)
```bash
# Run all tests
npx playwright test

# Run specific file
npx playwright test tests/auth.spec.ts

# Run by grep
npx playwright test --grep "login"

# With report
npx playwright test --reporter=html

# Parallel (default, configure in playwright.config)
npx playwright test --workers=4

# Single browser
npx playwright test --project=chromium
```

### Cypress (E2E)
```bash
# Run all tests (headless)
npx cypress run

# Run specific spec
npx cypress run --spec "cypress/e2e/auth.cy.ts"

# Interactive mode
npx cypress open

# Single browser
npx cypress run --browser chrome

# Parallel (requires Cypress Cloud or orchestration)
npx cypress run --parallel --record
```

### npm script fallbacks
When a project uses npm scripts, prefer them over direct invocation:
```bash
# Check available scripts
node -e "const p=require('./package.json'); console.log(Object.keys(p.scripts||{}).filter(s=>s.includes('test')).join('\n'))"

# Common script names
npm test                  # default
npm run test:unit         # unit tests
npm run test:integration  # integration tests
npm run test:e2e          # end-to-end tests
npm run test:coverage     # with coverage
npm run test:watch        # watch mode
```

---

## Python

### pytest
```bash
# Run all tests
pytest -v

# Run specific file or pattern
pytest tests/test_auth.py -v
pytest -k "test_authenticate" -v

# Coverage
pytest --cov=src --cov-report=term-missing
pytest --cov=src --cov-report=html

# Watch mode (requires pytest-watch)
ptw -- -v

# Affected only (run tests for changed modules)
pytest --co -q  # list tests first, then filter

# Parallel (requires pytest-xdist)
pytest -n auto
pytest -n 4

# Markers for test types
pytest -m unit
pytest -m integration
pytest -m "not slow"
```

### unittest
```bash
# Run all tests
python -m unittest discover -s tests -v

# Run specific test
python -m unittest tests.test_auth.TestAuth.test_login -v

# Coverage (via coverage.py)
coverage run -m unittest discover -s tests
coverage report -m
coverage html
```

### Django
```bash
# Run all tests
python manage.py test -v 2

# Run specific app or test
python manage.py test auth -v 2
python manage.py test auth.tests.TestLogin.test_valid_login

# Coverage
coverage run manage.py test
coverage report -m

# Parallel
python manage.py test --parallel auto
```

---

## Go

```bash
# Run all tests
go test ./... -v

# Run specific package
go test ./pkg/auth/... -v

# Run specific test
go test ./pkg/auth -run TestAuthenticate -v

# Coverage
go test ./... -coverprofile=coverage.out
go tool cover -func=coverage.out
go tool cover -html=coverage.out  # HTML report

# Race detection
go test ./... -race -v

# Short mode (skip long tests)
go test ./... -short

# Parallel (per-package parallelism is default, control with -p)
go test ./... -p 4

# Timeout
go test ./... -timeout 120s

# Benchmarks
go test ./... -bench=. -benchmem
```

---

## Rust

```bash
# Run all tests
cargo test

# Run specific test
cargo test test_authenticate
cargo test --test integration_tests

# With output
cargo test -- --nocapture

# Coverage (via cargo-tarpaulin or llvm-cov)
cargo tarpaulin --out Html
cargo llvm-cov --html

# Watch mode (requires cargo-watch)
cargo watch -x test

# Doc tests only
cargo test --doc

# Specific package in workspace
cargo test -p auth-service

# Parallel (default, limit with test-threads)
cargo test -- --test-threads=4

# Benchmarks (nightly)
cargo bench
```

---

## Java

### Maven
```bash
# Run all tests
mvn test

# Run specific test class
mvn test -Dtest=AuthTest

# Run specific method
mvn test -Dtest=AuthTest#testLogin

# Coverage (JaCoCo)
mvn test jacoco:report

# Skip integration tests
mvn test -DskipITs

# Integration tests only
mvn verify -Dskip.unit.tests

# Parallel
mvn test -T 4
```

### Gradle
```bash
# Run all tests
gradle test

# Run specific test
gradle test --tests AuthTest
gradle test --tests "com.app.AuthTest.testLogin"

# With output
gradle test --info

# Coverage (JaCoCo)
gradle test jacocoTestReport

# Parallel (configure in gradle.properties)
gradle test --parallel
```

---

## Ruby

### RSpec
```bash
# Run all tests
bundle exec rspec

# Run specific file or line
bundle exec rspec spec/auth_spec.rb
bundle exec rspec spec/auth_spec.rb:42

# Run by tag
bundle exec rspec --tag unit
bundle exec rspec --tag ~slow

# Coverage (via simplecov — add to spec_helper.rb)
# SimpleCov starts automatically when configured

# Watch mode (requires guard-rspec)
bundle exec guard

# Parallel (requires parallel_tests)
bundle exec parallel_rspec spec/

# Format
bundle exec rspec --format documentation
```

### Minitest
```bash
# Run all tests
ruby -Itest test/**/*_test.rb
rake test

# Run specific file
ruby -Itest test/auth_test.rb

# Run specific test
ruby -Itest test/auth_test.rb --name test_login

# Coverage (via simplecov)
# SimpleCov starts automatically when configured

# Parallel (requires parallel_tests)
bundle exec parallel_test test/
```

---

## Detection Heuristics

When multiple frameworks are present, prioritize by specificity:

1. **Dedicated config file** (e.g., `vitest.config.ts`) beats a generic `package.json` script
2. **Explicit test script** in package.json beats implicit framework detection
3. **CI configuration** is a reliable fallback — parse `.github/workflows/*.yml` for the actual test commands used in production
4. For monorepos, detect per-workspace — different packages may use different frameworks

## Coverage Threshold Defaults

When no project-specific threshold is configured, use these defaults:
- **Overall coverage**: 80% (warn below, not block)
- **Changed file coverage**: 70% (flag files below this)
- **New file coverage**: 80% (new code should be well-tested)

These are reporting thresholds, not enforcement gates. The skill reports gaps but does not fail the run based on coverage alone.
