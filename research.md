---
description: Deep iterative research with source evaluation and confidence scoring
argument-hint: <topic or question to research>
allowed-tools: Read(*), Write(*), Glob(*), Grep(*), WebSearch(*), WebFetch(*), Task(*), TodoWrite(*), mcp__context7__*
model: opus
---

# Deep Research: $ARGUMENTS

Execute iterative, multi-hop research to thoroughly investigate this topic. Continue until reaching **80% confidence** or completing **5 search iterations**.

## Research Protocol

### Phase 0: Context Check
1. Check if `context/knowledge/` directory exists
2. Search for existing research files related to this topic
3. Review prior findings to avoid duplication and build on existing knowledge
4. Use TodoWrite to create a research progress tracker

### Phase 1: Initial Discovery
1. Perform initial web search on the core topic
2. Identify key entities, concepts, and authoritative sources
3. Note knowledge gaps and follow-up questions

### Phase 2: Iterative Deep Dive (up to 5 hops)

For each iteration:

**Search** → **Evaluate** → **Expand** → **Assess Confidence**

#### Source Evaluation Criteria
Score each source 0.0-1.0 based on:
- **Authority** (0.3): Official docs, peer-reviewed, recognized experts
- **Recency** (0.2): How current is the information
- **Specificity** (0.3): Directly addresses the question vs tangential
- **Corroboration** (0.2): Confirmed by multiple independent sources

Only incorporate sources scoring **≥0.6** into findings.

#### Expansion Strategies (use as appropriate)
- **Entity expansion**: Topic → Key people/orgs → Their work/positions
- **Concept deepening**: Overview → Technical details → Implementation examples  
- **Temporal progression**: Current state → Historical context → Future trajectory
- **Causal chains**: Effect → Root cause → Contributing factors

### Phase 3: Synthesis

After reaching confidence threshold or max iterations:

1. **Create findings summary** with:
   - Key findings (bulleted, prioritized by relevance)
   - Confidence level (Low/Medium/High/Very High) with rationale
   - Source quality assessment
   - Knowledge gaps that remain
   - Recommended follow-up research if needed

2. **Save to context** (if context/ directory exists):
   - Write findings to `context/knowledge/research-YYYYMMDD-[topic-slug].md`
   - Include source URLs and evaluation scores
   - Date prefix enables historical tracking and avoids overwrites

## Confidence Assessment

Calculate overall confidence based on:
- Number of high-quality sources (≥0.7 score)
- Source agreement/disagreement
- Coverage of key aspects
- Recency of information

| Sources (≥0.7) | Agreement | Confidence |
|----------------|-----------|------------|
| 5+             | High      | Very High (90%+) |
| 3-4            | High      | High (80-89%) |
| 2-3            | Mixed     | Medium (60-79%) |
| 1-2            | Any       | Low (<60%) |

**Stop iterating when confidence ≥80% OR 5 iterations complete.**

## Output Format

```markdown
# Research: [Topic]

**Date:** [YYYY-MM-DD]
**Confidence:** [X%] - [Low/Medium/High/Very High]
**Iterations:** [N] searches performed
**Sources evaluated:** [N] total, [N] incorporated (≥0.6 quality)

## Key Findings

1. [Most important finding]
2. [Second finding]
...

## Source Summary

| Source | Quality Score | Key Contribution |
|--------|---------------|------------------|
| [URL]  | [0.X]         | [What it provided] |

## Knowledge Gaps

- [What remains unknown or uncertain]

## Recommended Follow-up

- [Suggested additional research if confidence <80%]
```

## Execution Notes

- Use WebFetch to read full articles when snippets are insufficient
- Prefer primary sources over aggregators/summaries
- For technical topics, prioritize official documentation and GitHub repos
- For current events, prioritize sources from last 30 days
- If sources conflict, follow the conflict resolution process below

### Handling Conflicting Sources

When sources disagree:
1. Note both positions explicitly in findings
2. Weight by: Authority > Recency > Specificity
3. If still unresolved, mark as "contested" in findings
4. Document the nature of the disagreement for future reference

### Edge Case Handling

- If no relevant results found after 2 iterations, pivot search terms or ask user for clarification
- If WebFetch fails repeatedly, note URL in sources as "inaccessible" and continue with available sources
- For library/API research, use context7 tools to fetch official documentation directly

Begin research now on: **$ARGUMENTS**
