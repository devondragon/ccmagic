# Finding Schema

Every finding reported by a review agent MUST use this exact structure. Omitting fields or inventing new ones breaks triage.

## Output Format

```
- severity: Critical | High | Medium | Low
- confidence: <0-100>
- file: <path relative to repo root>
- line: <number or range, e.g. 42 or 42-58>
- issue: <one-line summary>
- detail: <explanation with evidence — what the code does wrong, concrete triggering scenario>
- suggestion: <minimal fix — what to change, not a rewrite>
- specialist: <agent name that produced this finding — e.g. correctness, security, testing, performance, migration>
- fixable: <true | false — true if the fix is mechanical and can be auto-applied without judgment>
- systemic: <optional — present only when the issue is an instance of a repeatable pattern: name the defect class, then enumerate EVERY instance found, searching across all reference mechanisms that could carry the pattern (template attributes, raw attributes, ES-module imports, CSS @import/url(), manifests, service workers, config files — whichever apply). Omit for one-off issues.>
```

Use one block per finding. Separate findings with a blank line.

The `specialist` field enables multi-specialist confirmation (boosted confidence when 2+ agents flag the same issue). The `fixable` field drives the fix-first workflow — mechanical fixes are auto-applied, judgment calls are batched for user decision.

The `systemic` field prevents whack-a-mole fix loops — a point-fix to the reported line while sibling instances survive to the next review pass. When an issue is one instance of a pattern, the **enumeration is the finding**, not the first hit: search every mechanism that could carry the pattern, not just the syntax the first instance used. And scope your all-clears: a "no other instances" claim MUST state its search scope and the mechanisms covered, or be downgraded to "no other {mechanism} instances found". An unscoped universal claim is more dangerous than silence in an autonomous loop that acts on verdicts.

## Severity Definitions

### Critical
The code **will** cause harm in production without additional safeguards.

Examples:
- Security vulnerability with a concrete exploit path (SQL injection via unsanitized user input, auth bypass through missing middleware)
- Data loss or corruption (overwriting without backup, silent truncation, unguarded concurrent writes)
- Crash on a reachable production code path (unhandled null on required field, panic in request handler)

### High
The code **will likely** produce wrong results or miss an important safeguard.

Examples:
- Logic bug affecting core functionality (off-by-one in pagination, wrong comparison operator, swapped arguments)
- Missing authentication or authorization check on an endpoint
- Unhandled error that silently loses data or masks a failure the caller needs to know about
- Race condition under realistic concurrency

### Medium
The code has a **measurable** quality or performance concern, or is fragile enough to break on the next change.

Examples:
- O(n^2) loop over a collection that grows with user data
- Duplicated logic that must stay in sync (copy-paste without shared abstraction)
- Missing input validation at a trust boundary that isn't yet exploitable but would be with minor changes
- Fragile assumptions (hardcoded index, magic number tied to external format)

### Low
Minor improvement opportunity. Correct today, but could be better.

Examples:
- Defensive coding suggestion (add a bounds check that today can't fail)
- Slightly misleading variable name in a complex function
- Opportunity to use a more idiomatic language construct
- Missing edge-case test for an unlikely but possible input

## Confidence Scoring

The confidence score reflects how certain you are that the finding is real and the severity is accurate.

| Score | Meaning | Evidence required |
|-------|---------|-------------------|
| 90-100 | **Certain** | Can point to exact line AND exact failure scenario. Reproducible. |
| 70-89 | **Likely** | High probability based on code reading, but depends on runtime conditions, config, or input data you can't fully verify. |
| 50-69 | **Possible** | Suspicious pattern that needs more context. You see a risk but can't confirm without understanding callers or runtime state. |
| Below 50 | **Speculative** | Do NOT report. If you can't reach 50, the finding isn't worth the reader's time. |

### Scoring guidance
- Reading the code and seeing the bug directly → 90+
- Inferring the bug from types/signatures without seeing the call site → 70-89
- Pattern-matching against common mistakes without confirming this instance → 50-69
- "This could theoretically be a problem" → below 50, skip it

## Deduplication Rules

When multiple agents flag the same issue:
1. **Same file + same line range + same issue type** → merge into one finding
2. Keep the **highest confidence** score
3. Keep the **most specific detail** (prefer the version with a concrete scenario)
4. If severities differ, keep the **higher severity** but note the disagreement in detail

## What NOT to Report

Do not create findings for:
- Formatting or whitespace issues
- Naming style preferences (unless conventions.md explicitly requires a specific style)
- Missing comments or JSDoc (unless conventions.md explicitly requires them)
- TODO/FIXME/HACK comments (these are intentional markers, not bugs)
- Test file structure or test naming conventions
- Import ordering
- Anything that is a matter of taste rather than correctness, security, or documented convention
