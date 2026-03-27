# Verification Guide

Reference for parsing verify/done blocks, classifying failures, and running diagnostic agents.

## Parsing Rules

### Verify Blocks

Verify blocks use XML-style tags in task files:

```xml
<verify>command here</verify>
```

**Parsing steps:**
1. Scan the task file for all occurrences of `<verify>...</verify>`
2. Extract the text content between tags — this is the shell command
3. Trim leading/trailing whitespace from the command
4. Each tag contains exactly one command (no multi-line commands)
5. Commands are executed with `bash -c` and must return exit code 0 on success

**Common patterns:**
- Test runners: `npm test -- --testPathPattern="pattern"`
- Build checks: `npm run build 2>&1 | grep -qv "error"`
- File existence: `test -f path/to/file`
- Content checks: `grep -q "expected" path/to/file`
- API checks: `curl -sf http://localhost:3000/endpoint | jq -e '.field'`
- Database checks: `npx prisma migrate status | grep -q "applied"`

### Done Blocks

Done blocks use XML-style tags with bullet-list content:

```xml
<done>
- First criterion
- Second criterion
- Third criterion
</done>
```

**Parsing steps:**
1. Scan for `<done>...</done>` block (typically one per task)
2. Split content by newlines
3. Each line starting with `- ` (dash space) is a separate criterion
4. Trim the `- ` prefix to get the criterion text
5. Blank lines and lines not starting with `- ` are ignored

### Acceptance Criteria Checklist

These appear in the task body as markdown checklist items:

```markdown
- [ ] Criterion not yet met
- [x] Criterion already met
```

**Mapping:** Acceptance criteria are the canonical list. Verify commands and done criteria support them. When updating status, map each verify/done result back to the acceptance criterion it validates.

## Failure Classification

Every failed verification is classified into one of four types. This drives the diagnostic approach and suggested fix.

### MISSING_IMPL
The feature or component has not been built yet.

**Signals:**
- File not found errors
- Module not found / import errors
- Function or class does not exist
- Empty or stub implementations
- Test describes behavior that has no corresponding code

**Diagnostic approach:** Check if the referenced files/modules exist. Look for TODO comments or stub functions. Verify the implementation plan covers this work.

**Typical fix:** Implement the missing feature. This is expected for in-progress tasks.

### BUG
Implementation exists but produces incorrect behavior.

**Signals:**
- Test assertions fail (expected vs actual mismatch)
- Wrong return values or status codes
- Logic errors in conditionals or loops
- Off-by-one errors, null references
- Race conditions or ordering issues

**Diagnostic approach:** Read the failing test to understand expected behavior. Read the implementation to trace the logic path. Compare expected vs actual at each step.

**Typical fix:** Correct the implementation logic. May need targeted debugging.

### ENV_ISSUE
The environment, configuration, or dependencies are not set up correctly.

**Signals:**
- Connection refused (server not running)
- Missing environment variables
- Wrong port or URL
- Dependency not installed
- Database not migrated
- Permission denied

**Diagnostic approach:** Check config files (.env, config/). Verify services are running. Check dependency installation status. Look for setup steps that were skipped.

**Typical fix:** Run setup commands, start services, install dependencies, or fix configuration.

### TEST_ISSUE
The verify command itself is wrong, outdated, or tests the wrong thing.

**Signals:**
- Command references files/paths that have been renamed
- Test pattern matches no test files
- grep pattern does not match current output format
- Command assumes a setup state that does not exist
- Verify command contradicts the acceptance criteria

**Diagnostic approach:** Compare the verify command against current file structure and naming. Check if the command was written for an earlier version of the code. Verify the command tests what the acceptance criterion describes.

**Typical fix:** Update the verify command. This may require updating the task file.

## Diagnostic Agent Protocol

### When to spawn agents

- Always spawn for FAIL results from verify commands
- Spawn for done criteria the user marks as "No" (with description)
- Do not spawn for PASS, SKIP, or TIMEOUT results
- Cap at 3 simultaneous agents to avoid resource contention

### Agent scope

Diagnostic agents are **Explore** type (read-only investigation). They:
- Read source files, test files, config files
- Analyze error output
- Trace code paths
- Classify the failure

They do NOT:
- Modify any files
- Run the build or tests themselves
- Make commits or changes

### Agent prompt structure

Every diagnostic agent receives:
1. The exact failed command and its output
2. The task context (id, description, acceptance criteria)
3. Instructions to classify, explain root cause, and suggest fix
4. The four classification types with descriptions

### Interpreting agent results

Agents return:
- **Classification**: One of the four types
- **Root cause**: Specific explanation with file:line references
- **Suggested fix**: Concrete actionable steps
- **Confidence**: High (clear evidence), Medium (likely but not certain), Low (best guess)

Use confidence to weight the report:
- High confidence fixes can be presented as recommendations
- Medium confidence fixes should note uncertainty
- Low confidence fixes should suggest manual investigation

## Retry Protocol

When re-running failed verifications:
1. Only re-run commands that previously failed (not all commands)
2. Re-check done criteria that were marked "No" (not "Skip" or "Yes")
3. If a previously failed command now passes, update its status and remove the failure entry
4. If it still fails, keep the existing diagnostic and note "Still failing after retry"
5. Update the summary counts in the report

## TodoWrite Integration

Map verification results to TodoWrite entries:

- **Each failure** gets a TodoWrite entry with the pattern:
  `VERIFY FAIL: {criterion} -- {classification}: {root cause summary}`
- **Passing criteria** do not get TodoWrite entries (clean state)
- **Skipped criteria** get entries only if they were previously failing:
  `VERIFY SKIP: {criterion} -- deferred`
- When all criteria pass, create a single completion entry:
  `VERIFY COMPLETE: {task-id} -- all criteria verified`
