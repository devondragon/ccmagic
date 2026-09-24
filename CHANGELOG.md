# Changelog

All notable changes to ccmagic are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.12.0] — 2026-09

### Added

- `bin/ccm-review-route`: applies `/ccmagic:review` Step 0.5 in code (at most 2 files, at most 50 changed lines, no risk-path match, no new types, no error-flow change, otherwise DEEP) for a branch range, PR, or pasted diff, and prints `{route, reason, line, files, lines, risk_matches, ...}`. It also reads and updates `context/review-stats.json` (`--record name=N,...`) and reports which specialists are gated.
- `bin/ccm-post-review`: `/ccmagic:review-ticket` posts its report through it. It refuses, with exit 1 and a list of problems, a report that doesn't start with the `# Ticket-Grounded Review: {TICKET-ID}` heading or doesn't end with the fenced handshake the merge gate reads (the format #40 and #41 fixed).
- `bin/ccm-external-review`: runs the Codex and Gemini passes in parallel under `timeout --kill-after=30 300`, writes each pass's output and exit status to a run directory under the git dir (the 10 most recent are kept), and classifies each as `findings`, `empty`, `timed-out`, `auth-failed`, `unavailable`, or `failed`.
- `bin/ccm-doctor`: the doctor checks for context files, config, plugin hooks and scripts, git, branch and ticket ID, and skills run as a script that prints JSON lines `{level, area, message, fix}`, plus the `ccm-validate --list` plan under a Validation area.
- `hooks/lib-handshake.sh`: the status-handshake validation, shared by the SubagentStop hook and `ccm-post-review`.

### Changed

- `/ccmagic:review` prints the routing line from `ccm-review-route` and records specialist stats with `--record` instead of editing `context/review-stats.json`. The `auto-review` agent no longer has Write.
- `/ccmagic:review` Step 3.5 and `/ccmagic:codex-review` call `ccm-external-review` instead of running `codex` and `gemini` by hand; Claude triage stays in the skills. The dimension prompts moved into the script unchanged, and codex-review's per-pass limit drops from 600 to 300 seconds.
- `/ccmagic:doctor` renders its report from `ccm-doctor` and keeps the MCP and `gh` tracker checks. It warns when a skill listed in `/ccmagic:help` is missing, and a missing `jq` is now FAIL.
- Eval cases 01 to 05 assert that the routing line matches `ccm-review-route`, and allow Bash so the skill can run it.
- The routing line uses commas instead of dashes: `Routing → QUICK, reason: ...`.

## [3.11.0] — 2026-09

### Added

- `bin/ccm-validate`: runs `format`, `lint`, `types`, `test`, and `build`, one command per check, and uses the command's exit code as the verdict, with no `||` fallbacks. Commands come from `validate_<check>` config keys (`none` disables a check) or are detected from `package.json` scripts (with the lockfile's package manager), `Makefile` targets, `go.mod`, `Cargo.toml`, or configured `pyproject.toml` tools. Each check runs under `timeout` (or `gtimeout`) with `validate_timeout_seconds` (default 540, so a timed-out check still reports before the Bash tool's 10-minute limit). `--only` runs a subset and `--list` prints the plan. Exit 0 pass, 1 fail, 2 nothing to run.
- Config keys `validate_format`, `validate_lint`, `validate_types`, `validate_test`, `validate_build`, and `validate_timeout_seconds`.

### Changed

- `/ccmagic:validate` runs `ccm-validate --list`, then one `ccm-validate --only <check>` call per check, and fills its report from the JSON. The autonomous handshake is `done` exactly when every check that ran passed (or nothing was configured) and otherwise names the failed checks. Coverage, security, and docs checks stay optional and interactive and never affect the verdict. The unimplemented `.validation.json` file is gone in favor of the `validate_*` keys.
- `/ccmagic:test` runs the full suite with `ccm-validate --only test`; pattern, `--affected`, and coverage runs still use `framework-commands.md`.
- `work-ticket`, `review-ticket`, `pr`, `pr-feedback`, and `auto-ticket` Step 0 read config, ticket ID, and base branch from `ccm-context` instead of copies of that logic in prose. MCP probing and prompt-relay transport detection stay in the skills. `pr` now diffs against the target branch instead of a hard-coded `main`.
- `doctor` checks for `bin/ccm-validate` and reports whether a `timeout` binary is available.

### Fixed

- `tests/run.sh` ran each test inside an `if` condition, where bash ignores `set -e`, so a test passed whenever its last command did, even if an earlier `check` failed. Tests now run with `set -e` in effect, and the output capture in `run` and the hook helpers no longer aborts on a non-zero exit.

## [3.10.0] — 2026-09

### Added

- `bin/ccm-pr-threads`: review threads (grouped, with resolved/outdated state and an `open` flag), reviews, and conversation comments from one GraphQL call. `--since-id H` marks reviewer comments above a high-water mark. A thread is handled when resolved, or when the author's last reply carries a disposition marker; a `fixed` marker counts only when its commit is on the branch, newer than the review comment, and touches the thread's file. A bare "will fix" reply leaves the thread open.
- `bin/ccm-pr-reply`: posts a thread reply with a disposition marker (`fixed`, `declined`, `answered`, `deferred`), refuses a `fixed` reply citing an unpushed commit, and resolves the thread for `fixed`.
- SubagentStop hook (`hooks/subagent-stop-handshake.sh`): a `ccmagic:auto-*` step agent whose final message doesn't end with a valid status handshake is sent back once to add it, instead of the run parking with "produced no handshake". Plugin agents ignore `hooks:` in their own frontmatter, so it runs from `hooks/hooks.json` and filters on `agent_type`.

### Changed

- `auto-ticket` Step 4 reads the high-water mark and new/open threads with `ccm-pr-threads`, and waits for CI with `ccm-ci-status --watch --wait-key {run_id}-pass{n}`. The wait's total is bounded by a deadline file, which replaces the instruction to count 10-minute watch cycles in working notes. "Clean" is now `open_thread_count == 0` plus a `green` or `no-ci` CI status.
- `pr-feedback` Step 2 uses `ccm-pr-threads` instead of three REST calls plus thread reconstruction by `in_reply_to_id`. Autonomous `pr-feedback` now pushes before replying, and replies through `ccm-pr-reply`.

## [3.9.0] — 2026-09

### Added

- The PreToolUse guard now also denies force pushes (any in autonomous runs; to `main`, `master`, `develop`, `release/*`, or the default branch interactively), `git add`/`git commit` of secret-shaped files (`.env`, private keys, credential files; interactively the user can confirm with `CCMAGIC_ALLOW_SENSITIVE=1`, and `## Always Include` in `context/commit-preferences.md` is honored), and, in autonomous runs, commits whose subject isn't in conventional-commit format.

### Changed

- **Interactive behavior change:** staging or committing a secret-shaped file is now refused until the user confirms, and force-pushing to a shared branch is refused. Previously only `/ccmagic:push` asked about sensitive files, and nothing stopped a force push.
- The commit-subject parser and pattern moved to `hooks/lib-commit.sh`, shared by both commit hooks. The PostToolUse warning now also fires for `git commit` inside a chained command (`git add -A && git commit -m ...`), `-m '...'`, `--message=`, and `-F -` heredocs.

## [3.8.0] — 2026-09

### Added

- `bin/ccm-context`, `bin/ccm-ci-status`, and `bin/ccm-merge-gate`: bash scripts that print JSON for the questions skills used to answer from prose (ticket ID from the branch, resolved config, "is CI green", "may this PR merge"). `ccm-ci-status --watch --wait-key` bounds the total CI wait with a deadline file under the git dir, so the caller no longer counts watch cycles.
- `PreToolUse` guard hook: in autonomous runs, `gh pr merge` is denied while `ccm-merge-gate` fails, and always when `merge_owner: reeve`. Interactive merging is unchanged unless `merge_guard: on` is set.
- `merge_guard` config key (default `off`).
- `tests/run.sh` and a GitHub Actions workflow running it with shellcheck.

### Changed

- `finish-ticket` Steps 1 and 3 and the autonomous merge gate call `ccm-context` and `ccm-merge-gate` instead of parsing `gh` output. The PR lookup no longer requests `statusCheckRollup`, which a fine-grained PAT cannot read.
- `merge` runs `ccm-merge-gate` before merging, and no longer suggests checking for conflicts with `git merge --no-commit` in the working checkout or merging by hand into the target branch.

## [3.7.1] — 2026-09

### Fixed

- `review-ticket`: every report posted to the PR, full or delta, begins with the `# Ticket-Grounded Review:` heading and, in autonomous mode, ends with the fenced verdict handshake with the actual status filled in. The merge gate (Reeve) selects the comment by that heading and reads only a fenced `status:` line; a run on 2026-09-20 posted the handshake as bare text after a `---` and the ticket parked with `review-not-clean`.

## [3.7.0] — 2026-09

### Added

- `merge_owner: reeve` and `merge_handoff_state` in `ccmagic.local.md`. With `merge_owner: reeve`, `finish-ticket` runs its merge gate as a preflight and then hands the open PR off instead of merging (a tracker state move on Linear/JIRA, the `awaiting-merge` label on GitHub Issues, a requested state under prompt-relay); `auto-ticket` reports the run as **handed-off**. Absent the key, nothing changes.
- `auto-ticket` run summaries end with a fenced JSON run record (`ccmagic.version` 1): outcome, classification, pass counts, findings counts, and every step's handshake status, plus its reason when the sub-skill emitted one. Emitted on every outcome and transport, including parked.

## [3.6.6] — 2026-08

### Fixed

Field report: `/ccmagic:review` — a skill whose whole job is to report — was editing source, committing, and pushing.

- **The review skill told itself to fix and commit** (`skills/review/SKILL.md` Step 7, frontmatter, Step 6 report template) — Step 7a read "Apply each fix directly in source code" and "Commit each fix atomically: `git commit -m \"fix(review): FINDING-NNN — description\"`", with no flag guarding it and no line anywhere forbidding a push. Three things compounded it: the frontmatter granted `Bash(git:*, gh:*)`, which matches `git commit`, `git push`, and `gh pr create`; the Step 6 report template required a **Fixes Applied** section whose example rows are commit hashes, so even a reviewer inclined to only report had an output slot it could not fill without committing; and the push itself was never written down at all — it is what a model does next once it has commits on a branch. Reviewing and landing are now separate: fixes are opt-in behind a new `--fix` flag, `--fix` stops at the working tree, and commit/push/PR are prohibited in every mode.

  - `review` frontmatter now grants read-only subcommands only (`git diff|log|status|branch|show|rev-parse|merge-base|ls-files|blame`, `gh pr view|diff|list`, `gh repo view`) instead of `git:*, gh:*`, so a write is refused by the permission layer rather than discouraged by prose.
  - Step 7 defaults to no writes: without `--fix`, 7a and 7b are skipped entirely and the review must not offer to apply anything. With `--fix`, fixes require a clean working tree, are reported as `[FIXED] file:line`, and are left uncommitted for the user to review with `git diff`.
  - The report's **Fixes Applied** section is omitted unless `--fix` ran, and lists `file:line` instead of commit hashes.
  - `finding-schema.md` and `triage-instructions.md` no longer describe `fixable: true` as meaning "auto-applied" — it is a classification, and only a `--fix` run acts on it.

- **`review-ticket` said it never mutates code while delegating to a skill that did** (`skills/review-ticket/SKILL.md`) — line 204 has always read "This skill still only **reports and verdicts** — it does not mutate code; the caller applies fixes", and `agents/auto-review.md` ships without an `Edit` tool for the same reason, but the `review` pipeline it runs inline carried the Step 7 fix-and-commit instructions with it. It now drops `Edit(*)`, narrows its `git`/`gh` grants to read-only plus the two comment-posting subcommands it needs (`gh pr comment`, `gh issue comment`), and states explicitly that it invokes `review` without `--fix`.

  The autonomous path is unchanged and was already correct: on `fixable-findings`, `/ccmagic:auto-ticket` Step 3 applies the findings itself, pushes via `/ccmagic:push`, and re-invokes `review-ticket` with `review_pass: {n}` for a delta pass. Keeping the fix out of the reviewer is what makes that re-review meaningful — a reviewer that fixes its own findings and then verifies them is self-certifying.

## [3.6.5] — 2026-08

### Fixed

Field report: a live `/ccmagic:review` DEEP run produced **zero Codex findings and died at `CODEX_EXIT=124`**. The 3.6.3/3.6.4 work made that timeout observable and non-blocking; this fixes what was actually eating the 5 minutes.

- **Codex CLI was loading someone else's review skill and following it instead of ccmagic's prompt** (`skills/review/codex-pass.md`, `skills/codex-review/codex-prompts.md`, `skills/codex-review/SKILL.md` §4) — Codex runs its own skill auto-matcher: at the start of a run it matches the prompt against the `description` of every `~/.codex/skills/*/SKILL.md` and silently loads the best match. ccmagic's prompts open with "Review the changes on this branch … bugs, security issues, code quality", which is a near-verbatim match for GSD's `gsd-code-review` (*"Review source files changed during a phase for bugs, security issues, and code quality problems"*). Two seconds into the failing run — before touching the diff — Codex read that `SKILL.md` and its 838-line companion workflow, then followed *those* instructions: tracing risky changes into surrounding code, running tests, exploring files unrelated to the diff. It was still exploring when `timeout` killed it. Every ccmagic prompt fed to `codex` now opens with `Do not load, consult, or follow any installed skill, plugin, or workflow definition. This is a standalone review, not part of any phase-based workflow.` — the `review` skill's adversarial pass and all six `codex-review` dimension prompts (security, architecture, correctness, errors, tests, deps), which are also fed to Gemini and are unaffected by the extra line there.

  Measured against `codex-cli 0.146.1` with the skill installed: without the guard the hijack fired in 4 of 5 runs, with the first tool calls of the run being `sed` on `~/.codex/skills/gsd-code-review/SKILL.md` and `~/.codex/gsd-core/workflows/code-review.md`; with the guard prepended, 0 of 11 runs read any skill file. It is intermittent rather than deterministic, which is why the sentence must stay even when a run looks healthy. There is no flag to switch the matcher off — `codex exec --disable skills` errors with `Unknown feature flag: skills` — so the suppression has to be textual, and each file carries a note saying so, because it otherwise reads like a redundant line to clean up.

## [3.6.4] — 2026-07

### Fixed

3.6.3 fixed the fan-in deadlock in `review` and `codex-review` and named four other skills as still exposed. Two of them actually were.

- **`debug` could treat an uninvestigated hypothesis as disproven** (`skills/debug/SKILL.md` §5) — Step 5 launches up to 3 Explore agents, one per independent hypothesis, and Step 6 evaluates the results as though all of them arrived. An agent that never reports produces no verdict, and a missing verdict read as a negative result is worse here than in a review: a review loses findings, but a debugging session that silently rules out the correct hypothesis follows the wrong branch for the rest of its life. Step 5 now follows the shared fan-in protocol and records a silent agent's hypothesis as `not tested — agent did not report`, keeping it on the candidate list as the first thing to re-run when the others fail.

- **`analyze-impact` could report a missing dependency scan as a clean one** (`skills/analyze-impact/SKILL.md` §2) — Step 2 fans out three Explore agents (outward dependencies, inward dependencies, test coverage) and Step 3 consumes their results directly. If the outward-dependency agent goes silent and its silence renders as "no dependents found", the report declares a change safe at exactly the moment there is least evidence for that. Blast radius is the one output where a gap and a clean result look identical and mean opposite things. Missing directions are now labelled `unknown — agent did not report` and the summary must say the assessment is partial. `allowed-tools` gained `date:*, echo:*` for the deadline stamp, which its `Bash(git:*)` allowlist didn't cover.

- **The 3.6.3 entry overstated who was affected** — it said `debug`, `design-qa`, `browser-qa`, and `analyze-impact` "dispatch parallel agents". `design-qa` and `browser-qa` declare `Agent(*)` in `allowed-tools` but neither SKILL.md body ever instructs launching one, so there is no join to protect and nothing to fix. The exposure was real for `debug` and `analyze-impact` only.

## [3.6.3] — 2026-07

### Fixed

Field report: a live `/ccmagic:review-ticket` DEEP run **deadlocked and never produced a report**. Six dimension agents ran and five reported; the sixth's completion notification never arrived, and Codex — launched in the background — was still working. With no deadline it could observe and no sanctioned way to ship an incomplete review, the orchestrator waited indefinitely, burning turns on `echo waiting for correctness agent and codex`. It was killed and the review was redone by hand. The recovered agent reports contained a **High**-severity finding the manual review had missed, so the cost of stalling was real findings lost, not just time.

- **`review` discarded the stderr its own error handling matches on** (`skills/review/SKILL.md` §3.5) — the Codex invocation ended in `2>/dev/null`, while the *Error handling* block immediately below classifies failures by testing whether **stderr** contains `auth`/`login`/`unauthorized`. That branch was therefore unreachable, and an auth failure surfaced as an indistinguishable empty result. Codex output now goes to `{RUN_DIR}/codex-output.txt` with `2>&1`, and the error handling reads that file.

- **`review`'s 5-minute Codex timeout was documented but never enforced** (`skills/review/SKILL.md` §3.5) — the step said *"use a 5-minute timeout (`timeout: 300000`)"* while also specifying `run_in_background: true`. A backgrounded Bash task is detached and runs across turns, so a tool-level timeout does not stop it, and nothing gave the model a way to observe the 5-minute mark; the documented *"Codex timed out after 5 minutes — continuing"* branch had no trigger. The bound now lives in the command (`timeout --kill-after=30 300 codex exec …`), where it holds regardless of how the call is launched. Added a `timeout --kill-after=30 600` to each of `codex-review`'s three external review passes (Codex in branch mode, Codex per-module in full mode, Gemini), which had no deadline at all. `--kill-after` is what makes the bound hard rather than advisory: plain `timeout` sends only `SIGTERM`, which the child is free to trap or ignore.

- **The timeout signal was thrown away by the pipeline that carried it** (`skills/review/SKILL.md` §3.5, `skills/codex-review/SKILL.md` §4) — the enforced deadline above was first written as `timeout N cmd 2>&1 | tee out.txt`, but a pipeline reports the exit status of its *last* command, so `$?` was `tee`'s `0` and never `timeout`'s `124`. The "Codex timed out after 5 minutes" branch it was meant to trigger stayed unreachable — the same class of bug, at the command that replaced it. External CLI calls now redirect (`> out.txt 2>&1`) instead of piping to `tee`, which buys nothing when `codex exec` buffers its output anyway, and append the real status as a `CODEX_EXIT=` / `CLI_EXIT=` line that the error handling reads. Where the pipeline is structural — `codex-review` feeds its prompt via `cat … | codex` — `timeout` is already the last element and its status does survive, but `set -o pipefail` was added there so a failing `cat` can't feed the model an empty prompt and still report success.

- **`review` couldn't run its own timeout command** (`skills/review/SKILL.md` frontmatter) — `allowed-tools` permitted `Bash(git:*, gh:*, codex:*, which:*)`, but the new command's first token is `timeout`, matching none of them. It would have hit a permission prompt with nobody there to answer it, since `/ccmagic:auto-ticket`'s `auto-review` agent invokes this skill unattended. Allowlist extended to `command:*, timeout:*, gtimeout:*, echo:*, date:*, mktemp:*` — covering every command the reworked step now runs. (`codex-review` uses `Bash(*)` and was unaffected.)

- **`timeout` was assumed present, but it isn't on macOS** (`skills/review/SKILL.md` §3.5, `skills/codex-review/SKILL.md` §1) — it's GNU coreutils; stock macOS ships neither `timeout` nor `gtimeout`, so on a Mac without `brew install coreutils` every deadline-protected call would have failed with `command not found` — worse than the hang being fixed. Both skills now probe for `timeout`, then `gtimeout`, alongside the existing CLI-availability checks, and skip the external pass with an install hint if neither resolves. Running unbounded is explicitly not offered as a fallback: that is the stall this deadline exists to prevent.

- **An empty output file was being read as failure** (`skills/review/SKILL.md` §3.5, `skills/codex-review/SKILL.md` §5a) — `codex exec` buffers and writes nothing until it finishes, so a 0-byte file means "still working" exactly as often as "died"; in the field report this ambiguity led to Codex being declared dead while it was still running normally. Both skills now state that an empty file, an empty `BashOutput`, or absence from `ps` is **not** evidence of failure — only a reported completion, a recorded `CODEX_EXIT=` / `CLI_EXIT=` status, or an error in the output file is.

- **No fan-in protocol existed for the parallel agents** (`skills/review/SKILL.md`, new §3.9) — Step 3 dispatched up to 7 agents and Step 5 deduplicated as though every result were in hand; nothing anywhere covered an agent that never reports, which is what deadlocked the run. New *Collect agent results* step: stamp a deadline at dispatch (`date +%s` + 600), and when it passes, produce the report with what arrived. The deadline is deliberately **absolute rather than majority-conditional** — the failure being defended against is several agents going quiet at once, and a countdown that only starts once a majority has landed never starts at all in exactly that case. It governs every fan-out in the skill, not just Step 3: full mode's module agents and Cross-Module agent, the Codex pass, and Step 5c's Critical/High verification agents were all separate joins where one silent agent could stall the run. A finding whose verifier never reports is now kept at its original severity as `[Unverified]` rather than being dropped or promoted. It also bans the three things that run did — polling with no-op `echo` commands, fabricating a missing dimension, and `SendMessage`-ing a **completed** agent to ask for findings it already produced (resuming a finished agent restarts it from its transcript and it may answer as if fresh, *overwriting the report it already wrote* — recover the result by reading its output file instead).

- **A degraded review was indistinguishable from a clean one** (`skills/review/SKILL.md` §6, `skills/codex-review/SKILL.md` §8) — the report metadata listed which agents ran but had nowhere to record which ones *didn't*, so a silently omitted dimension read as "came back clean". Both report templates now carry a **Coverage** line marking any dimension as `unavailable — did not report` / `timed out`, and each external CLI as `findings | completed — 0 findings | timed out | unparseable | unavailable | auth failed | failed (exit N)`.

- **The exit status was recorded but never consulted, and keyword matching stood in for it** (`skills/review/SKILL.md` §3.5, `skills/codex-review/SKILL.md` §5a) — `review` classified an auth failure by searching its Codex output for the substrings `auth`, `login`, `unauthorized`. Once stderr was merged into that file it also held Codex's *findings*, and review findings routinely discuss authentication, login flows, and unauthorized access — so a successful review that happened to find an auth bug was discarded as an authentication failure, and the more it found, the likelier the misfire. `codex-review` was worse: it wrote a `CLI_EXIT=` line that nothing read, and Step 5a `cat`-ed every output file with no success/failure branching at all. Both skills now branch on the recorded exit status **first** and only then look for an anchored auth diagnostic (`not logged in`, `run codex login`), never a bare substring. A clean run with zero findings is now its own reportable state rather than being indistinguishable from a crash.

- **Fixed `/tmp` paths let runs contaminate each other** (`skills/review/SKILL.md` §3.5, `skills/codex-review/SKILL.md` §3) — every intermediate file was a hardcoded `/tmp` name, and `codex-review` aggregates results with `cat /tmp/codex-*-output.txt`. That glob matches `codex-review-output.txt`, the file written by the *separate* `review` skill, so a leftover from any earlier run was silently ingested as a dimension nobody ran this time — and then fed the multi-model agreement boost, inflating confidence on the strength of a stale file. Concurrent runs were worse: `codex-review-diff.txt` is opened with `>`, so one run could truncate the diff another was mid-way through piping to Codex. Since `/ccmagic:review-ticket` and `/ccmagic:auto-ticket` both reach these skills without anyone typing their names, concurrent runs are ordinary. Both skills now `mktemp -d` a per-run directory and scope every intermediate to it.

- **`codex-review` fed its models a file it never wrote** (`skills/codex-review/SKILL.md` §4) — all three CLI invocations read the dimension prompt from `/tmp/codex-{dimension}-prompt.txt`, but nothing anywhere created it; Step 4 only said to load the prompt templates into context. The `cat` would fail, and the Gemini pass — which interpolates the file with `$(cat …)` — would have sent an empty prompt and returned a confidently useless review. Step 4 now states explicitly that each selected dimension's filled-in prompt must be written to `{RUN_DIR}/codex-{dimension}-prompt.txt` before any CLI runs.

- **`codex-review` was told to use a tool it wasn't allowed to use** (`skills/codex-review/SKILL.md` frontmatter) — the new "write the dimension prompt to disk" step said to use the Write tool, but `allowed-tools` listed only `Read/Bash/Glob/Grep/Task/TodoWrite/AskUserQuestion`. The one step that had just been made non-optional was the one the skill couldn't perform. Added `Write(*)`.

- **`codex-review`'s own agent fan-outs were left unbounded** (`skills/codex-review/SKILL.md` §6, §7) — this release bounds every *external CLI* call in the skill, but its parallel Explore agents and Critical/High verification agents are the same join-on-an-agent-that-never-reports pattern the fan-in protocol exists for. Both now follow `${CLAUDE_PLUGIN_ROOT}/skills/review/fan-in-protocol.md`. Without this the stall survived in `codex-review`, one step over from where it was fixed.

- **Two skills had frontmatter that isn't valid YAML** (`skills/merge/SKILL.md:6`, `skills/pr/SKILL.md:6`) — `argument-hint: [PR-number] (optional)` parses `[…]` as a flow sequence and then fails on the trailing text, so the whole block errors out in a strict parser. Both are now quoted, and `analyze-impact`'s unquoted hint — valid, but parsed as a list rather than a string — was quoted for consistency. Pre-existing, unrelated to the deadlock work, but a release is the right time.

- **`review` referenced a check that didn't exist** (`skills/review/SKILL.md` §7) — auto-fix was to be skipped "if the working tree was dirty at the start of the review (detected in Step 0)", but Step 0 parses arguments and nothing in the skill ever ran `git status`. The precondition could never be established, so the guard never applied. It now says to run `git status --porcelain` and skip auto-fix if anything comes back.

These additions pushed `skills/review/SKILL.md` past the 500-line ceiling in `.claude/CLAUDE.md`, so Step 3.5 and Step 3.9 were extracted to `skills/review/codex-pass.md` and `skills/review/fan-in-protocol.md`, following the pattern the skill already uses for `agent-instructions.md` and `triage-instructions.md`. Both steps keep a short summary inline and load the detail via `${CLAUDE_SKILL_DIR}`. Also bumped `.claude-plugin/marketplace.json` to 3.6.3, which the original version bump missed — it had been left at 3.6.2 while `plugin.json` moved.

Scoped to `review` and `codex-review` deliberately, because they are where the field report's stall occurred and the only skills that background a CLI with `run_in_background`. `debug`, `design-qa`, `browser-qa`, and `analyze-impact` dispatch parallel agents too and remain exposed to the agent-fan-in half of this bug; extending the §3.9 collection protocol to them is follow-up work, not something this entry claims to have done.

## [3.6.2] — 2026-07

### Fixed

- **`validate` catalogued broken commands and could mask real failures** (`skills/validate/SKILL.md`) — two illustrative commands didn't work as written: `python -m ast **/*.py` (§2) errors on more than one file (the `ast` CLI accepts a single file, and `py_compile` on the line above already covers multi-file syntax checking), and `npx eslint --no-eslintrc --parser espree --no-config` (§2) uses flags that don't coexist (`--no-eslintrc` was removed in ESLint 9) with no target path. Removed the former and replaced the latter with `node --check`. Also reframed the `||` command chains: a check tool exiting non-zero usually means a real failure (lint errors, failing tests), so chaining past it with `||` masked that failure by falling through to the next tool. Added a note under *Implementation Steps* clarifying that `||` denotes *"whichever tool this project uses"* — pick one per detected stack, don't shell-fallback — split the cross-stack test chain (§6) into per-language lines, and hardened the autonomous-mode handshake (§10) to state that a non-zero exit from any selected check is a failure and must never be converted to a pass, since it gates the `/ccmagic:auto-ticket` merge decision.

## [3.6.1] — 2026-07

### Fixed

- **`doctor` ran two dead checks and under-reported config** (`skills/doctor/SKILL.md`) — the commit-hook (§4) and skill-inventory (§7) checks located the plugin via `claude plugins show ccmagic --path`, which is not a real CLI subcommand; wrapped in `$(… 2>/dev/null)` the failure was swallowed and the substitution returned empty, so the hook check always ran `test -f "/hooks/…"` against the filesystem root (always "missing") and the inventory check `ls`-ed a nonexistent `/skills` (always skipped). Both now resolve via `$CLAUDE_PLUGIN_ROOT` (the variable already used by `hooks/hooks.json`), degrading to an `INFO` line when it is unset rather than emitting a false failure. Additionally, the project-config section (§2) now parses `.claude/ccmagic.local.md` frontmatter and echoes the resolved `tracker`, `ticket_url_base`, `ticket_id_regex`, `default_qa_workflow`, `github_repo`, `autonomous`, and `needs_human_label` values (falling back to documented defaults for absent/commented keys) instead of only describing what it would report.

## [3.6.0] — 2026-07

Field hardening from the FullAuto smoke test on the live [Cyrus](https://github.com/cyrusagents/cyrus) instance: a run implemented a ticket, opened and reviewed the PR, then — unable to read the PR's checks — **ended by asking a human to confirm CI was green** instead of merging or parking. The root cause is not the pipeline but the token: Cyrus authenticates with a **fine-grained PAT**, and fine-grained PATs cannot read check runs authored by a GitHub App (GitHub Actions, and bot reviewers like Copilot/Claude, are Apps), so `gh pr checks` / `statusCheckRollup` return `Resource not accessible by personal access token` (HTTP 403) even with `Checks: read` granted. The Actions API (`gh run …`) and the Status API stay readable with `Actions: read` + `Commit statuses: read`.

### Fixed

- **CI reads are permission-robust; an autonomous run never ends by asking about CI** (`skills/auto-ticket/SKILL.md` Step 4c, `skills/finish-ticket/SKILL.md` §3b + merge gate, `skills/auto-ticket/autonomous-contract.md`) — when `gh pr checks` / `gh pr view --json statusCheckRollup` fail with a permissions 403 (a fine-grained PAT cannot read App-authored check runs), the CI wait and the merge gate now fall back to the **Actions + Status APIs**: `gh run list --commit <sha>` / `gh run watch <id>` for GitHub Actions runs (green = every run `completed` with conclusion in {success, skipped, neutral}) plus `gh api …/commits/<sha>/status` for legacy statuses, instead of treating CI as unreadable. CI is parked as "cannot read CI status" only when **both** the Checks API and the Actions/Status APIs are unreadable, and the merge gate now states explicitly that an autonomous run ends by merging or route-and-stop — **never** by emitting a question. The fallback sees GitHub Actions runs and legacy commit statuses; a repo whose required checks are third-party-App check runs (unreadable by any fine-grained token) is treated as unreadable and parked, never a false green.

## [3.5.0] — 2026-07

Hardens Linear transport selection after end-to-end validation on a live self-hosted [Cyrus](https://github.com/cyrusagents/cyrus) instance disproved the founding assumption of the prompt-relay work: Cyrus **does** provide the official hosted Linear MCP (`https://mcp.linear.app/mcp`), connecting in ~450 ms with the full toolset. `mcp` is the primary transport on Cyrus; prompt-relay is the fallback for the connect-window and for genuinely MCP-less harnesses. See `docs/mcp-transport-detection-hardening-design.md`.

### Fixed

- **Transport detection misread a *still-connecting* Linear MCP as absent** (`skills/auto-ticket/autonomous-contract.md` §7) — §7 condition (b) tested instantaneous tool *discoverability*, so at cold start on Cyrus (where the MCP connects non-blocking with ToolSearch-deferred tools) a registered-but-connecting server read as "no MCP" and the run fell to prompt-relay. Detection now keys on Linear MCP **server availability** — a `mcp__*[Ll]inear*__*` tool that is directly callable, present in the deferred/loadable list, or a server reported "still connecting" all count as present — with the pattern made explicitly case-insensitive so Cyrus's lowercase `mcp__linear__*` matches. Loading is a bounded, **non-blocking** ToolSearch attempt (no `sleep`: the raw MCP client log showed the server connects in well under a second; the real gap is a *per-context* tool-discovery lag a wait cannot bridge), falling through to prompt-relay when the tools genuinely aren't reachable.
- **A forked `auto-ticket` could get neither the MCP nor the ticket content, and stall** (`skills/auto-ticket/SKILL.md`, `skills/auto-ticket/autonomous-contract.md` §7 `fetch_ticket`, `docs/cyrus-deployment.md`) — `auto-ticket` runs `context: fork`, so it sees only its own invocation args; a harness that injects the ticket into the *parent* prompt (as the Cyrus FullAuto template did) never reaches the fork, which then had neither MCP tools (discovery lag) nor content and got stuck. Added a fork-safe **working-directory handoff file**: the harness writes the ticket title + description to `.ccmagic-ticket.md` in the working directory before invoking `auto-ticket`, which reads it (then `rm`s it, so it is never committed) when content isn't inline and no MCP is reachable — making prompt-relay an always-available floor regardless of the MCP-discovery race. The documented Cyrus prompt template is updated to write the handoff file.

### Changed

- **Sub-skills trust the orchestrator's resolved transport** (`skills/work-ticket/SKILL.md`, `skills/review-ticket/SKILL.md`, `skills/finish-ticket/SKILL.md`, `skills/pr-feedback/SKILL.md`) — when invoked with a grounding block that carries `transport:`, a sub-skill now uses that value instead of re-detecting, so transport is resolved once per run and per-step decisions can't diverge (a real inconsistency observed in testing, where one cold-start fork leaned prompt-relay while its siblings used `mcp`). Standalone invocations (no grounding block) still detect via §7.
- **Docs corrected** (`docs/cyrus-deployment.md`, `docs/cyrus-prompt-relay-transport-design.md`, `skills/doctor/SKILL.md`) — the earlier "Cyrus has no Linear MCP" framing was wrong; Cyrus provides a hosted Linear MCP, `mcp` is primary and prompt-relay the fallback. Documents the two in-container prerequisites found in testing: each repo's `allowedTools` must include `mcp__linear` (a verbatim override drops it), and the plugin directory must be readable by the session. `doctor` now notes that a registered-but-still-connecting server is present, not missing.

## [3.4.0] — 2026-07

Field-run hardening from two real-world `/ccmagic:auto-ticket` retrospectives — one run stalled silently at the CI wait, the other merged safely but only just, because its review-fix loop reasoned about instances of a bug rather than the defect class. See `docs/auto-ticket-field-hardening-design.md` for the full incident analysis.

### Fixed

- **The Step 4c CI wait** (`skills/auto-ticket/SKILL.md`, `skills/auto-ticket/autonomous-contract.md` §5) — previously specced as a sleep-based poll loop ("poll every `ci_poll_interval_seconds`"), which no orchestrator toolset could actually execute and produced a field-observed silent stall. Replaced with a bounded blocking watch: `gh pr checks --watch` invoked as a single Bash call at the maximum tool timeout, budgeted by invocation count rather than shell state (`CYCLES = ceil(ci_timeout_minutes / 10)`, since nothing persists across Bash calls), plus an evidence-based no-checks guard: an empty check set counts as "no CI configured" only when the repo has no workflow files and no required status checks; CI that exists but hasn't registered its checks yet is waited on via the head SHA's workflow run (`gh run watch`) or parked — never treated as a vacuous green. `finish-ticket`'s merge gate applies the same rule to an empty `statusCheckRollup` and still re-verifies CI status before merging, so it remains the backstop if the wait is ever skipped or misconfigured.
- **`finish-ticket` branch cleanup in linked worktrees** (`skills/finish-ticket/SKILL.md`) — `--delete-branch` was failing noisily on a worktree-per-ticket checkout. Linked-worktree detection now compares `git rev-parse --path-format=absolute --git-dir` against `--git-common-dir`; in a worktree, the merge runs without `--delete-branch`, the remote branch is deleted best-effort only once the merge is confirmed `MERGED`, and the local worktree is left in place without error — a normal solo-dev setup, not a failure. A second new error-handling path covers conflict resolution hitting "is already used by worktree at": re-run the conflict-resolution commands from that worktree path instead of failing.

### Added

- **Systemic-finding enumeration** (`skills/review/finding-schema.md`, `skills/review/agent-instructions.md`, `skills/review-ticket/SKILL.md`, `skills/auto-ticket/SKILL.md`) — an optional `systemic:` field on review findings for when an issue is one instance of a repeatable pattern; the reporting agent states the defect *class* and enumerates every instance across all reference mechanisms that could carry it (template attributes, ES-module imports, CSS `@import`/`url()`, manifests, config files, etc.), not just the mechanism of the first hit. The scoped all-clear rule is now universal across all review agents — an unscoped "no other instances" claim must be downgraded to name its search scope, since an unscoped claim is more dangerous than silence in a loop that acts on verdicts. `auto-ticket`'s Step 3 fix loop fixes a `systemic`-tagged finding as a whole class (fix every enumerated instance, re-run the enumeration search, then re-review) instead of point-fixing the reported line.
- **`work-ticket` invariant self-check and risk-ordered scoping** (`skills/work-ticket/SKILL.md`) — scope validation now requires identifying any invariant the change's safety depends on (especially one the change itself asserts in comments, docs, or the PR body) and verifying it holds repo-wide before shipping; a violated invariant is a gap to close, or `needs-human` in autonomous mode. Complex Feature scoping guidance now also prefers shipping the lower-risk slice first and requires flagging any new latent-failure mode the retained slice introduces (aggressive caching, destructive migrations, auth changes) explicitly in the PR body.
- **Delta re-reviews** (`skills/auto-ticket/autonomous-contract.md` §2, `skills/review-ticket/SKILL.md`) — the grounding block gains an optional `review_pass: {n}` field, set when `auto-ticket` re-invokes `review-ticket` from the Step 3 fix loop, plus a `previous_findings:` section listing what was just fixed. A fresh review subagent has no memory of the prior pass, so on `review_pass` ≥ 2 it verifies each prior finding fixed/not-fixed as a one-liner and posts a **delta report** — net-new findings in full, the prior report referenced rather than repeated — instead of a full fresh review. Review passes post their report as a PR comment via `gh pr comment` when a PR exists, so each pass leaves an artifact the next one can reference.
- **Idempotent run summary** (`skills/auto-ticket/SKILL.md` Step 6) — the run-summary template gains a `**Run:** {run_id}` line, and posting is skipped if a summary comment carrying that `run_id` already exists on the PR, so a same-run re-execution of Step 6 never double-posts.

### Changed

- All six `agents/auto-*.md` now declare explicit `tools:` allowlists instead of relying on prose alone to describe their capability boundary. Notably, `auto-review` structurally loses `Edit` — review can no longer mutate code, only report on it.
- `max_review_fix_passes` default raised **2 → 3** (`skills/auto-ticket/autonomous-contract.md` §5, `skills/auto-ticket/SKILL.md`, `docs/ccmagic.local.md.example`) — deliberate headroom so a systemic defect class is never left half-fixed for lack of a remaining pass.

## [3.3.0] — 2026-07

### Added

- **Prompt-relay transport** (`skills/auto-ticket/autonomous-contract.md` §7) — supports headless harnesses (e.g. [Cyrus](https://github.com/cyrusagents/cyrus)) that inject a Linear ticket directly into the prompt with no Linear MCP in the environment. Detection is content-presence — tracker resolves to `linear`, no `mcp__*Linear*__*` tool is present, and ticket content was passed in the invocation/grounding block — zero new config keys, and behavior is unchanged whenever an MCP is present. Under this transport, the contract's tracker-I/O ops branch: `fetch_ticket` reads title + description from the grounding block's `ticket_content:` section instead of calling the MCP; every `set_state` call becomes a no-op — the harness/tracker automation owns the transition, with the non-trivial moves (In Review/Done/needs-human) additionally reported as an intent via the handshake instead of performed directly; tracker writes collapse into a single consolidated final message (delimited by `=== FINAL MESSAGE TO RELAY (reproduce verbatim) ===`) rather than per-step comments; and follow-up tickets, which can't be created without an API, are listed under "Follow-ups to file" for a human to file manually. A park (`needs-human`) skips the state move entirely — that's never treated as a failure. The GitHub/PR half of the cycle (branch, push, PR, CI, merge via `gh`) is unaffected. See `docs/cyrus-deployment.md` for deployment prerequisites and the required prompt template.

### Changed

- **Grounding block** (contract §2) — now carries a `transport: {mcp | prompt-relay}` field on every sub-skill invocation, and under prompt-relay, a fenced `ticket_content:` section (title + description) since there's no MCP to fetch the ticket from.
- **Status handshake** (contract §3) — gains an optional `requested_state:` field, prompt-relay only: a sub-skill that would have transitioned ticket state reports the intended state here instead of performing the transition; the orchestrator folds it into the final summary as a `Requested state: {X}` intent line.
- **`skills/auto-ticket/SKILL.md` Notes** — corrected a stale note that claimed the autonomous cycle was already safe to run unmodified "from Cyrus's Dockerized worker" (which implicitly assumed a Linear MCP that doesn't exist in that container); it now documents the prompt-relay transport as the actual mechanism headless harnesses use, pointing to `docs/cyrus-deployment.md`.

## [3.2.0] — 2026-07

### Added

- **Per-step subagents for `/ccmagic:auto-ticket`** — each lifecycle step (work / review / pr-feedback / validate / finish / push) now runs in its own forked subagent on a best-fit model, keeping the orchestrator's context lean on long unattended runs. New thin wrapper agents live in `agents/auto-*.md`; the lifecycle skills' *logic* is reused unchanged (only three of them have their `model:` line tuned (work/review → `inherit`, push → `haiku`) — see Changed). Each step always runs in its own forked subagent.
- **Per-step model selection** — Balanced defaults (`opus` for work/review, `sonnet` for pr-feedback/finish/validate, `haiku` for push), overridable per repo with `model_<step>` keys. `auto-ticket` itself is now `context: fork`.

### Changed

- **`skills/auto-ticket/SKILL.md`** — now `context: fork`; every step routes through a `run_step` helper (forked-per-step or inline). The handshake contract is unchanged; it now returns across the subagent boundary.
- **Lifecycle-skill default models tuned** (part of the per-step model strategy, which removes the model-clobber risk at the source so per-step models are correct by construction): `work-ticket` and `review-ticket` now use `model: inherit` (scale to the session model instead of a pinned `sonnet`), and `push` now uses `model: haiku`. This also changes **interactive** use of those three skills — e.g. a human running `/ccmagic:push` now gets `haiku`. `pr-feedback`, `finish-ticket`, and `validate` stay `sonnet`.

## [3.1.0] — 2026-07

### Added

- **`/ccmagic:auto-ticket [TICKET-ID]`** — an autonomous end-to-end ticket driver. Given a ticket ID (or the current branch), it runs the full lifecycle unattended — `work-ticket → review-ticket → pr-feedback (looped) → finish-ticket` — invoking each sub-skill in autonomous mode, parsing its status handshake, and owning the single merge-or-park decision. Built for solo-dev projects and headless runners (e.g. Cyrus, Linear-triggered, Dockerized): **auto-merge with no human in the loop is intended**. The safety property is *not* "avoid merging" — it's that genuinely uncertain work is **parked** (moved to a needs-human state, commented, not merged) instead of guessed or stalled. Every run ends **merged** or **parked-needs-human**; it never hangs waiting for input.
- **`skills/auto-ticket/autonomous-contract.md`** — the shared contract the driver and sub-skills agree on: the autonomous signal, the grounding block, the status handshake vocabulary, and the single `route-and-stop` parking routine.
- **Autonomous mode (opt-in, additive) on five lifecycle skills** — `work-ticket`, `review-ticket`, `pr-feedback`, `finish-ticket`, and `push` each gained an "Autonomous mode" section describing what happens at every existing human-gate when an autonomous signal is set. Highlights:
  - **`work-ticket`** — proceeds with its own classification (recorded in the PR body), creates the PR without pausing, and treats a missing acceptance criterion as *not done* (keeps working, or parks — never commits a partial). Material implementation ambiguity → needs-human.
  - **`review-ticket`** — uses the inferred acceptance criteria without asking, applies drift rules automatically (out-of-scope stays but is flagged; missing AC = not-done; CRITICAL findings must be fixed), and emits a `clean | fixable-findings | needs-human` verdict.
  - **`pr-feedback`** — now *executes* its triage instead of only planning it: applies address-now fixes, replies to declined/question threads, files a follow-up ticket per deferred/out-of-scope item, and pushes. Conventions decide reviewer conflicts automatically; a genuine tie → needs-human.
  - **`finish-ticket`** — the Step 3 sanity check becomes a hard merge gate (mergeable + CI green + no unaddressed change-requests); anything short of that parks the ticket instead of merging. Trivial merge conflicts auto-resolve; business-logic conflicts → needs-human.
  - **`push`** — never commits a sensitive file unattended (skips it, or parks if it's genuinely required), and resolves the pre-push prompts (no upstream, behind remote) with safe defaults so an unattended run never hangs.
- **New `ccmagic.local.md` keys** (documented in `docs/ccmagic.local.md.example`): `autonomous` (bool, default `false`), `needs_human_state` (parked-ticket state), `needs_human_label` (fallback label, default `needs-human`), `max_feedback_passes` (int, default `3`), plus the other autonomous loop bounds `max_review_fix_passes` (`2`), `max_validate_attempts` (`2`), `ci_timeout_minutes` (`30`), and `ci_poll_interval_seconds` (`60`) — each has a built-in skill default and only needs setting to override.
- **User-level config file** — ccmagic config now resolves by precedence: an explicit arg / orchestrator grounding-block value → the project file `.claude/ccmagic.local.md` → the user file `~/.claude/ccmagic.local.md` → the built-in default. Personal defaults (e.g. a longer `ci_timeout_minutes`, or `autonomous: true`) can live once in the user file and be overridden per-repo.
- **`README.md` → Autonomous mode** section and a `docs/ccmagic.local.md.example` explainer covering the flow, the merge-or-park safety property, and how to turn it on.

### Changed

- **`pr-feedback`** — added `Skill(*)` to `allowed-tools` so its autonomous path can invoke `/ccmagic:push`. The interactive plan-only path is unchanged.
- **`/ccmagic:help`** and the README skill tables now list `auto-ticket` (24 skills total) and include an autonomous-workflow example.
- Autonomous behavior is strictly **additive** — every interactive path across the five modified skills is untouched; the new defaults are gated behind an explicit autonomous signal (`--autonomous` arg → orchestrator grounding block → `autonomous:` config, in that priority order).

## [3.0.3] — 2026-07

### Changed

- Add `user-invocable: true` to the three skills that omitted it (`browser-qa`, `design-explore`, `design-qa`), so all 23 skills consistently match the documented "all skills are user-invocable" convention.

### Housekeeping

- Stop tracking `.claude/settings.local.json` (a personal, machine-local Claude Code settings file) and add a `.gitignore` covering it plus editor swap/backup files. It should never have shipped in the repo or the plugin bundle.

## [3.0.2] — 2026-07

### Fixed

- Add the required `timeout` field (10s) to the PostToolUse hook entry in `hooks/hooks.json`. Claude Code treats the field as optional, but the marketplace/sandbox validator requires `timeout` (or `timeoutMs`) on every hook, which caused a `hook timeout or timeoutMs is required` error and a cascading plugin-manifest rejection.

## [3.0.1] — 2026-07

### Fixed

- Add the required `name` field to the YAML frontmatter of all 23 skills. The field matches each skill's kebab-case directory (e.g. `name: finish-ticket`). Claude Code's plugin loader infers the name from the directory, so the omission was silent locally, but the marketplace/sandbox validator requires an explicit `name` string — its absence caused `front matter must include a string name` errors and a cascading plugin-manifest rejection.

## [3.0.0] — 2026-05

**Breaking change.** ccmagic refocuses from project management to dev workflow. 23 planning/state-management skills have been removed; 3 new tracker-aware skills have been added; a non-blocking commit-format hook now ships with the plugin.

### Why this change

ccmagic v1–v2 grew into a 40-skill project-management surface: epics, features, tasks, spikes, backlogs, sessions, daily standups, checkpoints, handoffs, sync, status, progress. It worked, but in practice the maintainer ended up using other tools for the project-planning side of the loop:

- **[GSD](https://github.com/devondragon/gsd)** for milestone planning, roadmaps, phase-based execution, and the structured workflow side of large projects.
- **[Superpowers](https://github.com/anthropics/superpowers)** for shorter-lived feature work, brainstorming, plan execution, and test-driven discipline.

Both tools were doing the planning job better than ccmagic, but ccmagic kept its planning skills around for backward-compatibility. The result was a plugin pulling in two directions: half of the surface was duplicating what GSD/Superpowers already did, and the half that was genuinely useful (code review, push/pr/merge, debug, design QA, research) was buried under the planning verbs.

v3 strips the planning side and **goes all-in on the dev workflow loop**: pick up a ticket → branch → implement → review → PR → merge → close. The skills that survived are the ones that earned their keep on every single workday regardless of how the planning was being done.

### What replaces the removed skills

The intent is that ccmagic v3 + your planning tool of choice covers the full loop:

| If you used… | Now use… |
|---|---|
| `/ccmagic:plan`, `/ccmagic:create-features`, `/ccmagic:create-tasks` | GSD `/gsd:plan-phase` or Superpowers `brainstorming` skill |
| `/ccmagic:start-task`, `/ccmagic:current-task`, `/ccmagic:complete-task` | GSD `/gsd:execute-phase`, or use `/ccmagic:work-ticket {ID}` if work is tracker-driven |
| `/ccmagic:checkpoint`, `/ccmagic:handoff`, `/ccmagic:context-save`, `/ccmagic:context-load` | GSD `/gsd:pause-work` + `/gsd:resume-work`, or rely on Claude Code's native context management |
| `/ccmagic:status`, `/ccmagic:progress`, `/ccmagic:daily-standup` | GSD `/gsd:progress` + `/gsd:stats` |
| `/ccmagic:discuss-feature` | GSD `/gsd:discuss-phase` or Superpowers `brainstorming` |
| `/ccmagic:add-backlog`, `/ccmagic:blockers` | GSD backlog system, or your tracker (Linear, GitHub, JIRA) |
| `/ccmagic:verify` | `/ccmagic:review-ticket` (now checks AC against the diff), or GSD `/gsd:verify-work` |
| `/ccmagic:sync`, `/ccmagic:quick-start`, `/ccmagic:resume`, `/ccmagic:create-spike`, `/ccmagic:start-spike` | GSD equivalents, or drop them |

If you weren't using GSD or Superpowers, v3 is still useful — the tracker-aware skills (`work-ticket`, `review-ticket`, `finish-ticket`) and the dev verbs (`push`, `pr`, `review`, `debug`, etc.) cover most day-to-day work. You'll just lose ccmagic's own project-management story.

### Added

- **`/ccmagic:work-ticket {ID}`** — End-to-end ticket workflow. Detects your tracker (Linear / GitHub Issues / JIRA), looks up the ticket, classifies the work (Quick Fix / Complex Feature / Debugging), creates a branch, runs the right execution path, validates scope against the ticket, and opens a PR. Replaces the JIRA-only version that lived in the `general-dev-claude-plugin`.
- **`/ccmagic:review-ticket [ID]`** — Code review *grounded in the ticket's stated scope*. Fetches the ticket and acceptance criteria, runs `/ccmagic:review` with the ticket as the primary intent source, and adds an explicit Ticket-scope drift section: in-scope changes, out-of-scope changes (need justification), missing-from-ticket AC items.
- **`/ccmagic:finish-ticket [--qa]`** — Closes a ticket end-to-end after the PR is ready. Sanity-checks the PR (CI, reviews, scope alignment), confirms disposition (Done by default, QA opt-in), merges with the right strategy, and posts the merge back to the tracker.
- **Multi-tracker support** for the three skills above. Linear (via Linear MCP), GitHub Issues (via `gh` CLI), JIRA (via Atlassian MCP). Auto-detection cascade based on MCP availability, CLI availability, branch hints, and `.claude/ccmagic.local.md` configuration.
- **Commit-format hook** (`hooks/post-tool-use-commit.sh`) — Non-blocking PostToolUse hook that validates every commit's subject line against the conventional-commit format. Warns but never rejects, so it's safe on repos with non-conventional commit history.
- **`.claude/ccmagic.local.md`** — Per-project tracker config (which tracker, URL base, ticket ID regex, QA workflow toggle, GitHub repo). Template in `docs/ccmagic.local.md.example`. Created by `/ccmagic:init` and edited by `/ccmagic:settings`.

### Changed

- **`/ccmagic:review`** now has adaptive QUICK/DEEP routing. QUICK is an inline checklist pass; DEEP is the full multi-agent pipeline (4 core agents + conditional specialists + Codex CLI + MCP fallback + Critical/High verification). Default routing is biased toward DEEP — QUICK only fires for clearly trivial diffs (≤2 files, ≤50 lines, no risk paths, no new types, no error-handling changes). Override with `--quick` or `--deep`.
- **`/ccmagic:init`** is heavily slimmed. v2 created an epic/feature/task/spike/session/backlog directory tree. v3 creates only `context/conventions.md`, `context/branching.md`, `context/knowledge/`, and `.claude/ccmagic.local.md`. No planning state.
- **`/ccmagic:doctor`** rewritten to check the new surface: project config files, tracker integration availability, commit hook installation, branch convention compliance. v2 checked epic/feature/task directory health, which is no longer relevant.
- **`/ccmagic:help`** rewritten around the new 23-skill surface.
- **`/ccmagic:settings`** trimmed to tracker-related knobs (default tracker, QA workflow, ticket-ID regex override). Removed knobs for the deleted planning skills.
- **`.claude/CLAUDE.md`** consolidated. Now contains two parts: (1) ccmagic conventions documented for consuming projects (commit format, branch naming, ticket-ID regex), and (2) plugin-development notes for anyone editing ccmagic itself. The conventions live here (not at the plugin root) so they don't leak into consuming-project context.
- **Plugin description and keywords** updated to reflect the dev-workflow focus.

### Removed

- 23 project-management skills: `add-backlog`, `blockers`, `checkpoint`, `complete-task`, `context-load`, `context-save`, `create-features`, `create-spike`, `create-tasks`, `current-feature`, `current-task`, `daily-standup`, `discuss-feature`, `handoff`, `plan`, `progress`, `quick-start`, `resume`, `start-spike`, `start-task`, `status`, `sync`, `verify`.
- `skills/init/full-template.md` (the full-mode template that built the epic/feature/task tree).
- Planning-state references throughout the kept skills: `/ccmagic:status` follow-ups in `pr`/`merge`/`validate`/`test`, `context/working-state.md` updates in `push`, `context/backlog.md` offers in `debug`, `context/features/*/tasks/` lookups in `analyze-impact`/`test`/`review`/`codex-review`, `/ccmagic:init`/`/ccmagic:plan` next-step pointers in `map-codebase`.

### Migration from v2.x

Existing v2.x project directories (`context/features/`, `context/tasks/`, etc.) aren't auto-migrated — they're harmless if left in place but no v3 skill reads them. You can delete them, archive them, or leave them.

Kept files:
- `context/conventions.md` — coding standards (read by `review`, `codex-review`, `pr-feedback`, `push`, `quick`)
- `context/branching.md` — branch strategy (read by `pr`, `merge`)
- `context/knowledge/*.md` — architecture/stack/conventions (produced by `map-codebase`; read by `review`, `codex-review`, `analyze-impact`)

New files:
- `.claude/ccmagic.local.md` — tracker config (created by `/ccmagic:init`)

The recommended migration path:

1. Back up your v2 `context/` directory if you want to preserve historical planning data.
2. Run `/ccmagic:init` — it's idempotent and won't touch existing `conventions.md`/`branching.md`/`knowledge/` files; it'll just add `.claude/ccmagic.local.md` and any missing files.
3. Run `/ccmagic:doctor` to confirm the setup is healthy.
4. If you used `/ccmagic:map-codebase` before, you can re-run it to refresh `context/knowledge/` against the current state of the code.

### Repository structure

```
ccmagic/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── skills/
│   └── <name>/SKILL.md          # 23 skills
├── hooks/
│   ├── hooks.json
│   └── post-tool-use-commit.sh
├── docs/
│   └── ccmagic.local.md.example
├── .claude/
│   └── CLAUDE.md                # Conventions + dev notes (not auto-loaded)
├── README.md
├── CHANGELOG.md
└── LICENSE
```

---

## [2.3.1] and earlier

See git history. v2.x was a 40-skill project-management plugin centered on epics/features/tasks/spikes/sessions, with code-review and design-QA verbs alongside. The planning surface was the headline feature; v3 inverts that.
