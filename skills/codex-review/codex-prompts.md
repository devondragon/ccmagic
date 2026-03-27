# Codex Review Prompts

Structured prompts for multi-dimension Codex passes. Each prompt is self-contained and designed to produce focused, high-signal findings within a single concern area.

All prompts share the same output format (see Finding Output Format at the bottom).

---

## Security Pass

```
Review this code for SECURITY VULNERABILITIES ONLY. Do not report style, architecture, or performance concerns.

For each finding you MUST include:
- The attacker's entry point (what input they control)
- The data flow from input to dangerous sink
- Attacker preconditions (auth required? network access? specific role?)
- Concrete exploit scenario

Focus on:
- Injection: SQL, NoSQL, command, LDAP, XPath, template injection
- Authentication/authorization: missing checks, privilege escalation, session issues
- Data exposure: secrets in logs/responses, PII leaks, sensitive data in client code
- Insecure defaults: debug mode, permissive CORS, disabled CSRF
- Cryptography: weak algorithms, hardcoded keys, insecure randomness
- Path traversal: user-controlled file paths
- Deserialization: unsafe deserialization of user data

Do NOT report:
- Theoretical vulnerabilities requiring server-level access
- Missing rate limiting (unless on auth endpoints)
- Dependency CVEs (separate scanning concern)
- Internal code paths with no user input

Return at most 10 findings, sorted by severity then confidence.
If there are no actionable findings, output exactly: No actionable findings.
```

---

## Architecture & Design Pass

```
Review this code for ARCHITECTURE AND DESIGN issues ONLY. Do not report security vulnerabilities, style nits, or individual bugs.

Focus on:
- Coupling: inappropriate dependencies, business logic in wrong layer, cross-cutting concerns leaking
- Dependency direction: lower layers importing from upper layers, circular dependencies
- API design: inconsistent contracts, breaking changes, missing versioning
- Error boundaries: errors leaking across module boundaries, missing error handling at entry points
- Dead code/unused exports that create maintenance burden or false API surface
- Missing abstractions: same pattern duplicated 3+ times across modules
- Configuration: hardcoded values that should be configurable, environment-specific code in shared paths

Do NOT report:
- Single-function logic bugs (correctness pass handles those)
- Naming style preferences
- File organization opinions without concrete coupling evidence
- "This could be refactored" without demonstrating a defect or fragility

For each finding, identify which modules/files are affected and the dependency direction.

Return at most 10 findings, sorted by severity then confidence.
If there are no actionable findings, output exactly: No actionable findings.
```

---

## Correctness & Reliability Pass

```
Review this code for CORRECTNESS AND RELIABILITY issues ONLY. Do not report security, style, or architecture concerns.

Focus on:
- Logic errors: wrong operators, off-by-one, inverted conditions, swapped arguments
- Null/undefined/nil access on reachable code paths
- Race conditions under realistic concurrency
- Resource leaks: unclosed handles, missing cleanup in error paths, leaked goroutines/promises
- Error handling gaps: swallowed errors, incorrect error propagation, missing retry/fallback
- Type errors or unsafe coercion
- Broken control flow: unreachable code, missing break, fallthrough bugs
- Incorrect API usage: wrong argument order, deprecated methods, contract violations
- Edge cases: empty collections, zero values, boundary conditions

For each finding you MUST include a concrete triggering scenario: what input or state causes the bug, and what wrong behavior results.

Do NOT report:
- Code that works but could be "cleaner"
- Performance (separate pass)
- Style or formatting
- TODO comments

Return at most 10 findings, sorted by severity then confidence.
If there are no actionable findings, output exactly: No actionable findings.
```

---

## Error Handling & Resilience Pass

```
Review this code for ERROR HANDLING AND RESILIENCE issues ONLY.

Focus on:
- Swallowed errors: catch blocks that log but don't propagate, ignored return errors
- Missing error handling: operations that can fail but have no error path
- Incorrect error propagation: wrapping that loses context, wrong error types, status code mismatches
- Retry logic: missing retries on transient failures, retries without backoff, retries on non-idempotent operations
- Timeout handling: missing timeouts on network/IO operations, timeout too long/short
- Graceful degradation: missing fallbacks, cascade failure risks
- Resource cleanup: missing finally/defer blocks, cleanup that doesn't run on error paths
- Panic/crash paths: unhandled exceptions that kill the process instead of the request

For each finding, describe what happens when the failure occurs and what the user/system experiences.

Do NOT report:
- Error handling style preferences
- Logging format issues
- Missing error types that don't affect behavior

Return at most 10 findings, sorted by severity then confidence.
If there are no actionable findings, output exactly: No actionable findings.
```

---

## Test Coverage Gaps Pass

```
Review this code for SIGNIFICANT TEST COVERAGE GAPS ONLY. Do not report style or test organization preferences.

Focus on:
- Untested critical paths: auth flows, payment/billing, data mutations, API endpoints
- Untested error paths: what happens when dependencies fail, invalid input, timeouts
- Untested edge cases: empty inputs, boundary values, concurrent access
- Missing integration tests: components that interact but are only unit-tested in isolation
- Tests that don't assert: tests that run code but don't verify outcomes
- Brittle tests: tests coupled to implementation details that break on refactor
- Missing regression tests for recent bug fixes (check git log for fix commits without tests)

Do NOT report:
- Missing tests for trivial getters/setters
- Test naming conventions
- Test file organization
- Missing tests for generated code

For each finding, describe what specific test should be added and what scenario it covers.

Return at most 10 findings, sorted by severity then confidence.
If there are no actionable findings, output exactly: No actionable findings.
```

---

## Dependency Health Pass

```
Review the project's dependency configuration for HEALTH AND RISK issues.

Examine: package.json/package-lock.json, go.mod/go.sum, Cargo.toml/Cargo.lock, pyproject.toml/requirements.txt, pom.xml, build.gradle, Gemfile/Gemfile.lock

Focus on:
- Unpinned dependencies that could break on update (^ or ~ ranges for critical deps)
- Known deprecated packages still in use
- Overly broad dependency versions allowing major version bumps
- Duplicate dependencies at different versions
- Dev dependencies in production bundles
- Missing lockfile when one is expected
- Dependency on unmaintained packages (check for abandonment signals in config)
- Misconfigured build tools: wrong source/target versions, missing plugins, conflicting settings

Do NOT report:
- Specific CVEs (separate scanning tool)
- Minor version behind for non-critical deps
- Dependency count opinions

Return at most 10 findings, sorted by severity then confidence.
If there are no actionable findings, output exactly: No actionable findings.
```

---

## Finding Output Format (shared)

All passes must use this exact markdown table format:

```
| Severity | Confidence | Location | Issue | Trigger | Fix | Test |
|---|---:|---|---|---|---|---|
| Critical | 95 | src/auth.ts:42 | SQL injection via unsanitized email param | POST /login with email='; DROP TABLE-- | Use parameterized query | Test login with SQL metacharacters |
```

Severity: Critical, High, Medium, Low
Confidence: 0-100 (do not report below 50)
Location: file:line or "multiple" for cross-cutting issues
Trigger: concrete scenario that exposes the issue
Fix: minimal safe change (not a rewrite)
Test: specific test to add or update
