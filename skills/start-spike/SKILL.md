---
user-invocable: true
allowed-tools: Read(*), Write(*), Bash(git:*), Glob(*), Grep(*), Task(*), TodoWrite(*), AskUserQuestion(*), WebSearch(*), WebFetch(*), mcp__pal__thinkdeep(*), mcp__pal__analyze(*), mcp__context7__*
description: Start working on a research spike with structured investigation phases and parallel exploration
argument-hint: spike-id (e.g., spike-001 or spike-001-research-auth)
model: opus
---

# Start Spike Investigation: $ARGUMENTS

Execute a structured, time-boxed investigation through three phases: Define, Explore, Synthesize. Parallel exploration agents investigate independent angles simultaneously. All findings are captured in a persistent session journal.

> **Parallel execution:** Launch multiple Explore agents simultaneously to investigate independent angles.

## Step 1: Spike Selection and Activation

### 1a. Locate the spike
If `$ARGUMENTS` provides a spike-id, search `context/spikes/todo/` and `context/spikes/current/` for a match. If no spike-id provided, list available spikes in `context/spikes/todo/` and use `AskUserQuestion` to choose.

### 1b. Validate no other spike is active
Check `context/spikes/current/` — if another spike exists, warn the user and ask whether to shelve it or abort.

### 1c. Activate
Move the spike file from `todo/` to `current/`. Read it and extract: core question, constraints, time-box (default: 60 minutes), success criteria, and questions to answer. Record the start time.

## Step 2: Create Session Journal

```bash
mkdir -p context/spikes/sessions
```

Create `context/spikes/sessions/{spike-id}-session.md` using the template from `${CLAUDE_SKILL_DIR}/spike-template.md`. Fill in spike metadata, start timestamp, time-box, and core question. This file is updated after every phase.

## Step 3: DEFINE Phase — Scope and Decompose

Goal: Transform the spike question into 2-4 independent investigation angles.

### 3a. Load context
Read these files if they exist:
1. `context/project.md` — project overview and tech stack
2. `context/conventions.md` — development conventions
3. `context/working-state.md` — current project state

Search `context/knowledge/` for prior research on this topic. Use Glob and Grep to find codebase files related to the spike — existing implementations, configs, dependencies.

### 3b. Decompose into investigation angles

Break the spike into 2-4 tracks. Each track needs:
- **Angle**: What aspect to investigate
- **Key questions**: 1-3 specific questions
- **Source strategy**: Which tools to use (see table)
- **Independence**: Can it run in parallel with other tracks?

| Source Need | Tool |
|-------------|------|
| Library/framework docs | `mcp__context7__resolve-library-id` + `mcp__context7__query-docs` |
| Ecosystem state, trends | `WebSearch`, `WebFetch` for full articles |
| Codebase patterns | `Grep`, `Glob`, `Read` |
| Complex trade-offs | `mcp__pal__thinkdeep` |
| Structured analysis | `mcp__pal__analyze` |

### 3c. Set up tracking
Use `TodoWrite` to create a progress tracker with one entry per angle. Record the decomposition in the session journal.

### 3d. Time check
If more than 25% of the time-box is consumed on Define, proceed immediately to Explore.

## Step 4: EXPLORE Phase — Parallel Investigation

Goal: Gather evidence for each angle. Launch parallel agents for independent tracks.

### 4a. Launch Explore agents

For each independent angle, launch via Task tool:

```
Task tool with subagent_type: "Explore"
prompt: |
  # Spike Investigation: {angle name}

  ## Context
  **Spike**: {spike title}
  **Core question**: {core question}
  **Your angle**: {angle description}

  ## Questions to Answer
  {numbered list of questions for this angle}

  ## Source Strategy
  {tools and approach from Step 3b}

  ## Instructions
  1. Investigate using the specified sources
  2. Record each finding with: source, key claim, confidence (HIGH/MEDIUM/LOW)
  3. Note contradictions between sources
  4. Flag questions you could not answer

  ## Return Format
  - Numbered findings with source attribution and confidence
  - Evidence summary: confirmed, uncertain, contradictions
  - Leads for further investigation
```

Launch 2-3 agents simultaneously for independent angles.

### 4b. Merge and assess results

After agents return:
1. Merge findings into the session journal
2. Identify corroborating evidence (same conclusion from independent sources)
3. Flag contradictions between tracks
4. Note coverage gaps

Evaluate evidence quality by: source authority (official docs > blogs > forums), recency, specificity to the question, and corroboration across sources.

### 4c. Time check and iteration

| Situation | Action |
|-----------|--------|
| Key questions answered with good evidence | Proceed to Synthesize |
| Gaps remain, under 60% of time-box | Run targeted follow-up (4d) |
| Gaps remain, over 60% of time-box | Synthesize with noted gaps |
| Over 80% of time-box | Warn user, Synthesize immediately |

### 4d. Targeted follow-up (conditional)

Launch 1-2 focused agents for specific unanswered questions. Use `mcp__pal__thinkdeep` for complex trade-off reasoning or `mcp__pal__analyze` for structured evidence analysis when standard exploration is insufficient.

### 4e. Update session journal

Add a timestamped exploration round: angles investigated, findings with evidence, contradictions, gaps, elapsed time.

## Step 5: SYNTHESIZE Phase — Decision Output

Goal: Produce a clear recommendation or "need more information" with specific gaps.

### 5a. Evaluate against success criteria

For each criterion from the spike file, mark as Met, Partially Met, or Not Met with evidence references.

### 5b. Formulate recommendation

Produce ONE of these structured outputs:

**Option A — Clear recommendation:**
```markdown
## Recommendation
**Verdict**: {recommended approach}
**Confidence**: {High/Medium/Low}

### Supporting Evidence
- {finding with source}

### Trade-offs
- Pro: {advantage}
- Con: {disadvantage}

### Alternatives Considered
- {alternative}: Rejected because {reason}
```

**Option B — Need more information:**
```markdown
## Recommendation
**Verdict**: Investigation incomplete — additional information needed

### What We Know
- {confirmed findings}

### Critical Gaps
- {gap}: Need {what would resolve it}

### Suggested Next Steps
- {action to close each gap}
- Estimated additional time: {duration}
```

### 5c. Answer each spike question

For every question in the original spike file: provide the answer (or "unanswered" with reason), cite evidence, and note confidence.

### 5d. Define follow-up actions

List: implementation tasks, architecture decisions to record, knowledge base updates, risks needing mitigation, further spikes needed.

## Step 6: Persist Results

### 6a. Finalize session journal
Complete with: end timestamp, total elapsed time, final recommendation, all findings with evidence, follow-up actions.

### 6b. Update spike file
Update the spike in `context/spikes/current/`:
- Status: `Completed` or `Needs Follow-up`
- Fill in: Findings, Recommendation, and Next Steps sections

### 6c. Update working state
If `context/working-state.md` exists, record the spike completion and one-line recommendation.

### 6d. Transfer knowledge
If `context/knowledge/` exists and findings are broadly useful, write `context/knowledge/spike-{id}-findings.md` with key conclusions and evidence.

### 6e. Move to completed
```bash
mkdir -p context/spikes/completed
mv context/spikes/current/{spike-file}.md context/spikes/completed/
```

## Step 7: Follow-up and Summary

Use `TodoWrite` for each follow-up action. Note implementation tasks for `/create-task`.

Present summary:
```
Spike Complete: {spike-id}

Question: {core question}
Verdict: {recommendation in one sentence}
Confidence: {High/Medium/Low}
Time: {elapsed} of {time-box} budget

Key Findings:
- {finding 1}
- {finding 2}
- {finding 3}

Follow-up: {count} action items created
Session Log: context/spikes/sessions/{spike-id}-session.md
```

## Execution

Begin immediately. Move through Define quickly — spend the majority of time in Explore. Every round must produce concrete findings in the session journal. Track elapsed time and warn at the time-box limit. Always produce a decision output, even if the decision is "need more information" with specific gaps. Negative results are valuable — document what was ruled out and why.

Start now on: **$ARGUMENTS**
