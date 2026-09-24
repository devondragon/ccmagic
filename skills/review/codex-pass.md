# Codex CLI Review Pass

Supporting detail for **Step 3.5** of the `review` skill. Optional and always non-blocking — Codex is an additional voice, never a gate.

## Launching the pass

`ccm-external-review` runs the pass: it checks that Codex and a `timeout` binary are installed, creates a run-scoped directory under the git dir, runs the adversarial prompt under `timeout --kill-after=30 300`, and classifies the result. The script is also on the Bash `PATH` as `ccm-external-review` while the plugin is enabled; use the bare name if the `${CLAUDE_SKILL_DIR}` path doesn't resolve.

```bash
"${CLAUDE_SKILL_DIR}/../../bin/ccm-external-review" --tools codex --dimensions adversarial
```

Add `--base <branch>` when the review's base branch is not `main` (the prompt tells Codex to run `git diff <base>...HEAD`).

Run it via the Bash tool with `run_in_background: true`, alongside the Explore agents from Step 3. It is an independent voice, not a replacement. A pass takes up to 5.5 minutes, and the script always exits by then, so the backgrounded task's completion is the signal; do not poll the output file or `ps`.

**Do not run `codex` yourself, and do not re-derive the status.** The script holds the prompt (including the line that stops Codex from auto-loading an unrelated review skill out of `~/.codex/skills/`), the hard deadline, and the classification rules. An empty output file while the pass runs means "still working", never "failed".

## Acting on the result

The script prints JSON with one entry in `passes`. Act on its `status`:

| `status` | Say | Coverage line |
|---|---|---|
| `findings` | (parse `output_file`, below) | `findings`, or `unparseable` if nothing in it can be read as a finding |
| `empty` | `Codex returned no findings — continuing.` | `completed — 0 findings` |
| `timed-out` | `Codex timed out after 5 minutes — continuing without Codex findings.` | `timed out` |
| `auth-failed` | `Codex authentication failed. Run 'codex login' to authenticate.` | `auth failed` |
| `failed` | `Codex failed (exit N) — continuing without Codex findings.` (N is `exit_code`) | `failed (exit N)` |
| `unavailable` | the `reason` field; for a missing CLI add `Install: npm install -g @openai/codex`, for a missing timeout binary add `brew install coreutils` | `unavailable` |

Every status other than `findings` continues the review with Explore agent findings only. `unavailable` is informational, not an error. If the script itself exits 3 or 4, record Codex as `failed` with the error it printed and continue.

Record the outcome in the report as `Codex: findings | completed — 0 findings | timed out | unparseable | unavailable | auth failed | failed (exit N)` so a reader can tell a genuinely clean cross-model pass from one that never ran.

## Processing Codex output

For `findings`, read `output_file` (Codex's review; diagnostics are in `stderr_file`) and parse its findings into the same finding schema:

- Tag each finding with `specialist: codex`
- Set `fixable` based on the fix-first classification rules in `triage-instructions.md`
- Findings enter the same deduplication and triage pipeline as all other findings

**Multi-model confirmation:** When a Codex finding matches a finding from an Explore agent (same file + overlapping line range + same issue type), apply the multi-specialist confirmation boost (+10 confidence, tag as `[MULTI-MODEL: codex + {agent}]`). Cross-model agreement is a strong signal.

Findings routinely discuss authentication, logins, and unauthorized access. The script classifies auth failures only on a nonzero exit, so a `findings` pass that mentions them is still a successful review.
