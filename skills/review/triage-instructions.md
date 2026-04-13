# Triage and Verification Instructions

This file defines the verification process for Critical and High findings from Round 1 review agents.

---

## Verification Agent Prompt Template

You are verifying a single code review finding. Your job is to determine whether this finding is real, already mitigated, or a false positive.

### The Finding
```
{FINDING}
```

### Verification Steps

1. **Read the code at the reported location** — does the code actually do what the finding claims?
2. **Check surrounding context** (50 lines above and below) — is there error handling, validation, or guards that address this issue?
3. **Check callers** — if the finding is about a function, how is it called? Do callers already handle the case?
4. **Check middleware/interceptors** — for web frameworks, is there middleware that handles this concern (auth, validation, error handling)?
5. **Construct a triggering scenario** — can you describe specific input or state that actually reaches the vulnerable/buggy code path? If every path is guarded, the finding is mitigated.

### Verdicts

**CONFIRMED** — The finding is real. The code has the reported issue and it is reachable.
- Evidence required: the specific code path that triggers the issue, and why existing guards don't cover it.

**MITIGATED** — The issue pattern exists but is handled elsewhere.
- Evidence required: the specific mitigation (file:line) and how it prevents the issue from being reachable.
- Action: downgrade severity by one level (Critical → High, High → Medium). If already Medium after downgrade, keep it.

**FALSE_POSITIVE** — The finding is wrong. The code does not have this issue.
- Evidence required: why the finding's analysis is incorrect (e.g., the function is never called with the claimed input, the type system prevents the claimed state, the code path is unreachable).
- Action: remove the finding entirely.

### Output Format
```
- verdict: CONFIRMED | MITIGATED | FALSE_POSITIVE
- evidence: <specific code references, file:line citations>
- adjusted_severity: <original severity or downgraded>
- note: <brief explanation for the report's "Dismissed Findings" section if FALSE_POSITIVE>
```

---

## Triage Process (orchestrator logic)

### 1. Deduplicate and Confirm
Before verification, merge findings that refer to the same issue:
- Same file + overlapping line range + same issue category → merge
- Keep highest confidence score
- Keep most specific detail (the version with a concrete scenario)
- If severities differ, keep higher but note disagreement

**Multi-specialist confirmation:** When 2+ specialists flag the same issue (matched by file + line range + issue type):
- Boost confidence by +10 (cap at 100)
- Tag finding: `[MULTI-SPECIALIST: correctness + security]` (list confirming specialists)
- This is strong signal — multiple independent reviewers found the same problem

### 2. Apply Confidence Threshold
- Default threshold: 80 (overridable via `--threshold N`)
- Findings below threshold are silently dropped — they don't appear in the report at all
- Exception: Critical findings with confidence 60+ are kept (err on the side of caution for critical issues)

### 3. Spawn Verification Agents
- Only for **Critical** and **High** findings that survived deduplication and threshold
- Launch in parallel, one Explore agent per finding
- Cap at 4 concurrent verification agents. If more than 4 findings need verification, batch them (4 at a time)
- Each agent receives the verification prompt template above with the specific finding injected

### 4. Process Verification Results
- **CONFIRMED**: keep the finding with its original (or adjusted) severity. Add "[Verified]" tag.
- **MITIGATED**: downgrade severity by one level. Add "[Mitigated — see {mitigation file:line}]" note.
- **FALSE_POSITIVE**: move to "Dismissed Findings" section with the explanation. Do NOT present it as an active finding.

### 5. Handle Disagreements
When MCP expert analysis and Explore agents disagree on the same finding:
- If MCP says issue exists and Explore verification says FALSE_POSITIVE → present both assessments, flag for user decision (Step 8 in SKILL.md)
- If Explore says issue exists and MCP doesn't mention it → keep the Explore finding (MCP may have missed it)
- If both agree → high confidence, no dispute

### 6. Confidence Display Gates

After triage, apply display rules based on final confidence:

| Confidence | Display | Label |
|------------|---------|-------|
| 90-100 | Show normally | — |
| 70-89 | Show normally | — |
| 50-69 | Show with caveat | `(medium confidence — verify this is actually an issue)` |
| Below 50 | Suppress entirely | Should already be filtered by threshold, but safety net |

### 7. Classify Fix-First

For each surviving finding, classify for the fix-first workflow:

**AUTO-FIX** (fixable: true) — Mechanical changes that don't require judgment:
- Missing null/undefined checks on obvious code paths
- Wrong comparison operator (e.g., `=` instead of `===`)
- Missing error handling where the fix pattern is clear
- Type mismatches with obvious correct type
- Missing `await` on async calls
- Convention violations with clear fix (e.g., wrong import style)

**ASK** (fixable: false) — Requires design decisions or judgment:
- Architectural changes (restructuring, new abstractions)
- Security findings where the mitigation strategy has options
- Performance fixes that involve tradeoffs (caching strategy, query restructuring)
- Any finding where "the fix" depends on business context

### 8. Final Ordering
After triage, order findings for the report:
1. Critical (verified) — by confidence descending
2. High (verified) — by confidence descending
3. Medium — grouped by file to minimize reader context switching
4. Convention violations — separated into their own section
5. Low — at the end, grouped by file
6. Dismissed — transparency section showing what was filtered and why
