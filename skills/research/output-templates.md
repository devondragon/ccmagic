# Research Output Templates

Select the template matching the `{RESEARCH_TYPE}` determined in Step 0 of the research skill. All templates share the common header and footer defined in SKILL.md Step 7. The sections below go between them.

---

## Technology Choice

Use when comparing technologies, frameworks, libraries, or tools for a specific use case.

```markdown
## Recommendation

**Choose: [Technology X]** (Confidence: [X%])

[2-3 sentence rationale with the strongest supporting evidence]

## Comparison Matrix

| Criterion | Weight | [Tech A] | [Tech B] | [Tech C] | Winner |
|-----------|--------|----------|----------|----------|--------|
| [criterion-1] | [0.X] | [score/10] [brief note] | [score/10] [brief note] | [score/10] [brief note] | [winner] |
| [criterion-2] | [0.X] | ... | ... | ... | ... |
| ... | | | | | |
| **Weighted Total** | **1.0** | **[X.X]** | **[X.X]** | **[X.X]** | **[overall]** |

### Criterion Definitions

- **[criterion-1]** (weight: [0.X]): [Why this matters for this specific use case. What was measured.]
- **[criterion-2]** (weight: [0.X]): ...

### Weights Rationale

[Explain why criteria were weighted this way, based on the project's specific needs and constraints.]

## Key Trade-offs

### [Tech A] Advantages
- [Advantage with source citation [#N]]

### [Tech A] Risks
- [Risk with source citation [#N]]

### [Tech B] Advantages
- [Advantage with source citation [#N]]

### [Tech B] Risks
- [Risk with source citation [#N]]

## Migration/Adoption Considerations

- **Learning curve:** [assessment]
- **Integration effort:** [assessment]
- **Ecosystem compatibility:** [assessment with project-specific details]

## Disputed Points

| Claim | Position A (Source) | Position B (Source) | Assessment |
|-------|--------------------|--------------------|------------|
| [claim] | [position] ([#N]) | [position] ([#N]) | [resolved/disputed] |
```

---

## Architecture Decision

Use when evaluating architectural patterns, design approaches, or structural decisions.

```markdown
## Decision

**[Chosen approach]** (Confidence: [X%])

[2-3 sentence rationale]

## Context

- **Problem:** [What problem this decision addresses]
- **Constraints:** [Technical, business, or team constraints]
- **Existing patterns:** [What the codebase currently does]

## Options Evaluated

### Option 1: [Name]

**Description:** [How it works]

**Pros:**
- [Pro with evidence [#N]]

**Cons:**
- [Con with evidence [#N]]

**Fits constraints:** [Yes/Partially/No — explain]

### Option 2: [Name]
[Same structure]

### Option 3: [Name]
[Same structure]

## Trade-off Analysis

| Dimension | Option 1 | Option 2 | Option 3 |
|-----------|----------|----------|----------|
| Complexity | [Low/Med/High] | ... | ... |
| Scalability | [assessment] | ... | ... |
| Maintainability | [assessment] | ... | ... |
| Migration effort | [assessment] | ... | ... |
| Risk | [assessment] | ... | ... |

## Decision Rationale

1. [Primary reason — the strongest argument]
2. [Secondary reason]
3. [What tipped the balance vs the runner-up]

## Reversibility

- **Effort to reverse:** [Low/Medium/High]
- **Lock-in factors:** [What makes this hard to change later]
- **Recommended review point:** [When to re-evaluate this decision]
```

---

## Bug Investigation

Use when researching root causes, debugging strategies, or investigating unexpected behavior.

```markdown
## Root Cause

**[One-sentence root cause]** (Confidence: [X%])

## Symptoms

- [Observable symptom 1]
- [Observable symptom 2]

## Causal Chain

```
[Trigger event]
  -> [Intermediate cause 1]
    -> [Intermediate cause 2]
      -> [Root cause]
        -> [Observed symptom]
```

## Evidence

| Evidence | Source | Supports | Contradicts |
|----------|--------|----------|-------------|
| [observation] | [where found] | [hypothesis] | [hypothesis] |

## Hypotheses Evaluated

### Hypothesis 1: [Description] — [CONFIRMED/REJECTED/INCONCLUSIVE]
- **Evidence for:** [list]
- **Evidence against:** [list]
- **Verdict:** [assessment]

### Hypothesis 2: [Description] — [CONFIRMED/REJECTED/INCONCLUSIVE]
[Same structure]

## Reproduction Steps

1. [Step 1]
2. [Step 2]
3. [Expected: X, Actual: Y]

## Recommended Fix

- **Immediate:** [Quick fix to stop the bleeding]
- **Proper:** [Root cause fix with implementation guidance]
- **Preventive:** [What to add to prevent recurrence — tests, monitoring, validation]

## Related Issues

- [Links to similar bugs, related code paths, or upstream issues]
```

---

## Library Evaluation

Use when assessing whether a specific library or tool fits project needs.

```markdown
## Verdict

**[Recommended / Not Recommended / Conditionally Recommended]** (Confidence: [X%])

[2-3 sentence summary]

## Fitness Scorecard

| Criterion | Weight | Score | Notes |
|-----------|--------|-------|-------|
| API quality / DX | 0.20 | [/10] | [assessment] |
| Performance | 0.15 | [/10] | [benchmarks cited] |
| Bundle size / footprint | 0.10 | [/10] | [numbers] |
| Maintenance health | 0.15 | [/10] | [commit frequency, issue response, releases] |
| Community / ecosystem | 0.10 | [/10] | [downloads, plugins, community size] |
| Documentation quality | 0.10 | [/10] | [assessment] |
| Type safety | 0.10 | [/10] | [TS support quality] |
| Project fit | 0.10 | [/10] | [compatibility with existing stack] |
| **Weighted Total** | **1.0** | **[X.X/10]** | |

## Maintenance Health Indicators

| Metric | Value | Assessment |
|--------|-------|------------|
| Last release | [date] | [current/stale] |
| Open issues | [N] | [manageable/concerning] |
| Issue response time | [avg] | [fast/slow] |
| Contributors (last year) | [N] | [healthy/declining] |
| Breaking changes frequency | [assessment] | [stable/volatile] |
| Corporate backing | [org or "community"] | [sustainable/risky] |

## Integration Assessment

- **Install complexity:** [trivial/moderate/complex]
- **Breaking changes to existing code:** [none/minor/significant]
- **Peer dependency conflicts:** [none/list them]
- **Configuration required:** [minimal/moderate/extensive]

## Alternatives Considered

| Library | Why Not | When to Reconsider |
|---------|---------|-------------------|
| [alt-1] | [reason] | [condition] |
| [alt-2] | [reason] | [condition] |

## Risk Factors

- [Risk 1 with likelihood and mitigation]
- [Risk 2 with likelihood and mitigation]
```

---

## Migration Planning

Use when planning transitions between technologies, versions, or architectures.

```markdown
## Migration Assessment

**[Feasible / Feasible with Risks / Not Recommended]** (Confidence: [X%])

**Estimated effort:** [T-shirt size with range]
**Risk level:** [Low / Medium / High / Critical]

## Current State

- **Source:** [What we are migrating from, with version]
- **Usage scope:** [How extensively the current solution is used — files, modules, features affected]
- **Dependencies:** [What depends on the current solution]

## Target State

- **Destination:** [What we are migrating to, with version]
- **Key differences:** [Breaking changes and behavioral differences]
- **Benefits expected:** [Why migrate — quantified where possible]

## Risk Matrix

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| [risk-1] | [Low/Med/High] | [Low/Med/High] | [strategy] |
| [risk-2] | ... | ... | ... |

## Migration Phases

### Phase 1: Preparation ([estimated effort])
- [ ] [Task 1]
- [ ] [Task 2]
- **Rollback point:** [How to undo this phase]

### Phase 2: Parallel Running ([estimated effort])
- [ ] [Task 1]
- [ ] [Task 2]
- **Rollback point:** [How to undo this phase]

### Phase 3: Cutover ([estimated effort])
- [ ] [Task 1]
- [ ] [Task 2]
- **Rollback point:** [How to undo this phase]

### Phase 4: Cleanup ([estimated effort])
- [ ] [Remove old code/config]
- [ ] [Update documentation]
- **Point of no return:** [After this, rollback is impractical]

## Breaking Changes Inventory

| Breaking Change | Affected Code | Migration Path | Effort |
|----------------|---------------|----------------|--------|
| [change-1] | [files/modules] | [how to migrate] | [S/M/L] |
| [change-2] | ... | ... | ... |

## Validation Strategy

- **Phase 1 validation:** [How to verify preparation is complete]
- **Phase 2 validation:** [How to verify parallel running works]
- **Phase 3 validation:** [How to verify cutover succeeded]
- **Smoke tests:** [Critical paths to test after each phase]

## Rollback Plan

- **Trigger conditions:** [When to invoke rollback]
- **Rollback steps:** [Ordered list]
- **Data considerations:** [Any data migration that complicates rollback]
- **Maximum safe rollback window:** [How long after cutover can we still roll back]
```

---

## General

Use for research topics that do not fit the specialized templates above.

```markdown
## Summary

[3-5 sentence executive summary of findings and recommendation]

## Key Findings

1. **[Finding title]** — [Detailed explanation with source citations [#N]]
2. **[Finding title]** — [Detailed explanation with source citations [#N]]
3. **[Finding title]** — [Detailed explanation with source citations [#N]]

## Detailed Analysis

### [Aspect 1]

[Analysis with evidence and source citations]

### [Aspect 2]

[Analysis with evidence and source citations]

### [Aspect 3]

[Analysis with evidence and source citations]

## Contested or Uncertain Areas

| Topic | Position A | Position B | Current Assessment |
|-------|-----------|-----------|-------------------|
| [topic] | [view + source] | [view + source] | [assessment] |

## Recommendation

[Clear, actionable recommendation with confidence level and conditions/caveats]

## Decision Criteria

[What factors should influence the final decision, for the reader to apply their own context]
```
