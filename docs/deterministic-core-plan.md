# Deterministic core: remaining steps (4 to 6)

Written 2026-09-23. Steps 1 to 3 shipped as three stacked PRs; this file specifies what is left, so each step can be picked up in a fresh session.

## Background

An evaluation of every ccmagic skill found that converting whole skills to code is the wrong unit. Most skills mix mechanical steps that have one right answer (parse a ticket ID, decide whether CI is green, check a PR can merge) with judgment (implement, review, triage feedback). The mechanical steps are where the model kept slipping. Earlier fixes #23, #25, #27, #28 and #40 each corrected a skill that misapplied a rule written in prose.

The approach: keep every skill, move the mechanical steps into small bash scripts in `bin/` and hooks in `hooks/`, and have the skill act on the script's JSON output. Everything stays bash + `gh` + `jq`, with no Python.

## Done (steps 1 to 3)

| PR | Version | Contents |
|---|---|---|
| #42 | 3.8.0 | `bin/ccm-lib.sh` (config parsing), `ccm-context`, `ccm-ci-status`, `ccm-merge-gate`; PreToolUse merge guard; finish-ticket and merge rewired; `tests/run.sh`, `tests/stubs/gh`, `.github/workflows/tests.yml` |
| #43 | 3.9.0 | Guard also denies force pushes, secret-shaped files, and (autonomous) bad commit subjects; `hooks/lib-commit.sh` |
| #44 | 3.10.0 | `ccm-pr-threads` (disposition markers decide "handled"), `ccm-pr-reply`; SubagentStop handshake hook; auto-ticket Step 4 and pr-feedback rewired |

The PRs are stacked: #43 is based on #42's branch, and #44 on #43's. Merge in order and retarget each to `main` after the one below it merges.

## Conventions every step follows

- **Scripts** live in `bin/ccm-<name>`, source `bin/ccm-lib.sh` for config (`ccm_config_json`, `ccm_config_get`, `ccm_repo_slug`, `ccm_state_dir`), print JSON on stdout, and use exit codes documented in a header comment that `-h` prints. Exit 4 is a usage error, and 3 means "couldn't read something".
- **Config** comes from flat `key: value` lines in the YAML frontmatter of `.claude/ccmagic.local.md` (project) and `~/.claude/ccmagic.local.md` (user). Nested YAML is not parsed. Add a default for every new key to `CCM_CONFIG_DEFAULTS` in `bin/ccm-lib.sh`, and document it in `docs/ccmagic.local.md.example`.
- **Skills** call scripts as `"${CLAUDE_SKILL_DIR}/../../bin/ccm-<name>"`, grant that path in `allowed-tools` (for example `Bash(${CLAUDE_SKILL_DIR}/../../bin/ccm-validate *)`), and say the bare name works too, because plugin `bin/` is on `PATH`. Skills must not re-derive what the script decided.
- **"Autonomous"** in hooks means the hook input's `agent_type` starts with `ccmagic:auto-`, or `autonomous: true` is set in config. Plugin agents ignore `hooks:` in their own frontmatter, so hooks go in `hooks/hooks.json` and filter on `agent_type`.
- **Tests**: add cases to `tests/run.sh` for every script or hook change. Function names with the `context_`, `ci_`, `merge_gate_`, `guard_`, `post_`, `stop_`, `threads_`, or `reply_` prefix run as tests, so name helpers differently (`run_*`, `seed_*`). Add a new prefix to the runner's `grep -E` list. Fake `gh` responses go through `tests/stubs/gh` fixtures (`fx NAME JSON [RC] [STDERR]`, `fx_err NAME STDERR RC`).
- **Match CI before pushing.** CI uses Ubuntu 24.04 with shellcheck 0.9.0 and jq 1.7, which reject things newer local versions accept. The Docker commands are in `.claude/CLAUDE.md` under "Testing locally". Also run `HOOK_BASH=/bin/bash bash tests/run.sh` for macOS bash 3.2 compatibility of hooks.
- **Every PR**:
  - bump the minor version in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`;
  - add a CHANGELOG entry;
  - update the README "Hooks and scripts" section, the `doctor` file list (section 4), and the `.claude/CLAUDE.md` layout if files were added;
  - use a conventional-commit subject with no attribution trailer.

## Step 4: `ccm-validate`, and `ccm-context` in the remaining skills

One PR, version 3.11.0.

### 4a. `bin/ccm-validate`

Problem: `/ccmagic:validate` picks lint, type-check, test and build commands from a catalog in prose and judges pass or fail itself. #27 fixed `||` chains that turned a failed lint into a pass. The autonomous handshake from this skill feeds auto-ticket's fix loop (Step 4b) and so indirectly the merge decision.

Behavior:

- **Checks**, in order: `format`, `lint`, `types`, `test`, `build`. Each has at most one command, and the command's exit code is the verdict. No `||` fallbacks, ever.
- **Command source**, per check:
  1. Config key `validate_<check>` (for example `validate_lint: npm run lint`). Flat keys, because the config parser reads flat keys only. A value of `none` disables that check.
  2. Detection, only when the key is absent:
     - `package.json` scripts: `format:check`, `lint`, `typecheck` or `type-check`, `test`, `build`, run with the lockfile's package manager (`pnpm-lock.yaml` means pnpm, `yarn.lock` means yarn, otherwise npm).
     - `Makefile` targets of the same names.
     - `go.mod`: `gofmt -l .` (fails if it prints anything), `go vet ./...`, `go test ./...`, `go build ./...`.
     - `Cargo.toml`: `cargo fmt -- --check`, `cargo clippy -- -D warnings`, `cargo test`, `cargo build`.
     - `pyproject.toml`: `ruff format --check`, `ruff check`, `mypy .`, `pytest`, each only if the tool is configured in `pyproject.toml` or its own config file exists.
  3. No command found: the check is `skipped` with reason "not configured".
- **Flags**:
  - `--only a,b` runs a subset. `/ccmagic:test` uses `--only test`.
  - `--list` prints the resolved commands without running them. This lets the skill show the plan, and doctor can use it.
- **Time limits**: each check runs under `timeout` with `validate_timeout_seconds` (default 540, so a check that hits it still reports before the Bash tool's 10-minute limit; values above that let the tool call time out first). The skill therefore runs `--list` first and then one `--only <check>` call per check, each with the maximum tool timeout. A check that hits its timeout is `failed` with reason "timed out".
  - macOS may lack `timeout`; use `gtimeout` if present, otherwise run without a bound and say so in the output. `review/codex-pass.md` already handles this; reuse its approach.
- **Output**:
  - `{status: pass | fail | nothing-to-run, checks: [{name, command, source: config|detected, status: passed|failed|skipped, exit_code, duration_s, log}]}`.
  - `log` is a file under `ccm_state_dir` holding the full output. The JSON carries the last 40 lines of a failed check as `tail`.
  - Exit codes: 0 all run checks passed; 1 any failed; 2 nothing to run; 4 usage error.
- **Out of scope** for the script: coverage thresholds, security scanners, docs checks, and auto-fix. They stay optional and interactive in the skill, and the autonomous verdict never depends on them.

### 4b. Rewire `/ccmagic:validate`

- Replace sections "1. Detect Project Type and Tools" through "9. Build Verification" with: run `ccm-validate --list`, then one `ccm-validate --only <check>` per listed check, then report from the JSON.
- Keep the report format, but fill it from the JSON. Remove `.validation.json` (never implemented) in favor of the `validate_*` keys.
- Autonomous mode: the handshake is `done` exactly when every run check passed (`status: pass`). `nothing-to-run` is `done` with reason "no checks configured", which matches `no-ci` in `ccm-ci-status`. The reason line lists failed check names from the JSON.
- `/ccmagic:test`: use `ccm-validate --only test` to run the suite. Keep Steps 4 to 8 (parsing, failure diagnosis, coverage gaps), which are judgment. `framework-commands.md` remains the reference for pattern and `--affected` runs, which the script does not cover.

### 4c. Use `ccm-context` in the remaining skills

The config precedence, ticket-ID parsing and base-branch logic is still copied into `work-ticket` (Step 0a and the base-branch block in Step 6), `review-ticket` (Step 0 item 1, Step 1, and the `BASE=` block in Step 4), `pr` ("Reading Branching Configuration", target branch), `pr-feedback` (tracker for follow-ups), and `auto-ticket` Step 0 items 2 and 3.

Replace each with a call to `ccm-context` (or `ccm-context TICKET-ID` when the skill has an argument). MCP probing and prompt-relay transport detection stay in the skills, because a shell can't see MCP servers. Keep behavior identical otherwise.

### 4d. Tests

- A repo with `package.json` scripts pointing at `true` and `false` yields the right pass and fail. `lint` failing makes status `fail` even when a later check passes; this is the #27 regression test.
- A `validate_lint:` config value beats detection; `validate_test: none` skips the check.
- `pnpm-lock.yaml` selects pnpm (stub `pnpm` on PATH in the test).
- No manifest at all gives `nothing-to-run` with exit 2.
- A check exceeding `validate_timeout_seconds: 1` fails as "timed out" (run `sleep 5`).
- `--only` and `--list` behave as documented.
- `ccm-context` already has tests. Add one for an argument-supplied GitHub integer ID if touched.

## Step 5: small scripts

One or two PRs.

- **`bin/ccm-review-route`** (review). Inputs: a diff range or PR number. It applies Step 0.5 of `skills/review/SKILL.md` exactly: at most 2 files, at most 50 changed lines, no risk-path match, no new `class`/`interface`/`type`/`struct`/`enum`/`trait`, and no error-flow change; otherwise DEEP. Output `{route: QUICK|DEEP, reason, files, lines, risk_matches[]}`. The skill prints the routing line from it. `--quick`/`--deep`/`full` overrides stay in the skill. Also move the `context/review-stats.json` read and update into it (`--record specialist=findings,...`). Add eval cases to `evals/` asserting the routing line matches the script for cases 01 to 05.
- **`bin/ccm-post-review`** (review-ticket). Reads the report on stdin and posts it with `gh pr comment` only if the first line is `# Ticket-Grounded Review: {TICKET-ID}` and the body ends with a fenced block whose `status:` is `clean`, `fixable-findings` or `needs-human`, followed by `reason:` and `follow_ups:`. Otherwise it exits 1 with what is wrong. Reeve parses this format, and #40 and #41 fixed drift in it. Reuse the validation logic from `hooks/subagent-stop-handshake.sh`; consider moving it into a shared `hooks/lib-handshake.sh`.
- **`bin/ccm-doctor`**. Move the bash from `skills/doctor/SKILL.md` sections 1, 2, 4, 5, 6 and 7 into one script that emits JSON lines `{level: OK|WARN|INFO|FAIL, area, message, fix}`. The skill adds the MCP check (the model can see its tools) and renders the report. Include `ccm-validate --list` output under a "Validation" area.
- **`bin/ccm-external-review`** (codex-review, review Step 3.5). Runs Codex and Gemini passes in parallel under `timeout --kill-after=30 300`, writes each output and exit status to a run-scoped directory, and prints `{passes: [{tool, dimension, status: findings|empty|timed-out|auth-failed|unavailable|failed, exit_code, output_file}]}`. The status classification already exists in prose in `skills/review/codex-pass.md` and `skills/codex-review/SKILL.md`. Claude triage stays in the skills.

## Step 6: fully scripted auto-ticket loop (decide later)

Do not start until steps 1 to 5 have had field runs of `/ccmagic:auto-ticket` on real tickets. If runs still fail on loop control (pass counting, routing between steps, handshake parsing), move the orchestration into a plugin Workflow script (`workflows/auto-ticket.js` at the plugin root, invoked as `/ccmagic:auto-ticket` or a new name). Each step stays an agent; the loop bounds, CI waits (`ccm-ci-status`), clean check (`ccm-pr-threads`), and handshake parsing move into JS.

Open questions to settle in a design doc first:

- Whether Workflows run under Cyrus's headless invocation and prompt-relay transport.
- How the run summary and run record (the JSON Reeve reads) are produced.
- Whether the skill version stays as a fallback.

An external driver using `claude -p --output-format json --json-schema` is the alternative if Workflows don't run headless.

## Verification for each step

- `bash tests/run.sh` and `HOOK_BASH=/bin/bash bash tests/run.sh` pass; the Docker shellcheck 0.9.0 and Ubuntu 24.04 runs from `.claude/CLAUDE.md` pass.
- Mutation check: break the key logic in the new script on purpose, confirm a test fails, and restore it.
- Live: `claude -p --plugin-dir <repo> --model haiku` in a scratch repo exercises the new skill path once (for step 4: a repo with a failing lint script, and confirm validate reports it failed).
- CI green on the PR, and bot review comments answered with `ccm-pr-reply`.
