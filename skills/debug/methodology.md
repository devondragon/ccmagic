# Debugging Methodology

Scientific debugging reference. Loaded by the debug skill to guide hypothesis generation, experiment design, and root cause analysis.

---

## The Scientific Debugging Method

```
Observe → Hypothesize → Predict → Experiment → Evaluate → (repeat or resolve)
```

### 1. Observe
Gather all available evidence before forming hypotheses:
- What is the exact symptom? (error message, wrong output, crash, hang, performance)
- When did it start? (always, after a specific change, intermittently)
- What is the environment? (OS, runtime version, config, data state)
- What is the reproduction path? (exact steps, or "random")
- What has already been tried?

### 2. Hypothesize
Generate multiple hypotheses ranked by likelihood. Each hypothesis must be:
- **Specific**: "The null check on line 42 doesn't account for empty strings" not "something is null"
- **Testable**: there must be an experiment that can confirm or refute it
- **Falsifiable**: it must be possible for the experiment to prove the hypothesis wrong

### 3. Predict
For each hypothesis, state what you expect to observe if it's correct:
- "If the null check is the issue, passing an empty string to the /api/users endpoint will return a 500 instead of 400"
- "If the race condition hypothesis is correct, adding a 100ms delay before the second call will make the bug disappear"

### 4. Experiment
Design the minimal experiment that tests the prediction:
- Change one variable at a time
- Use the simplest reproduction case possible
- Record the exact commands/steps and their output

### 5. Evaluate
Compare the result against the prediction:
- **Prediction confirmed**: hypothesis is supported (but not yet proven — look for alternative explanations)
- **Prediction refuted**: hypothesis is eliminated — this is progress, document it and move on
- **Inconclusive**: experiment wasn't decisive — redesign with a more targeted test

---

## Symptom Analysis Framework

### Crash / Exception
- Read the full stack trace — the root cause is often 3-4 frames up from the thrown exception
- Check for null/undefined at the crash site, then trace where the value should have been set
- Search for recent changes to the crashing file and its dependencies

### Wrong Output
- Identify the exact divergence point: where does actual output first differ from expected?
- Binary search through the data pipeline: check intermediate values at midpoints
- Compare against a known-good case: what's different about the failing input?

### Performance Degradation
- Profile first, hypothesize second — don't guess at bottlenecks
- Check for: N+1 queries, missing indexes, unbounded loops, memory leaks, blocked I/O
- Compare against baseline: when was it last fast? What changed since then?

### Intermittent / Flaky
- Suspect timing: race conditions, timeouts, external service latency
- Suspect state: shared mutable state, stale caches, connection pool exhaustion
- Increase logging temporarily to capture state at failure point
- Run in a loop to increase reproduction probability

### Environment-Specific
- Diff the environments: config files, env vars, runtime versions, OS, data state
- Check for: hardcoded paths, platform-specific behavior, timezone issues, locale differences
- Try reproducing in the "working" environment with the "broken" environment's config

---

## Root Cause Taxonomy

Use these categories to classify the root cause once identified. This helps with fix design and regression prevention.

### 1. Logic Error
Wrong operator, off-by-one, inverted condition, swapped arguments, incorrect algorithm.
**Fix pattern**: correct the logic, add a test with the failing input.

### 2. State Corruption
Shared mutable state modified unexpectedly, stale cache, leaked reference, missing cleanup.
**Fix pattern**: make state immutable or access controlled, add state validation.

### 3. Race Condition
Concurrent access without proper synchronization, TOCTOU, interrupted operations.
**Fix pattern**: add synchronization, make operations atomic, use optimistic locking.

### 4. Configuration Issue
Wrong config value, missing env var, config drift between environments, default override.
**Fix pattern**: validate config at startup, add config tests, document required settings.

### 5. Dependency Change
Upstream API changed, library updated with breaking change, infrastructure change.
**Fix pattern**: pin versions, add contract tests, add integration tests at boundaries.

### 6. Data Issue
Unexpected data format, encoding issue, corrupt data, missing migration, schema mismatch.
**Fix pattern**: add input validation, data migration, schema versioning.

### 7. Integration Failure
Contract mismatch between services, timeout handling, retry logic, error propagation.
**Fix pattern**: add contract tests, improve error handling at boundaries, add circuit breakers.

### 8. Resource Exhaustion
Memory leak, file descriptor leak, connection pool exhaustion, disk full, rate limit hit.
**Fix pattern**: add resource cleanup, connection pooling, monitoring, graceful degradation.

---

## Bisection Strategies

### Git Bisect (for regressions)
When you know a commit where it worked and one where it doesn't:
```bash
git bisect start
git bisect bad HEAD
git bisect good {known-good-commit}
# Git checks out midpoint — test and mark good/bad
git bisect good  # or: git bisect bad
# Repeat until the first bad commit is identified
git bisect reset
```

Automate with a test script:
```bash
git bisect run ./test-reproduction.sh
```

### Code Path Bisection
When the bug isn't a regression but you need to find where in a pipeline it goes wrong:
1. Identify the start (input) and end (wrong output) of the pipeline
2. Add logging/assertions at the midpoint
3. If midpoint is correct → bug is in the second half
4. If midpoint is wrong → bug is in the first half
5. Repeat on the bad half

### Input Bisection
When a specific input triggers the bug but you need to find the minimal reproduction:
1. Start with the full failing input
2. Remove half the input
3. If still fails → the removed half wasn't needed, repeat on the remaining
4. If passes → the removed half contains the trigger, restore it and remove the other half
5. Continue until you have the minimal input that triggers the bug

---

## Common Debugging Patterns

### "Works on my machine"
1. Diff environments systematically (runtime, config, data, OS)
2. Use containers to reproduce the "other" environment locally
3. Check for: timezone, locale, file path separators, case sensitivity, line endings

### "Nothing changed"
Something always changed. Check:
1. `git log` for recent commits (including dependency updates)
2. Infrastructure changes (deploys, config updates, DNS, certificates)
3. Data changes (new records that trigger edge cases)
4. Time-based triggers (expiring tokens, scheduled jobs, date boundaries)

### "It was working yesterday"
1. Use `git bisect` to find the exact commit
2. If no code changed: check for data changes, external service changes, certificate expiry
3. Check for time-dependent code (timestamps, cron, TTL)

### Cascade Failures
The first error causes a chain of subsequent errors. The root cause is NOT the last error:
1. Find the chronologically first error in the logs
2. Trace backward from there
3. Ignore subsequent errors until the first is understood
