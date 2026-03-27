# Codex Triage and Claude-Originated Review

Instructions for Claude's triage of Codex/Gemini findings and Claude's own supplementary review pass.

---

## Part 1: Triage of External Findings

### Load Convention Context

Before triaging, read project conventions (silent skip if missing):
1. `CLAUDE.md` in project root
2. `.claude/CLAUDE.md`
3. `context/conventions.md`

Use these to evaluate whether a finding is intentional per project rules, or whether the finding reveals a convention violation that the external tool didn't know to flag.

### Per-Finding Evaluation

For each finding from Codex/Gemini, evaluate three dimensions:

**1. Validity — Is this real?**
- Read the actual code at the reported location
- Check if the issue is already handled elsewhere (middleware, callers, error boundaries, guards)
- Check if the trigger scenario is actually reachable
- Check if project conventions explicitly allow the flagged pattern
- Verdict: **Valid** / **Mitigated** / **False Positive** / **Convention-Allowed**

**2. Severity — Is the classification correct?**
- Critical: security vuln with exploit path, data loss, crash on production path
- High: functionality bug, missing auth check, unhandled error losing data
- Medium: measurable quality/performance concern, fragile code
- Low: minor improvement, defensive coding
- Adjust severity up or down with reasoning

**3. Actionability — What should happen?**
- **Fix now**: clear, safe fix that can be done in this session
- **Design decision**: requires discussion about approach
- **Defer**: valid but out of scope for current work
- **Dismiss**: false positive or already handled

### Multi-Model Agreement Scoring

When findings come from multiple sources (Codex + Gemini + Claude):
- **3 models agree**: confidence +15 (capped at 100)
- **2 models agree**: confidence +10
- **1 model only**: keep original confidence
- **Models disagree**: flag for user decision (Step 8 in SKILL.md)

### Deduplication

After triaging all sources:
- Same file + overlapping line range + same issue type → merge
- Keep highest confidence (with multi-model bonus applied)
- Keep most specific detail and trigger scenario
- If severities differ, keep higher and note disagreement

---

## Part 2: Claude-Originated Review Pass

After triaging external findings, Claude performs its own supplementary review focused on areas where it has an advantage over Codex/Gemini:

### What Claude Reviews

**1. Codebase Consistency**
Claude has full codebase access (Codex got a subset). Check:
- Does the new code follow the same patterns as existing code? (error handling style, import conventions, logging patterns)
- Are there established utility functions the new code should use but doesn't?
- Does the new code duplicate logic that already exists elsewhere?

**2. Convention Compliance**
Using the loaded CLAUDE.md/conventions.md:
- Does the code violate any explicit documented rules?
- Are there missing required elements? (e.g., "all endpoints must have input validation")
- Does the code follow the project's architectural layering?

**3. Integration Completeness**
- Is the new code properly connected? (exported, imported, registered, configured)
- Does it follow the same middleware/decorator/annotation patterns as peers?
- Are there missing index exports, route registrations, or DI bindings?

**4. Cross-Cutting Gaps**
Things Codex likely missed because it reviewed files independently:
- Inconsistent error handling across related endpoints
- Missing shared state updates (cache invalidation, event emission)
- Broken assumptions between producer and consumer of shared data

### What Claude Skips
- Anything already covered by a triaged Codex/Gemini finding (no duplicates)
- Security analysis (Codex/Gemini are strong here)
- Performance analysis (Codex/Gemini handle this)

### Output
Claude-originated findings use the same schema as the review skill's `finding-schema.md`:
```
- severity: Critical | High | Medium | Low
- confidence: 0-100
- file: path
- line: number or range
- issue: one-line summary
- detail: explanation with evidence
- suggestion: minimal fix
- source: claude (to distinguish from codex/gemini findings)
```

---

## Part 3: Verification of Critical/High Findings

For all Critical and High findings that survived triage (from any source), launch parallel verification Explore agents (capped at 4 concurrent):

### Verification Agent Prompt
```
Verify this code review finding by reading the actual code in context.

Finding: {FINDING}
File: {PATH}
Source: {codex|gemini|claude}

Check:
1. Does the code actually do what the finding claims?
2. Is this already handled elsewhere? (try/catch, middleware, caller, guard)
3. Can you construct a concrete scenario that triggers this issue?
4. If from project conventions — is the convention still documented and current?

Verdict: CONFIRMED | MITIGATED | FALSE_POSITIVE
Evidence: [specific code references, file:line citations]
Adjusted severity: [original or downgraded]
```

### Processing Verdicts
- **CONFIRMED** → keep with "[Verified]" tag and source attribution
- **MITIGATED** → downgrade severity by one level, note the mitigation location
- **FALSE_POSITIVE** → move to Dismissed section with explanation
