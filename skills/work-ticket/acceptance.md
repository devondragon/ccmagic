# Acceptance tests written before the build

Reeve (RV-134) can have a ticket's acceptance tests written by another session, from the ticket's criteria, before the build starts. A tests ticket adds black-box tests under `<path>/<TICKET>/` and an empty marker file `<pending>/<TICKET>`, a person approves them, and they merge to the base marked as expected to fail. The ticket's build then deletes the marker, so the tests run normally and must pass, unchanged. Reeve's gate refuses a build PR that changes the tests or keeps the marker, and a tests PR that changes anything else.

`work-ticket` reads this file in two cases: the ticket is a tests ticket (*Tests ticket* below), or the `find` mode of `ccm-acceptance` reports tests for the ticket being built (*Build with acceptance tests* below). In both, `{base-ref}` is `origin/{base-branch}` after `git fetch origin {base-branch}` (its own Bash call); with no `origin` remote it is `{base-branch}`. Run each `ccm-acceptance` call as its own Bash call, at the repository root, by the `${CLAUDE_PLUGIN_ROOT}/bin/` path shown (the bare name `ccm-acceptance` only when the path form is not found or is denied).

A stop below is a `needs-human` with the reason given, in autonomous mode; when running interactively, tell the user the reason and ask how to proceed instead.

## Tests ticket

A tests ticket is one whose description carries a `reeve:acceptance` block. Reeve writes the block as the ticket's whole description, titled `Acceptance tests: <PARENT>` (or `..., revision <n>`, or `Remove acceptance tests: <PARENT>`). It holds:

- under its own "Acceptance criteria" heading, what this ticket delivers: the files, a test per criterion, and nothing else;
- under "Criteria to test", the parent ticket's identifier and each of its criteria as `AC-<n>: <text>`;
- the directory the tests go in (`<path>/<PARENT>/`), the marker to add (`<pending>/<PARENT>`), and the rules below.

Follow the block's own rules where they are more specific than these. A revision ticket changes tests under the directory, which already exists, and keeps the marker; a remove ticket deletes the directory and the marker. For those two, the block's rules take the place of items 2 and 5.

1. **"Criteria to test" is input, not scope.** It describes behavior the parent's build will add. Do not implement any of it. Step 6 compares the work with the block's own "Acceptance criteria", never with the criteria to test, and an unbuilt criterion to test is not a gap.
2. **Write only under `<path>/<PARENT>/`, plus the marker `<pending>/<PARENT>`**, an empty file. Change nothing else: no app code, no fixture or contract the app serves, no config, no package or lock file, no helper outside the directory. When the tests need a change outside it (a missing helper, a dependency, a fixture state), stop: `reason: the acceptance tests for <PARENT> need {the change} outside <path>/<PARENT>/`.
3. **Black-box tests only,** through HTTP, the CLI, or the browser, using the repository's acceptance helper (its `CLAUDE.md` describes it). Test data the app does not already serve lives under the ticket's directory.
4. **Every test title starts with the `AC-<n>` it checks** (`AC-3: lists each tripped repo`; a helper such as `acceptance("RD-41", "AC-3", "lists each tripped repo", ...)` writes the prefix). Every criterion gets at least one test, or one line in the PR body saying why it cannot be tested from outside. Each test asserts only what its criterion states. A criterion the code already meets (a regression criterion) uses the helper's `holds: true` flag, and the PR body lists each such test.
5. **Check the branch** before committing:

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/bin/ccm-acceptance" tests --worktree --ids {the criteria ids, comma-separated, such as AC-1,AC-3} {path}/{PARENT} {pending}/{PARENT} {base-ref}
   ```

   Exit 0: each id in `uncited` needs a test or its PR-body line. Exit 1: a rule failed (`exists`, `scope`, `marker-missing`, `tests-missing`); fix what it names when the fix stays within these rules, and run it again; otherwise stop: `reason: acceptance tests check failed ({rule}): {detail}`. Any other exit: stop: `reason: cannot run the acceptance tests check: {detail}`.
6. **Run the new tests with the marker in place,** the way the repository runs them, when this environment can. Every test that is not `holds: true` must fail against the current code, which the expected-to-fail marking turns into a pass. A test that passes checks nothing the build adds: rewrite it, or mark it `holds: true` and list it.
7. **The PR body** gets an `## Acceptance tests` section: one line per criterion id with its test titles, the line for each criterion without a test, and the `holds: true` tests.

A fix pass on a tests ticket follows the same rules and runs the check in item 5 again before it reports `done`.

## Build with acceptance tests

On every ticket that is not a tests ticket, before Step 5's paths, run:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-acceptance" find {TICKET-ID} {base-ref}
```

It looks for `<path>/{TICKET-ID}/` at the base, from `acceptance_path` and `acceptance_pending` in `.claude/ccmagic.local.md` when set, otherwise by finding one directory and one marker file named for the ticket. When `applies` is `false`, nothing in this section applies. Exit 1 (`ambiguous`): stop: `reason: cannot tell which files are this ticket's acceptance tests: {detail}`. Exit 3 or 4: stop: `reason: cannot run the acceptance tests check: {detail}`.

When `applies` is `true`, the files in `tests` (under `dir`) were written from this ticket's criteria by another session and approved by a person before this build. They are part of the ticket's acceptance criteria:

1. **The tests are read-only.** Never edit, rename, delete, skip, or loosen them, and change nothing else under the tests' directory or the marker's directory, other tickets' tests and markers included.
2. **Delete the marker** `marker` when `marker_present` is `true` (`git rm {marker}`), in the same PR as the build.
3. **Build the ticket, then run the acceptance tests** with the marker deleted, the way the repository runs them (its `CLAUDE.md`, or the CI job that runs the directory). They must pass.
4. **A test that cannot pass without changing it is a stop,** whatever the reason: it contradicts the ticket, it needs UI or data the ticket does not describe, or it fails for a cause outside the code. Stop with `reason: acceptance test "{test title}" in {file} cannot pass without changing it: {why}`. Never change a test to fit the code.
5. **When this environment cannot run the tests** (no browser or runner), say so in the PR body; CI runs them, and the merge gate waits on that check.
6. **Check the branch** before committing:

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/bin/ccm-acceptance" build --worktree {TICKET-ID} {base-ref}
   ```

   Exit 0: continue. Exit 1 `still-pending`: delete the marker and run it again. Exit 1 `tests-changed`: restore the file it names as the base has it (`git checkout {base-ref} -- {file}`, or remove a file you added) and run it again. Any other exit: stop: `reason: cannot run the acceptance tests check: {detail}`.
7. **The PR body** gets an `## Acceptance tests` section: the marker deleted, and the tests run with their result, or why they could not run here.

A fix pass on such a build follows the same rules and runs the check in item 6 again before it reports `done`. A finding that asks for a change to an acceptance test is a stop naming the test.
