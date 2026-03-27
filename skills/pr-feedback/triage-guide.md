# PR Comment Triage Guide

Classification criteria, verification methodology, conflict resolution, and response templates for PR feedback triage.

---

## Severity Classification

### must-fix (Blocking)

The comment identifies something that **will cause harm** if merged as-is.

**Qualifies when:**
- Security vulnerability with a concrete exploit path
- Bug that produces wrong results on a reachable code path
- Data loss or corruption scenario
- Breaking API contract (existing callers will fail)
- Missing authentication or authorization check
- Crash on production code path (unhandled null, panic in handler)
- Race condition under realistic concurrency

**Does NOT qualify just because:**
- The reviewer used urgent language ("this is critical!")
- The reviewer requested changes (CHANGES_REQUESTED state alone is not proof)
- The code looks unfamiliar to the reviewer

### should-fix (Valid, Non-Blocking)

The comment identifies a **real improvement** that belongs in this PR.

**Qualifies when:**
- Missing error handling or edge case coverage
- Code clarity improvement that aids maintainability
- Naming that is misleading or confusing in context
- Test coverage gap for changed code
- Duplicated logic that should be shared (DRY violation)
- Documentation gap for complex or non-obvious logic
- Performance fix that is straightforward to implement
- Missing input validation at a trust boundary
- Any improvement achievable in under ~30 minutes

**This is the default classification.** When uncertain, start here.

### style/preference (Optional)

The comment reflects **personal taste** rather than objective improvement.

**Qualifies when:**
- Alternative approach that is equally valid (not better or worse)
- Naming preference not backed by project conventions
- Code organization suggestion that is lateral (different, not better)
- Formatting or structural preference beyond what linters enforce
- "I would have done it differently" without a concrete quality argument

**Upgrade to should-fix if:**
- Project conventions explicitly require the suggested pattern
- The suggestion measurably improves readability for the team (not just the reviewer)
- Multiple reviewers independently make the same suggestion

### question (Response Only)

The reviewer is **asking for information**, not requesting a change.

**Qualifies when:**
- "Why did you choose X over Y?"
- "What happens if Z?"
- "Can you explain this logic?"
- "Is this related to issue #N?"
- Inline questions marked with "?" that don't imply a change request

**Upgrade to should-fix if:**
- The question reveals that the code is genuinely unclear (the question itself proves the code needs a comment or better naming)

---

## Verification Methodology

### Reading Code in Context

When verifying a reviewer's claim:

1. **Read the full function**, not just the flagged line. A 3-line diff hunk often omits the guard clause 10 lines above.
2. **Check the callers**. Use Grep to find who calls this function. The issue may be handled upstream.
3. **Check error boundaries**. Look for try/catch, middleware, error handlers that wrap this code path.
4. **Check tests**. Search for test files that exercise this code. If a test already covers the flagged scenario, the concern may be addressed.
5. **Check git history**. If the code was recently changed, `git log -1 --format=%s -- {file}` may reveal intent.

### Convention Verification

When a reviewer suggests a pattern:

1. Search `{PROJECT_CONVENTIONS}` for explicit rules about the pattern
2. If conventions say **do X** and the reviewer says **do X** — upgrade to should-fix
3. If conventions say **do X** and the reviewer says **do Y** — decline with citation
4. If conventions are **silent** — evaluate on merit (default to should-fix if the suggestion is objectively better)

### False Positive Indicators

A reviewer concern is likely a false positive when:

- The code already handles the case (check 5+ lines above/below the flagged line)
- A middleware/decorator/wrapper handles it at a higher level
- The input is already validated before reaching this point
- The reviewer is reading an older version of the diff (check if the concern was addressed in a later commit)
- The reviewer misidentified the language/framework behavior
- Project conventions explicitly allow the flagged pattern

### True Positive Indicators

A reviewer concern is likely valid when:

- You can construct a concrete input that triggers the issue
- The code path is reachable from user input or external data
- No test covers the flagged scenario
- The same pattern caused bugs elsewhere in the codebase
- Multiple reviewers independently flag the same area

---

## Conflict Resolution

### Same Reviewer, Multiple Comments on Same Code

Often a reviewer leaves initial feedback, then follows up after seeing more context. Read the **entire thread** — the last comment usually represents their final position.

### Two Reviewers Disagree

Present both positions to the user with context:

```
Conflicting feedback on `{file}:{line}`:
- @reviewer_a: {position A with reasoning}
- @reviewer_b: {position B with reasoning}
- Convention alignment: {which side aligns, or "no convention applies"}
- Code evidence: {what the code actually does}
```

Let the user decide. Do not pick a side.

### Reviewer vs. Project Conventions

Project conventions win over individual reviewer preferences. If a reviewer suggests a pattern that contradicts documented conventions:

1. Classify as **decline**
2. Cite the specific convention
3. Suggest a response to the reviewer that references the convention

Exception: if the reviewer is arguing the convention itself should change, that is a valid discussion — classify as **defer** and suggest opening a separate discussion.

### Reviewer vs. PR Author (in thread)

If the PR author already responded to a comment and the reviewer acknowledged or dropped the concern:
- The thread is resolved — skip it
- Only triage threads where the concern is still open (no resolution in the replies)

---

## Response Templates

### For declined comments (already handled)

> This is already handled by `{mechanism}` at `{file}:{line}`. The `{function/middleware/guard}` ensures `{what it does}`, which covers the scenario you described.

### For declined comments (convention disagreement)

> Our project conventions (`{file}`) specify `{quoted rule}`. The current code follows this convention. If you think the convention should change, happy to discuss that separately.

### For declined comments (misunderstanding)

> I think there may be a misunderstanding — `{what the code actually does}`. The `{variable/function}` is `{explanation}`, so `{why the concern doesn't apply}`.

### For deferred comments

> Good catch — this is a valid concern but touches `{scope description}` which is outside this PR's scope. I've created `{issue/backlog item}` to track it. Want to discuss the approach there?

### For questions

> `{direct answer to the question}`. I've added a code comment at `{location}` to make this clearer for future readers.

---

## Grouping Strategy

### Why Group by File

Opening a file, understanding its context, and making changes has a cognitive and mechanical cost. Grouping minimizes:
- Repeated file reads
- Context switching between different parts of the codebase
- Risk of conflicting changes when the same file is edited multiple times

### Cross-File Concern Groups

Some feedback spans multiple files but addresses one concern:
- "Add input validation" across 3 API handlers — one concern, 3 files
- "Use the shared utility instead of inline logic" in 2 places — one concern, 2 files

Group these by **concern** rather than by file. The implementation pass should fix all instances together to maintain consistency.

### Fix Group Format

Each fix group in the TodoWrite should contain:
```
File: {path}
Fixes:
  - Line {N}: {what to change} (must-fix | should-fix | style)
  - Line {M}: {what to change} (should-fix)
Reviewer(s): @{user1}, @{user2}
```

This gives the implementer everything needed to open the file once and make all changes.
