# Debug Session Template

Template for debug session files created in `context/debug/`. Designed to survive context resets and enable session resumption.

---

```markdown
# Debug Session: {slug}

**Created**: {date-time}
**Status**: Active | Blocked | Resolved
**Bug Type**: {from root cause taxonomy, once classified}

## Symptoms

**What happens**: {exact symptom — error message, wrong output, crash, hang}
**What should happen**: {expected correct behavior}
**Reproduction**:
1. {exact steps to reproduce}
2. {step 2}
3. {step 3}

**Reproduction rate**: Always | Often (~X%) | Rare (~X%) | Unknown
**First observed**: {when — date, commit, deploy, or "always"}
**Environment**: {OS, runtime version, config, relevant env vars}

## Hypotheses

### H1: {concise hypothesis statement}
- **Likelihood**: High | Medium | Low
- **Prediction**: If this is the cause, then {testable prediction}
- **Experiment**: {what to do to test this}
- **Status**: Untested | Testing | Confirmed | Refuted | Inconclusive
- **Evidence**: {what the experiment showed}

### H2: {concise hypothesis statement}
- **Likelihood**: High | Medium | Low
- **Prediction**: {testable prediction}
- **Experiment**: {what to do}
- **Status**: Untested | Testing | Confirmed | Refuted | Inconclusive
- **Evidence**: {results}

### H3: {concise hypothesis statement}
...

## Investigation Journal

### {date-time} — Session start
- Symptoms captured
- Initial hypotheses generated: H1, H2, H3
- Plan: test H1 and H2 in parallel (independent)

### {date-time} — Round 1 results
- H1: {Confirmed/Refuted/Inconclusive} — {brief evidence}
- H2: {Confirmed/Refuted/Inconclusive} — {brief evidence}
- New hypothesis H4 generated based on H1 evidence
- Next: test H3 and H4

### {date-time} — Dead end documented
- Investigated {path} but it was a red herring because {reason}
- This eliminates {class of causes}
- Key learning: {what this tells us about the system}

## Root Cause

**Category**: {from taxonomy: logic error, state corruption, race condition, etc.}
**Location**: `{file:line}`
**Explanation**: {what the code does wrong, why, and under what conditions}
**First introduced**: {commit hash or "unknown"}

## Fix

**Approach**: {what was changed and why}
**Files modified**:
- `{file}` — {what changed}
- `{file}` — {what changed}

**Verification**:
```bash
{command that proves the fix works}
```

## Regression Test

**Test file**: `{path to test}`
**What it tests**: {the specific scenario that triggered this bug}
**Command**: `{how to run the test}`

## Follow-Up

- [ ] {Any remaining cleanup or hardening}
- [ ] {Related code that might have the same issue}
- [ ] {Monitoring or alerting to add}
```
