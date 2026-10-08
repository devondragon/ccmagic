---
name: validate
user-invocable: true
allowed-tools: Read(*), Bash(*), Bash(${CLAUDE_PLUGIN_ROOT}/bin/ccm-validate *), Bash(ccm-validate *), Glob(*), Task(*), TodoWrite(*)
description: Pre-commit validation that runs the project's format, lint, type, test, and build checks and reports pass or fail
model: sonnet
context: fork
---

# Validate Command

Comprehensive pre-commit validation to ensure code quality, tests pass, and changes are ready for PR.

## What decides pass or fail

`ccm-validate` resolves and runs the checks: `format`, `lint`, `types`, `test`, `build`, in that order. Each check has at most one command, from the config key `validate_<check>` in `ccmagic.local.md` (`none` disables it) or, when the key is absent, detected from `package.json` scripts, `Makefile` targets, Gradle or Maven builds, `go.mod`, `Cargo.toml`, or `pyproject.toml`. When a Gradle (`build.gradle*`, `settings.gradle*`) or Maven (`pom.xml`) build exists, it is the primary build: it supplies `test` and `build` (Gradle: `./gradlew test` and `./gradlew build`; Maven: `./mvnw -B test` and `./mvnw -B verify`; `gradle` or `mvn` without a wrapper) ahead of `package.json` and the `Makefile`, which still supply `format`, `lint`, and `types`. The command's exit code is the verdict. **Do not pick, substitute, or chain commands yourself, and do not re-judge a result**: a check the script reports `failed` has failed, even if the output looks harmless.

The script is also on the Bash `PATH` as `ccm-validate` while the plugin is enabled; use the bare name if the `${CLAUDE_PLUGIN_ROOT}` path doesn't resolve.

## Implementation Steps

### 1. List the checks

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-validate" --list
```

It prints `{status, timeout_seconds, checks: [{name, command, source, status, reason?}]}` without running anything. `status: planned` checks will run; `skipped` checks carry a `reason` ("not configured" or "disabled in config"). Show the plan to the user as a short table. If the top-level `status` is `nothing-to-run` (exit 2), skip to the report: there is nothing to run, and the user can add `validate_*` keys to `.claude/ccmagic.local.md`.

### 1b. Install missing Node dependencies

Skip this step when `--list`'s `timeout_seconds` is above 540: the background run of step 2L installs the dependencies itself before its first check, under the same limit, and reports `environment` the same way.

If the `--list` output has an `install` object, the repository's `package.json` declares dependencies, one of them is not installed in `node_modules`, and a planned check runs through Node (`npm`, `npx`, `pnpm`, `yarn`, `bun`, `bunx`, or `node`, or a `package.json` script), so the checks would fail for a reason that is not the code. Install them first, as its own call with the maximum Bash tool timeout (600000 ms):

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-validate" --install
```

It runs the install the lockfile calls for (`npm ci` for `package-lock.json` or `npm-shrinkwrap.json`; `pnpm`, `yarn`, or `bun` for their lockfiles, only when that tool is installed) under `validate_timeout_seconds` and prints `{status: installed | not-needed | environment, install}`. `installed` or `not-needed`: go on to step 2. `environment` (exit 5): the install failed, timed out, or could not be done (no lockfile, or the lockfile's tool is missing); `install.reason` says which, and `install.tail` shows the end of the install's output. Run no check: report the environment problem, since every check would fail for the same reason. This is Node only; other ecosystems are never installed, and a project whose checks are all Gradle, Maven, or other non-Node commands has no `install` object. A step 2 call that finds the dependencies still missing installs them itself and reports `environment` the same way.

### 2. Run each planned check, one call per check

Use this step when `--list`'s `timeout_seconds` is 540 or less (the default). Above 540, a check can outlast the Bash tool's 10-minute limit; use step 2L instead.

For each check with `status: planned`, in the listed order:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-validate" --only <check>
```

Give each call the maximum Bash tool timeout (600000 ms). One call per check keeps each under the tool's 10-minute limit; the script enforces its own `validate_timeout_seconds` limit (default 540, which leaves room to report before the tool's limit) and reports a check that hits it as `failed` with reason "timed out". If the output has a `note`, no `timeout` binary was found and the checks ran unbounded; repeat the note in the report. If the Bash call itself times out and prints no JSON, count that check as failed with reason "timed out".

Each call prints `{status: pass | fail | environment, install?, checks: [{name, command, source, status, exit_code, duration_s, log, reason?, tail?}]}` and exits 0 on pass, 1 on fail, and 5 on `environment` (missing dependencies it could not install, so no check ran; stop and report it as step 1b says). A failed check carries the last 40 lines of its output as `tail`; the full output is in the `log` file. Keep going after a failure so the report covers every check, unless the user asked to stop at the first failure.

### 2L. Long checks: one background run (`timeout_seconds` above 540)

Start every planned check in one run that outlives the Bash call. Make this one Bash call with `run_in_background: true`, so the harness owns the run as a background task:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-validate" --start --attached
```

If the path form is not found or is denied, make the same background call with the bare name `ccm-validate` in place of the path. With `--attached` the run happens in the foreground of that call, which the harness keeps running in the background: a sandboxed Bash tool (Cyrus) ends every process a call started when the call returns, so a run detached from an ordinary call dies with it, while a background task survives. The call prints nothing until the run ends, so do not read its output to follow the run; the state file is the interface. Do not wait for its completion notification either: go straight on to `--wait`.

If the harness has no background option (the call is denied, or `run_in_background` is not a parameter of its Bash tool), start the run detached instead, as an ordinary call:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-validate" --start
```

It prints `{status: "started", run, pid, timeout_seconds, limit_s, checks}` (exit 0) and returns at once. Say in the report that the run was detached, because a detached run does not survive in a sandbox that ends a call's processes; there the first `--wait` reports it failed with a `reason` about its heartbeat.

Either way, wait for the run with ordinary Bash calls (not in the background), each on its own with the maximum Bash tool timeout (600000 ms):

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-validate" --wait
```

Each call waits up to 480 seconds. Exit 6 with `{status: "running", elapsed_s, heartbeat_age_s, limit_s, done, running, pending}` means the run is still going: say which check is running, then call `--wait` again. Repeat until a call exits with another code; that call prints the plain run's JSON for every planned check (step 2's format, with `status` `pass`, `fail`, or `environment` and exit 0, 1, or 5), which is the result. A later `--wait` prints the same result again. Do not end your turn while the background run is going: keep calling `--wait` until it prints a result, since a turn that ends early returns without one.

The loop has a limit: `limit_s` is the sum of the planned checks' limits (one more for an install) plus 120 seconds, and a `--wait` past it records the run as failed and returns `fail` with a top-level `reason`, the running check `failed` and the rest `skipped`. A run that stopped writing its heartbeat (none for more than 90 seconds, or none 30 seconds after its start) died without a result and is reported the same way. Stop calling `--wait` only on a result; if a `running` answer ever shows `elapsed_s` above `limit_s`, stop and count the running and pending checks as failed with reason "timed out". If one `--wait` Bash call itself times out and prints nothing, call `--wait` again.

Other `--start` answers: `nothing-to-run` (exit 2) is step 1's case. `running` (exit 6) with a `note` means an earlier call in this checkout left a run going, which may have checked older code: `--wait` until it ends, discard that result, and start again. Exit 1 with a `fail` result means the run could not start; report it as failed. The background call's own completion notification, when it arrives, carries the same final JSON as `--wait`; `--wait` is the one to judge.

### 3. Optional checks (interactive only)

These are outside the script and never change the verdict. Offer them in interactive mode when relevant; skip them in autonomous mode:

- **Coverage:** if the user asks for a threshold, run the test command with its coverage flag and compare.
- **Security scan:** the one dependency audit or secret scanner the project actually uses (`npm audit`, `pip-audit`, `gitleaks detect`, `semgrep`). Run one tool; never chain tools with `||`.
- **Documentation:** `git diff --name-only <base>...HEAD` to see whether public behavior changed without a docs or CHANGELOG update.

## Validation Report Format

Fill the report from the JSON of the step 2 calls (or the step 2L result): one section per check in the listed order, with the command, `duration_s`, and for a failed check the relevant lines of `tail` (read `log` for more when the tail doesn't show the cause). Skipped checks get one line with their `reason`. Optional checks from step 3 go in their own sections, marked as not affecting the result.

```markdown
# Validation Report
Timestamp: [ISO 8601 timestamp]

## Summary
✅ **PASSED** - All validation checks successful
-- OR --
❌ **FAILED** - 3 checks failed, must fix before commit

## Check Results

### ✅ Format (`npm run format:check`, 3s)
- Passed

### ❌ Lint (`npm run lint`, 12s, exit 1)
- `src/auth/login.ts:45` - Missing return type
- `src/utils/helpers.ts:12` - Unused variable 'temp'

### ⏭️ Types
- Skipped: not configured

### ✅ Tests (`npm run test`, 41s)
- 145/145 passing

### ✅ Build (`npm run build`, 45s)
- Passed

### Optional: Security Scan (does not affect the result)
- No vulnerabilities found

## Required Actions
1. Fix linting warnings in 3 files
2. Update README with new endpoints
3. Add entry to CHANGELOG.md

## Recommendations
- Consider adding tests for uncovered lines
- Update deprecated dependencies (3 available)
- Add JSDoc comments to public APIs
```

## Smart Features

### 1. Auto-fix Mode (interactive only)
Offer to fix simple failures, then rerun that check with `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-validate" --only <check>` to confirm:
```bash
# Auto-fix linting
eslint --fix

# Auto-format code
prettier --write .

# Auto-fix imports
npx organize-imports-cli
```

### 2. Git Hooks Integration
Set up pre-commit hooks:
```bash
# Install husky
npx husky install

# Add pre-commit hook
npx husky add .husky/pre-commit "npm run validate"
```

## Configuration

Commands and the time limit come from flat keys in the `ccmagic.local.md` frontmatter (project file over user file):

```yaml
---
validate_lint: npm run lint:strict   # overrides detection
validate_types: none                 # disables the check
validate_timeout_seconds: 1800       # per check; default 540, at most 7200
---
```

A `validate_timeout_seconds` above 540 runs the checks as step 2L describes, since one Bash call cannot wait longer than 10 minutes.

Keys: `validate_format`, `validate_lint`, `validate_types`, `validate_test`, `validate_build`, `validate_timeout_seconds`. See `docs/ccmagic.local.md.example`.

## Integration with Other Commands

- Automatically run before `/ccmagic:pr`
- Include in `/ccmagic:merge` workflow
- Use with git pre-commit hooks

## Failure Handling

When validation fails:
1. Clearly identify what failed
2. Provide specific fix instructions
3. Offer auto-fix for simple issues
4. Create todos for complex fixes
5. Prevent commit/PR until fixed

## Autonomous mode

`/ccmagic:validate` runs interactively by default. Autonomous mode is **opt-in and additive**: it runs the same checks without prompting and ends with a machine-readable handshake the orchestrator (`/ccmagic:auto-ticket`) parses. It never fixes code on its own — fixing is the caller's job.

### When autonomous mode is active

Autonomous mode is ON when the first present signal (in priority order) resolves truthy:

1. `--autonomous` in the skill arguments.
2. An `autonomous: true` line in the grounding/context block a parent skill (e.g. `/ccmagic:auto-ticket`) prepends when invoking this skill.
3. `autonomous: true` in `ccmagic.local.md` frontmatter — the project file `.claude/ccmagic.local.md` first, then the user file `~/.claude/ccmagic.local.md`.

Absent all three, run the interactive path exactly as documented above.

`/ccmagic:validate` has no tracker access; it never moves a ticket. It runs steps 1 and 2, or 2L (not the optional checks), reports the result, and emits the handshake. The parent skill or orchestrator owns any route-and-stop. Auto-fix is **off** in autonomous mode: report failures, don't rewrite code.

The handshake follows the script's JSON, with no judgment of your own:

- Every step 2 call returned `status: pass` (or the step 2L result did): emit `done` with reason `validation passed`. A step 2L `running` answer (exit 6) is not a result: keep calling `--wait`.
- `--list` returned `nothing-to-run`: emit `done` with reason `no checks configured`.
- `--install`, a step 2 call, or the step 2L result returned `status: environment`: emit `needs-human` with a reason starting `environment:` and quoting `install.reason` (for example `environment: npm ci exited 1`), and no `failures:` section. An environment problem is not a check failure: the orchestrator parks it without a fix pass. Only the script's `environment` status is one; a check the script reports `failed` stays `failed:` however environmental its output looks.
- Any step 2 call returned `status: fail`, or the step 2L result did: emit `needs-human` with a reason listing the failed check names from the JSON (for example `failed: lint, test`; add "(timed out)" after a check whose `reason` says so). Just before the handshake, emit a `failures:` section (contract §3) with one entry per failed check: its `command`, `exit_code`, `log` path, and the lines of its `tail` that show the cause, copied from the JSON (a check a stopped step 2L run left failed has no exit code or `tail`; give its `reason`, and the end of its `log` when there is one). The orchestrator decides whether to fix-and-retry or park, and hands that section to the fix pass.

### Handshake (emit last, in autonomous mode)

```
status: done | needs-human
reason: <one line: "validation passed" or "no checks configured" on done; "failed: <check names>" or "environment: <install.reason>" on needs-human>
follow_ups: []
```

## Execution

Begin validation immediately without confirmation. Run the checks in the order `--list` gives, report each result as it arrives, and display clear, actionable results with specific file:line references taken from the failed checks' output.
