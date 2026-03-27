---
user-invocable: true
description: Deep iterative research with parallel exploration, source evaluation, and confidence scoring
argument-hint: <topic or question to research>
allowed-tools: Read(*), Write(*), Glob(*), Grep(*), WebSearch(*), WebFetch(*), Task(*), TodoWrite(*), mcp__context7__*, mcp__pal__analyze(*), mcp__pal__thinkdeep(*)
model: opus
context: fork
---

# Deep Research: $ARGUMENTS

Execute rigorous, multi-phase research with parallel source exploration, structured evaluation, and confidence-gated iteration. Research continues until the confidence threshold is met or evidence is exhausted — not after an arbitrary number of loops.

> **Parallel execution:** Launch multiple Explore agents simultaneously to investigate different angles. Claude Code determines when parallel execution is safe.

## Step 0: Classify Research Type

Determine which research template applies. Load `${CLAUDE_SKILL_DIR}/output-templates.md` for the output format matching the detected type.

| Pattern | Type | Key Focus |
|---------|------|-----------|
| "X vs Y", "which library", "should we use" | `technology-choice` | Comparison matrix with weighted criteria |
| "how should we structure", "design for", "pattern for" | `architecture-decision` | Trade-off analysis, ADR format |
| "why is X failing", "root cause", "debug" | `bug-investigation` | Causal chain, reproduction steps |
| "evaluate X", "is X good for", "X review" | `library-evaluation` | Fitness scoring against requirements |
| "migrate from X to Y", "upgrade path", "transition" | `migration-planning` | Risk matrix, phased rollout plan |
| *(other)* | `general` | Standard findings format |

Store the detected type as `{RESEARCH_TYPE}`. If ambiguous, default to `general`.

## Step 1: Context and Prior Knowledge

1. Check if `context/knowledge/` directory exists — search for prior research on this topic
2. Search codebase for files related to the research topic (configs, implementations, dependencies)
3. Review CLAUDE.md and project conventions for relevant context
4. Use TodoWrite to create a research progress tracker

Record what is already known vs what needs investigation. This prevents redundant work.

## Step 2: Decompose the Question

Break the research topic into 2-4 independent investigation angles. Each angle becomes a parallel exploration track.

**Example decomposition for "Should we migrate from Express to Fastify?":**
- Track A: Performance and scalability characteristics of both frameworks
- Track B: Migration effort — API compatibility, plugin ecosystem, breaking changes
- Track C: Community health — maintenance activity, adoption trends, corporate backing

Each track should be investigable independently. Tracks that depend on another track's results belong in a later iteration.

## Step 3: Source Strategy Selection

Load `${CLAUDE_SKILL_DIR}/research-methodology.md` for detailed source evaluation criteria.

Choose the right tool for each investigation track:

| Source Need | Tool | When to Use |
|-------------|------|-------------|
| Library/framework docs | `mcp__context7__resolve-library-id` then `mcp__context7__query-docs` | API syntax, config options, version-specific behavior |
| Current state of the art | `WebSearch` | Trends, benchmarks, recent announcements, community sentiment |
| Deep article content | `WebFetch` | When search snippets are insufficient — read full articles |
| Codebase patterns | `Grep`, `Glob`, `Read` | How the project currently uses a technology, existing patterns |
| Deep analytical reasoning | `mcp__pal__thinkdeep` | Complex trade-off analysis, architectural reasoning |
| Structured analysis | `mcp__pal__analyze` | When you need a second analytical perspective on findings |

**Priority order:** context7 docs > codebase exploration > web search > web fetch. Prefer authoritative primary sources over aggregators.

## Step 4: Parallel Exploration (Round 1)

Launch 2-3 Explore agents simultaneously, one per investigation track from Step 2.

Each agent receives:
- Its assigned track and specific questions to answer
- Source strategy guidance from Step 3
- Instructions to evaluate every source using the criteria in `${CLAUDE_SKILL_DIR}/research-methodology.md`
- The source record format (URL/location, authority score, recency, specificity, key claims)

Each agent returns:
- Findings with source attributions and quality scores
- Confidence estimate for its track (0-100)
- Unresolved questions or conflicts discovered
- Leads for further investigation

## Step 5: Synthesize and Assess

After Round 1 agents complete:

### 5a. Merge Findings
- Combine findings from all tracks
- Identify corroborating evidence (same claim from independent sources)
- Flag contradictions between tracks or sources

### 5b. Evaluate Source Quality
Apply the weighted scoring from `${CLAUDE_SKILL_DIR}/research-methodology.md`:

| Criterion | Weight | Score Range |
|-----------|--------|-------------|
| Authority | 0.30 | 0.0 - 1.0 |
| Recency | 0.20 | 0.0 - 1.0 |
| Specificity | 0.30 | 0.0 - 1.0 |
| Corroboration | 0.20 | 0.0 - 1.0 |

**Minimum quality threshold:** 0.6 (sources below this are noted but not used for conclusions)

### 5c. Calculate Confidence

Confidence is calculated from evidence strength, not iteration count:

| Condition | Confidence Band |
|-----------|----------------|
| 4+ high-quality sources (>=0.7) agreeing, key aspects covered | Very High (90-100%) |
| 3+ high-quality sources agreeing, most aspects covered | High (80-89%) |
| 2-3 sources agreeing, some gaps remain | Medium (60-79%) |
| Few sources, significant conflicts, or major gaps | Low (< 60%) |

**Confidence threshold: 80%.** If met, proceed to Step 7 (Synthesis). If not, proceed to Step 6.

### 5d. Resolve Conflicts

When sources disagree, do NOT simply pick one. Follow the conflict resolution process from `${CLAUDE_SKILL_DIR}/research-methodology.md`:

1. Document both positions with their sources and quality scores
2. Identify the nature of disagreement (factual, methodological, outdated, context-dependent)
3. If resolvable by source quality alone (high-authority vs low-authority), resolve and note
4. If genuinely contested, mark as "disputed" and investigate further in Step 6

## Step 6: Targeted Follow-up (Conditional)

Only execute if confidence < 80% after Step 5.

### 6a. Identify Gaps
From Step 5, determine:
- Which specific questions remain unanswered
- Which conflicts need resolution
- Which aspects lack sufficient source coverage

### 6b. Focused Exploration
Launch 1-2 targeted Explore agents to address specific gaps. These are NOT broad searches — each agent has a precise question and knows what evidence would resolve it.

### 6c. Re-assess Confidence
Merge new findings and recalculate confidence. If still below threshold:
- If progress was made (confidence increased by 10+), run one more targeted round
- If no meaningful progress, accept current confidence and note gaps explicitly
- Maximum 3 total exploration rounds (initial + 2 follow-ups)

### 6d. MCP Deep Analysis (if available)
When confidence remains below threshold after exploration rounds, use analytical MCP tools:
- `mcp__pal__thinkdeep`: For complex reasoning about trade-offs or architectural implications
- `mcp__pal__analyze`: For structured analysis of collected evidence

Integrate MCP insights as additional high-weight sources.

## Step 7: Generate Output

Select the appropriate template from `${CLAUDE_SKILL_DIR}/output-templates.md` based on `{RESEARCH_TYPE}` from Step 0.

### All research types include these common sections:

```markdown
# Research: [Topic]

**Date:** YYYY-MM-DD
**Type:** [technology-choice | architecture-decision | bug-investigation | library-evaluation | migration-planning | general]
**Confidence:** [X%] — [Low | Medium | High | Very High]
**Exploration Rounds:** [N] (initial + [N-1] follow-ups)
**Sources:** [N] evaluated, [N] incorporated (>= 0.6 quality)
```

Then the type-specific body (see output-templates.md), followed by:

```markdown
## Source Registry

| # | Source | Type | Quality | Key Contribution |
|---|--------|------|---------|------------------|
| 1 | [URL or location] | [docs/article/code/benchmark] | [0.XX] | [What it established] |

## Confidence Breakdown

| Factor | Status | Impact |
|--------|--------|--------|
| Source agreement | [High/Mixed/Low] | [+/-] |
| Aspect coverage | [X of Y covered] | [+/-] |
| Source quality | [avg score] | [+/-] |
| Recency | [current/dated] | [+/-] |

## Open Questions

- [Remaining unknowns that could change the recommendation]

## Recommended Follow-up

- [Specific next steps if confidence < 80% or decision requires validation]
```

## Step 8: Persist Results

If `context/` directory exists:
1. Write findings to `context/knowledge/research-YYYY-MM-DD-[topic-slug].md`
2. Include full source registry with evaluation scores
3. Date prefix enables historical tracking

## Step 9: Task Integration

1. Create TodoWrite entries for any recommended follow-up actions
2. For technology choices and architecture decisions, note if a formal ADR should be created

## Execution

Begin research immediately. Be thorough but efficient — every exploration round must have a clear purpose, and iteration stops when evidence supports a confident conclusion, not after burning through arbitrary rounds. Quality of sources matters more than quantity.

Start now on: **$ARGUMENTS**
