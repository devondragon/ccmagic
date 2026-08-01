# Codex CLI Review Pass

Supporting detail for **Step 3.5** of the `review` skill. Optional and always non-blocking — Codex is an additional voice, never a gate.

## Availability and run workspace

Check for Codex, for a timeout binary to bound it with, and create a per-run directory:

```bash
which codex 2>/dev/null && echo "CODEX_AVAILABLE" || echo "CODEX_NOT_AVAILABLE"
command -v timeout >/dev/null && echo "TIMEOUT_BIN=timeout" \
  || { command -v gtimeout >/dev/null && echo "TIMEOUT_BIN=gtimeout" || echo "TIMEOUT_BIN=none"; }
mktemp -d /tmp/ccmagic-review.XXXXXX
```

Substitute the printed temp directory for `{RUN_DIR}` below. **Don't hardcode a `/tmp` filename here.** Two `/ccmagic:review` runs sharing one fixed path truncate each other's output and then both read it back for error classification — and concurrent runs are ordinary, since `/ccmagic:review-ticket` and `/ccmagic:auto-ticket` each invoke this skill without anyone typing its name. A fixed name is also what let this file get swept into `/ccmagic:codex-review`'s result aggregation as a phantom dimension; both skills now scope their intermediates to a per-run directory.

**`timeout` is GNU coreutils, not a POSIX given.** Stock macOS ships neither `timeout` nor `gtimeout` — they appear only once someone runs `brew install coreutils`. Substitute whichever name the check printed into the command below. If it printed `TIMEOUT_BIN=none`, **skip the Codex pass** and print `No timeout/gtimeout found (brew install coreutils) — skipping cross-model review.` Running Codex without an enforced deadline is exactly the hang this step exists to prevent, so an unbounded run is not an acceptable fallback.

## Launching the pass

**If Codex is available**, launch an adversarial review pass via Bash. This runs in the background alongside the Explore agents from Step 3 — it's an independent voice, not a replacement.

```bash
timeout --kill-after=30 300 codex exec "Review the changes on this branch against the base branch. Run git diff main...HEAD to see the diff. Find ways this code will fail in production: edge cases, race conditions, security holes, resource leaks, failure modes, silent data corruption, logic errors that produce wrong results silently, error handling that swallows failures. Be adversarial. For each finding, output: severity (Critical/High/Medium/Low), confidence (0-100), file, line, issue, detail, suggestion. No compliments — just problems." -C "$(git rev-parse --show-toplevel)" -s read-only \
  > {RUN_DIR}/codex-output.txt 2>&1; echo "CODEX_EXIT=$?" >> {RUN_DIR}/codex-output.txt
```

Run via the Bash tool with `run_in_background: true` so it doesn't block the Explore agents.

**The deadline must live in the command, not in your intentions.** `timeout --kill-after=30 300` is what actually bounds this run — a backgrounded Bash task is detached and keeps running across turns, so a tool-level `timeout:` parameter does not stop it and you have no way to observe the 5-minute mark yourself. Without the shell `timeout`, a slow Codex is indistinguishable from a hung one and the review waits forever. `--kill-after` is what makes the bound hard: plain `timeout` only sends `SIGTERM`, which a process is free to trap or ignore, so without the follow-up `SIGKILL` the "deadline" is a request rather than a guarantee.

**Redirect, don't pipe.** The exit status has to survive to be read, and `cmd | tee file` throws it away — a pipeline reports `tee`'s status, so a timed-out Codex still looks like exit 0 and the 124 branch below becomes dead code. Writing the exit code into the output file with `; echo "CODEX_EXIT=$?" >> …` is what makes the deadline observable. (`tee` buys nothing here anyway: `codex exec` buffers and streams nothing to watch live.) If you do need a pipeline, `set -o pipefail` first or read `${PIPESTATUS[0]}`.

**Keep stderr.** `2>&1` into the same file is required, not cosmetic: the error handling below classifies failures by matching on stderr text, so discarding stderr (`2>/dev/null`) makes every branch of it unreachable and turns an auth failure into a silent empty result.

**An empty output file is NOT a failure signal.** `codex exec` buffers and writes nothing until it finishes, so a 0-byte file means "still working" exactly as often as it means "died". Never conclude Codex failed from an empty file, an empty `BashOutput`, or the absence of a `codex` process in `ps`. Only these are evidence: the background task reported completion, or the file ends with a `CODEX_EXIT=` line, or the output file contains an error. Until one of those, treat Codex as still running.

## Processing Codex output

After Codex completes, parse its findings into the same finding schema:

- Tag each finding with `specialist: codex`
- Set `fixable` based on the fix-first classification rules in `triage-instructions.md`
- Findings enter the same deduplication and triage pipeline as all other findings

**Multi-model confirmation:** When a Codex finding matches a finding from an Explore agent (same file + overlapping line range + same issue type), apply the multi-specialist confirmation boost (+10 confidence, tag as `[MULTI-MODEL: codex + {agent}]`). Cross-model agreement is a strong signal.

## Error handling (all non-blocking)

Read `{RUN_DIR}/codex-output.txt` to classify — that file has stderr merged in. **Branch on the `CODEX_EXIT=` line first; only a non-zero status means something went wrong.**

- `CODEX_EXIT=0` → Codex ran to completion. Everything else in the file is review output. Parse it and move on.
- `CODEX_EXIT=124` → `Codex timed out after 5 minutes — continuing without Codex findings.`
- `CODEX_EXIT=` non-zero, and the file carries an authentication error (a diagnostic line matching `not logged in`, `unauthorized`, `authentication failed`, or `run codex login` — **not** a bare `auth`/`login` substring): `Codex authentication failed. Run 'codex login' to authenticate.`
- `CODEX_EXIT=` non-zero, cause unclear → `Codex failed (exit N) — continuing without Codex findings.`
- Exited clean but the file holds nothing parseable → `Codex returned no findings — continuing.`
- Any failure: proceed with Explore agent findings only. Codex is additive, never blocking.

**Never keyword-match a successful run.** The output file holds Codex's *findings* as well as its diagnostics, and review findings routinely discuss authentication, login flows, and unauthorized access. Grepping the whole file for `auth`/`login` without first checking the exit status throws away good reviews as auth failures — the more findings Codex produced, the likelier it misfires.

Record the outcome in the report as `Codex: findings | completed — 0 findings | timed out | unparseable | unavailable | auth failed | failed (exit N)` so a reader can tell a genuinely clean cross-model pass from one that never ran.

**If Codex is not available:** Print `Codex CLI not found — skipping cross-model review. Install: npm install -g @openai/codex` and continue. This is informational, not an error.
