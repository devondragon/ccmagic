# Research Methodology

This file defines the source evaluation framework, iteration strategy, confidence calculation, and conflict resolution process used by the research skill.

---

## Source Evaluation Criteria

Every source encountered during research must be scored on four weighted dimensions. The composite score determines whether findings from that source are incorporated into conclusions.

### Scoring Dimensions

#### Authority (Weight: 0.30)

How trustworthy is the source based on its origin?

| Score | Criteria |
|-------|----------|
| 0.9 - 1.0 | Official documentation, specification documents, peer-reviewed research, original author/maintainer |
| 0.7 - 0.8 | Recognized industry experts, well-known technical blogs (with author credentials), reputable benchmarks with methodology |
| 0.5 - 0.6 | Community wikis with editorial oversight, Stack Overflow accepted answers with high votes, established tech publications |
| 0.3 - 0.4 | Personal blogs, forum posts, unverified tutorials |
| 0.0 - 0.2 | Anonymous sources, AI-generated content without verification, marketing materials |

#### Recency (Weight: 0.20)

How current is the information relative to the topic's rate of change?

| Score | Criteria |
|-------|----------|
| 0.9 - 1.0 | Published within last 3 months, or covers the current/latest version |
| 0.7 - 0.8 | Published within last 12 months, covers a recent version |
| 0.5 - 0.6 | Published within last 2 years, information likely still accurate |
| 0.3 - 0.4 | Published 2-4 years ago, may be partially outdated |
| 0.0 - 0.2 | Over 4 years old, or covers a deprecated version |

**Adjustment:** For stable/mature topics (algorithms, protocols, language specs), recency matters less. Shift all scores up by 0.2 for evergreen content.

#### Specificity (Weight: 0.30)

How directly does the source address the research question?

| Score | Criteria |
|-------|----------|
| 0.9 - 1.0 | Directly answers the exact question with concrete evidence, examples, or data |
| 0.7 - 0.8 | Addresses the topic with relevant detail, requires minor inference to apply |
| 0.5 - 0.6 | Related to the topic but covers it broadly or tangentially |
| 0.3 - 0.4 | Adjacent topic that provides some useful context |
| 0.0 - 0.2 | Barely relevant, requires significant extrapolation |

#### Corroboration (Weight: 0.20)

Is this finding confirmed by independent sources?

| Score | Criteria |
|-------|----------|
| 0.9 - 1.0 | Confirmed by 3+ independent, high-authority sources |
| 0.7 - 0.8 | Confirmed by 2 independent sources |
| 0.5 - 0.6 | Confirmed by 1 other source, or consistent with official docs |
| 0.3 - 0.4 | Single source, no corroboration found but plausible |
| 0.0 - 0.2 | Contradicted by other sources, or extraordinary claim without evidence |

### Composite Score Calculation

```
composite = (authority * 0.30) + (recency * 0.20) + (specificity * 0.30) + (corroboration * 0.20)
```

### Quality Thresholds

| Composite Score | Classification | Usage |
|-----------------|---------------|-------|
| >= 0.8 | Excellent | Primary evidence for conclusions |
| 0.7 - 0.79 | High quality | Strong supporting evidence |
| 0.6 - 0.69 | Acceptable | Supporting evidence with caveats |
| 0.5 - 0.59 | Marginal | Note in source registry but do not base conclusions on |
| < 0.5 | Poor | Exclude from findings, note only if contradicts high-quality sources |

---

## Source Record Format

Each source must be recorded with this structure for the final report:

```
- url_or_location: [URL, file path, or "context7: library@version"]
- type: [official-docs | benchmark | article | forum | code | specification | book]
- authority: [0.0-1.0]
- recency: [0.0-1.0]
- specificity: [0.0-1.0]
- corroboration: [0.0-1.0]
- composite: [calculated]
- key_claims: [list of specific claims extracted from this source]
- accessed: [YYYY-MM-DD]
```

---

## Iteration Strategy

Research proceeds through exploration rounds, each with a clear purpose. Iteration is driven by evidence gaps, not by a fixed count.

### Round Planning

Before each round, answer:
1. **What specific questions remain unanswered?** — List them explicitly.
2. **What evidence would resolve each question?** — Define what "good enough" looks like.
3. **What is the most efficient way to find that evidence?** — Choose the right tool (see source strategy in SKILL.md).
4. **What is the expected confidence gain?** — If a round cannot plausibly increase confidence by 10+, it is not worth running.

### Round Execution Rules

- **Round 1 (always):** Broad parallel exploration — 2-3 agents covering different investigation angles.
- **Round 2 (if confidence < 80%):** Targeted gap-filling — 1-2 agents addressing specific unresolved questions.
- **Round 3 (if confidence increased by 10+ in Round 2 but still < 80%):** Final targeted push.
- **No Round 4.** If three rounds cannot reach confidence, accept the current level and document gaps.

### Stopping Conditions

Stop iterating when ANY of these are true:
- Confidence >= 80% (success)
- Three exploration rounds completed (maximum effort)
- Two consecutive rounds with < 5% confidence improvement (diminishing returns)
- No new sources or evidence found in the latest round (evidence exhausted)
- The question is fundamentally unanswerable with available tools (acknowledge and explain)

---

## Confidence Calculation

Confidence is a composite measure of evidence strength, not a subjective feeling.

### Input Factors

| Factor | Measurement |
|--------|-------------|
| **Source quantity** | Number of incorporated sources (quality >= 0.6) |
| **Source quality** | Average composite score of incorporated sources |
| **Source agreement** | Proportion of sources that agree on key claims |
| **Aspect coverage** | Proportion of the research question's facets that have evidence |
| **Conflict severity** | Number and importance of unresolved conflicts |

### Calculation Method

```
base_confidence = min(
  source_count_factor,        # 0-25 points: 5 pts per high-quality source, cap at 25
  source_quality_factor,      # 0-25 points: avg_quality * 25
  agreement_factor,           # 0-30 points: agreement_ratio * 30
  coverage_factor              # 0-20 points: coverage_ratio * 20
)

confidence = base_confidence - conflict_penalty
# conflict_penalty: 5 per unresolved minor conflict, 15 per unresolved major conflict
```

This is a guide, not a formula to execute literally. Use it to calibrate your confidence estimate.

### Confidence Interpretation

| Range | Label | Meaning |
|-------|-------|---------|
| 90-100% | Very High | Strong evidence from multiple authoritative sources with high agreement |
| 80-89% | High | Sufficient evidence to act on, minor gaps acceptable |
| 60-79% | Medium | Partial evidence, notable gaps or conflicts, recommendation is tentative |
| 40-59% | Low | Significant uncertainty, recommendation requires validation |
| < 40% | Very Low | Insufficient evidence, cannot make a meaningful recommendation |

---

## Conflict Resolution Process

When sources disagree, this is a signal to investigate further, not to pick a winner.

### Step 1: Classify the Disagreement

| Type | Description | Resolution Path |
|------|-------------|-----------------|
| **Factual** | Sources cite different numbers, dates, or facts | Verify against primary/official source |
| **Methodological** | Sources reach different conclusions from different approaches | Assess which methodology is more appropriate for the context |
| **Temporal** | One source is outdated, the other reflects current state | Prefer the more recent source, verify the change actually occurred |
| **Contextual** | Both are correct but in different contexts | Document both with their applicable contexts |
| **Genuine** | Experts legitimately disagree | Present both positions, weight by authority, flag as disputed |

### Step 2: Investigate

For factual, methodological, and temporal conflicts:
1. Seek a third independent source to break the tie
2. Check official documentation or changelogs for factual conflicts
3. Look for meta-analyses or comparative studies for methodological conflicts

### Step 3: Document

Every conflict that appears in findings must include:
- The specific claim in dispute
- The sources on each side (with quality scores)
- The conflict type
- Resolution (if achieved) with evidence
- If unresolved: both positions presented fairly, flagged as "disputed"

### Step 4: Impact on Confidence

- Resolved conflicts: no penalty (they actually increase confidence by showing thoroughness)
- Unresolved minor conflicts (peripheral to the main question): -5% confidence per conflict
- Unresolved major conflicts (central to the recommendation): -15% confidence per conflict

---

## Exploration Agent Instructions

Each Explore agent launched during research receives these instructions along with its specific track assignment.

### Agent Prompt Template

```
You are investigating: [TRACK DESCRIPTION]

Specific questions to answer:
1. [Question 1]
2. [Question 2]
...

Source strategy:
- [Which tools to use and in what order for this track]

For every source you consult, record:
- URL or location
- Source type (official-docs, benchmark, article, forum, code, specification)
- Authority score (0.0-1.0): based on source origin and author credentials
- Recency score (0.0-1.0): based on publication date relative to topic
- Specificity score (0.0-1.0): how directly it addresses the question
- Key claims: specific facts or conclusions extracted

For every finding, attribute it to its source(s).

Flag any contradictions between sources — do not silently resolve them.

Return:
1. Findings (with source attributions)
2. Source records (scored)
3. Unresolved questions
4. Contradictions found
5. Your confidence estimate for this track (0-100)
```
