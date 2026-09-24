# Fan-in Protocol — Collecting Agent Results

Supporting detail for **Step 3.9** of the `review` skill. This is the rule that keeps a review from hanging forever on an agent that never reports.

## Why this exists

Steps 3 and 3.5 dispatch up to 7 agents plus Codex. **Some of them will not report back.** A completion notification can be dropped, an agent can finish abnormally, a CLI can die silently. The pipeline must degrade, not stall — a review that never produces a report is strictly worse than one that reports five dimensions out of six and says so.

## Foreground agents

Agents are dispatched in the foreground (`run_in_background: false`, one message per batch; see the skill's parallel-execution note), so their results arrive in the dispatch message. An agent that errors or returns no findings block counts as not reported. The deadline and waiting rules below matter for anything still running in the background, which is the Codex pass in an interactive run.

## Every fan-out, not just Step 3

Each of these is a join where one silent agent stalls the whole run, and each gets its own deadline:

| Join point | Waiting on |
|---|---|
| Step 3 (branch/PR mode) | up to 7 concern agents |
| Step 3 (full mode) | module agents, then the Cross-Module Agent |
| Step 3.5 | the Codex pass (backgrounded in an interactive run) |
| Step 5c | Critical/High verification agents (4 concurrent) |

## Set the deadline at dispatch, not when you start to worry

Stamp the batch when you launch it and compute its expiry up front:

```bash
echo "BATCH_DEADLINE=$(( $(date +%s) + 600 ))"
```

Ten minutes, or the longest `timeout` in the batch if that is longer. When a completion notification arrives, compare `date +%s` against the stamp. Past it, **stop waiting and produce the report** with whatever arrived.

**The deadline is absolute, never majority-conditional.** Do not wait for most agents to report before starting to count down. The failure this protects against is precisely the one where *several* agents go quiet — if you only start the clock once a majority has landed, a batch that loses half its agents never starts the clock at all, and the run hangs exactly as it did before. The deadline runs from dispatch regardless of how many have reported, including zero.

## Never do these while waiting

- **Do not poll with no-op commands.** `echo waiting for the correctness agent` does nothing except consume a turn. There is nothing to poll — agent completions arrive as notifications on their own.
- **Do not `SendMessage` a completed agent to ask for findings it already produced.** Resuming a finished agent starts it from its transcript, and it may answer as if fresh — *overwriting the report it already wrote*. Its result already exists on disk. Read the agent's output/transcript file instead. Recover, don't re-run.
- **Do not fabricate, infer, or "reconstruct" a missing agent's findings.** An absent dimension is absent.

## Report what actually ran

Mark every dimension that did not report as `unavailable — did not report` in the report's agent roster, and say so in your summary. A degraded review must be visibly degraded; silently omitting a dimension lets a reader believe it came back clean.

If **no** agent reported, say so plainly and stop — do not emit an empty report implying the code is clean.
