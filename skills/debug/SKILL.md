---
user-invocable: true
allowed-tools: Read(*), Write(*), Edit(*), Bash(*), Glob(*), Grep(*), Task(*), TodoWrite(*), AskUserQuestion(*)
description: Systematic debugging with scientific method, parallel investigation, and persistent sessions
argument-hint: "[bug description] or [resume <slug>]"
model: sonnet
---

# Structured Debugging

Systematic bug investigation using the scientific method. Persistent session files survive context resets and enable multi-session debugging.

> **Parallel execution:** When hypotheses are independent, test them simultaneously with parallel Explore agents.

## Step 1: Parse Arguments and Determine Mode

Parse `$ARGUMENTS`:
- **New session** (default): description of the bug → create new session
- **`resume <slug>`**: resume an existing debug session → load session file
- **No arguments**: use `AskUserQuestion` to gather symptoms

For resume mode:
```bash
ls context/debug/*-{slug}*.md 2>/dev/null
```
Read the session file and skip to Step 5 (continue investigation from where it left off).

## Step 2: Capture Symptoms

If `$ARGUMENTS` provides a bug description, use it. Otherwise gather via `AskUserQuestion`:
- What is the expected behavior?
- What is the actual behavior? (exact error message, wrong output, crash, hang)
- Steps to reproduce?
- When did it start? (always, after a specific change, intermittently)
- What environment? (OS, runtime version, config, data state)

## Step 3: Create Session File

```bash
mkdir -p context/debug
```

Create `context/debug/{YYYYMMDD-HHMMSS}-{slug}.md` using the template from `${CLAUDE_SKILL_DIR}/session-template.md`.

Fill in: symptoms, reproduction steps, environment, reproduction rate.

## Step 4: Classify Bug Type and Generate Hypotheses

Load `${CLAUDE_SKILL_DIR}/methodology.md` for the root cause taxonomy and hypothesis generation guidance.

### 4a. Classify the symptom type
Based on symptoms, classify as: crash/exception, wrong output, performance degradation, intermittent/flaky, or environment-specific. This narrows the investigation strategy.

### 4b. Check for regression signals
```bash
git log --oneline -20
git log --oneline --since="3 days ago"
```
If the bug is recent and there are recent commits, it's likely a regression → mark git bisect as a priority strategy.

### 4c. Generate hypotheses
Generate 2-4 hypotheses, each with:
- **Concise statement**: what you think is wrong and where
- **Likelihood**: High / Medium / Low (based on symptom analysis)
- **Prediction**: if this is the cause, then {testable prediction}
- **Experiment**: what to do to test it (specific commands, files to read, tests to run)

Rank by likelihood. Record all hypotheses in the session file.

### 4d. Identify independent hypotheses
Mark which hypotheses can be tested in parallel (no shared state or experiment interference) vs which must be sequential.

## Step 5: Investigate (Parallel When Possible)

### For independent hypotheses — parallel Explore agents
Launch up to 3 Explore agents simultaneously, one per independent hypothesis:

```
Use Task tool with:
  subagent_type: "Explore"
  prompt: |
    # Hypothesis Investigation

    ## Bug Context
    **Symptom**: {symptom}
    **Reproduction**: {steps}

    ## Hypothesis to Test
    {hypothesis statement}

    ## Prediction
    If this is correct: {expected observation}

    ## Experiment
    {what to check — specific files, code paths, git history, logs}

    ## Instructions
    1. Execute the experiment exactly as described
    2. Compare results against the prediction
    3. Report:
       - Verdict: CONFIRMED / REFUTED / INCONCLUSIVE
       - Evidence: specific file:line references, command output
       - If CONFIRMED: describe the root cause precisely
       - If REFUTED: what does this eliminate? Any new hypothesis suggested?
       - If INCONCLUSIVE: what additional experiment would be decisive?
```

### For the git bisect path (regression bugs)
When the bug is a regression with a known-good point:

```bash
# Offer automated bisection
git bisect start
git bisect bad HEAD
git bisect good {known-good-commit}
# Automate with reproduction test if available:
git bisect run {test-command}
git bisect reset
```

Use `AskUserQuestion` to confirm the known-good commit before starting bisect.

### For sequential hypotheses
Test one at a time, updating the session file after each result.

## Step 6: Evaluate Results and Update Session

After agents return or experiments complete:

### 6a. Record in session file
Add a timestamped journal entry for each investigation round:
- Which hypotheses were tested
- Verdict for each (CONFIRMED / REFUTED / INCONCLUSIVE)
- Evidence gathered (specific file:line references)
- Dead ends documented (what was eliminated and why)
- New hypotheses generated from evidence

### 6b. Assess progress
- **Root cause found** (hypothesis CONFIRMED with evidence) → proceed to Step 7
- **Hypotheses remain** → generate refined hypotheses from evidence, return to Step 5
- **All hypotheses exhausted** → broaden scope, consider categories from root cause taxonomy not yet explored

### 6c. Ask user how to proceed
If not yet resolved, use `AskUserQuestion`:

```
Debug Status: {round N complete}
Tested: {hypotheses tested and verdicts}
Current best lead: {most promising direction}

How to proceed?
- Another round — {suggested next hypotheses}
- Git bisect — narrow down the regression commit
- Blocked — save findings, pause investigation
- Widen scope — explore different root cause categories
```

## Step 7: Fix and Verify

When root cause is confirmed:

### 7a. Document root cause
Update session file with:
- Root cause category (from taxonomy)
- Location (`file:line`)
- Explanation (what the code does wrong, under what conditions)
- First introduced (commit hash if known)

### 7b. Implement fix
- If straightforward (<20 lines): implement directly
- If complex: describe the fix approach and ask for confirmation via `AskUserQuestion`

### 7c. Verify the fix
Run the reproduction steps and confirm the bug is gone:
```bash
{reproduction command that should now succeed}
```

If tests exist for the affected area, run them:
```bash
{relevant test command}
```

## Step 8: Regression Test

After fix is verified, prompt for regression test creation:

Use `AskUserQuestion`:
```
Fix verified. Create a regression test?
- Yes — write a test that reproduces the original bug (should pass now, would have caught this)
- No — skip (add a TodoWrite reminder instead)
```

If yes:
- Identify the appropriate test framework and file location
- Write a test that exercises the exact scenario that triggered the bug
- Verify the test passes with the fix and would fail without it

If no:
- Create a `TodoWrite` entry: "Add regression test for {bug slug} — {file:line}"

## Step 9: Resolution

### 9a. Update session file
- Status: `Resolved`
- Fill in: root cause, fix, verification, regression test sections
- Complete the follow-up checklist

### 9b. Move to resolved
```bash
mkdir -p context/debug/resolved
mv context/debug/{session-file} context/debug/resolved/
```

### 9c. Report summary
```
Bug resolved!

Root Cause: {category} — {brief explanation}
Location: {file:line}
Fix: {what was changed}
Regression Test: {test file or "deferred"}
Session log: context/debug/resolved/{filename}
```

### 9d. Follow-up items
If the investigation revealed related issues:
- Create `TodoWrite` entries for each
- Offer to add to `context/backlog.md` via `AskUserQuestion`

## Execution

When invoked, immediately begin investigation. For new sessions, capture symptoms and generate hypotheses quickly — don't over-plan before investigating. For resume sessions, read the session file and pick up exactly where the last investigation left off. Each round should make measurable progress: either confirm/refute a hypothesis or narrow the search space. Document everything in the session file — it's the lifeline across context resets.
