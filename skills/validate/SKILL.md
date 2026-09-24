---
name: validate
user-invocable: true
allowed-tools: Read(*), Bash(*), Bash(${CLAUDE_SKILL_DIR}/../../bin/ccm-validate *), Glob(*), Task(*), TodoWrite(*)
description: Pre-commit validation that runs the project's format, lint, type, test, and build checks and reports pass or fail
model: sonnet
context: fork
---

# Validate Command

Comprehensive pre-commit validation to ensure code quality, tests pass, and changes are ready for PR.

## What decides pass or fail

`ccm-validate` resolves and runs the checks: `format`, `lint`, `types`, `test`, `build`, in that order. Each check has at most one command, from the config key `validate_<check>` in `ccmagic.local.md` (`none` disables it) or, when the key is absent, detected from `package.json` scripts, `Makefile` targets, Gradle or Maven builds, `go.mod`, `Cargo.toml`, or `pyproject.toml`. When a Gradle (`build.gradle*`, `settings.gradle*`) or Maven (`pom.xml`) build exists, it is the primary build: it supplies `test` and `build` (Gradle: `./gradlew test` and `./gradlew build`; Maven: `./mvnw -B test` and `./mvnw -B verify`; `gradle` or `mvn` without a wrapper) ahead of `package.json` and the `Makefile`, which still supply `format`, `lint`, and `types`. The command's exit code is the verdict. **Do not pick, substitute, or chain commands yourself, and do not re-judge a result**: a check the script reports `failed` has failed, even if the output looks harmless.

The script is also on the Bash `PATH` as `ccm-validate` while the plugin is enabled; use the bare name if the `${CLAUDE_SKILL_DIR}` path doesn't resolve.

## Implementation Steps

### 1. List the checks

```bash
"${CLAUDE_SKILL_DIR}/../../bin/ccm-validate" --list
```

It prints `{status, timeout_seconds, checks: [{name, command, source, status, reason?}]}` without running anything. `status: planned` checks will run; `skipped` checks carry a `reason` ("not configured" or "disabled in config"). Show the plan to the user as a short table. If the top-level `status` is `nothing-to-run` (exit 2), skip to the report: there is nothing to run, and the user can add `validate_*` keys to `.claude/ccmagic.local.md`.

### 2. Run each planned check, one call per check

For each check with `status: planned`, in the listed order:

```bash
"${CLAUDE_SKILL_DIR}/../../bin/ccm-validate" --only <check>
```

Give each call the maximum Bash tool timeout (600000 ms). One call per check keeps each under the tool's 10-minute limit; the script enforces its own `validate_timeout_seconds` limit (default 540, which leaves room to report before the tool's limit) and reports a check that hits it as `failed` with reason "timed out". If the output has a `note`, no `timeout` binary was found and the checks ran unbounded; repeat the note in the report. If the Bash call itself times out and prints no JSON, count that check as failed with reason "timed out".

Each call prints `{status: pass | fail, checks: [{name, command, source, status, exit_code, duration_s, log, reason?, tail?}]}` and exits 0 on pass, 1 on fail. A failed check carries the last 40 lines of its output as `tail`; the full output is in the `log` file. Keep going after a failure so the report covers every check, unless the user asked to stop at the first failure.

### 3. Optional checks (interactive only)

These are outside the script and never change the verdict. Offer them in interactive mode when relevant; skip them in autonomous mode:

- **Coverage:** if the user asks for a threshold, run the test command with its coverage flag and compare.
- **Security scan:** the one dependency audit or secret scanner the project actually uses (`npm audit`, `pip-audit`, `gitleaks detect`, `semgrep`). Run one tool; never chain tools with `||`.
- **Documentation:** `git diff --name-only <base>...HEAD` to see whether public behavior changed without a docs or CHANGELOG update.

## Validation Report Format

Fill the report from the JSON of the step 2 calls: one section per check in the listed order, with the command, `duration_s`, and for a failed check the relevant lines of `tail` (read `log` for more when the tail doesn't show the cause). Skipped checks get one line with their `reason`. Optional checks from step 3 go in their own sections, marked as not affecting the result.

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
Offer to fix simple failures, then rerun that check with `ccm-validate --only <check>` to confirm:
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
validate_timeout_seconds: 900        # per check; default 540
---
```

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

`/ccmagic:validate` has no tracker access; it never moves a ticket. It runs steps 1 and 2 (not the optional checks), reports the result, and emits the handshake. The parent skill or orchestrator owns any route-and-stop. Auto-fix is **off** in autonomous mode: report failures, don't rewrite code.

The handshake follows the script's JSON, with no judgment of your own:

- Every step 2 call returned `status: pass`: emit `done` with reason `validation passed`.
- `--list` returned `nothing-to-run`: emit `done` with reason `no checks configured`.
- Any step 2 call returned `status: fail`: emit `needs-human` with a reason listing the failed check names from the JSON (for example `failed: lint, test`; add "(timed out)" after a check whose `reason` says so). The orchestrator decides whether to fix-and-retry or park.

### Handshake (emit last, in autonomous mode)

```
status: done | needs-human
reason: <one line: "validation passed" or "no checks configured" on done; the failed check names on needs-human>
follow_ups: []
```

## Execution

Begin validation immediately without confirmation. Run the checks in the order `--list` gives, report each result as it arrives, and display clear, actionable results with specific file:line references taken from the failed checks' output.
