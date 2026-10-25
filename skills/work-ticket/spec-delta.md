# Spec delta rules for a plain ticket

`work-ticket` reads this file only when the base has `openspec/specs/` and the grounding block has no `spec:` section: a plain ticket in a repository with OpenSpec specs (RV-100). Nothing here applies to any other ticket.

`{base-ref}` is `origin/{base-branch}` after `git fetch origin {base-branch}` (its own Bash call); with no `origin` remote it is `{base-branch}`. Run each command below as its own Bash call, at the repository root, by the `${CLAUDE_PLUGIN_ROOT}/bin/` path shown (the bare name, such as `ccm-spec-delta`, only when the path form is not found or is denied).

## Approval check

Runs at the start of Step 5, only when the ticket description contains `openspec archive` (it may be the archive ticket of a Reeve requirements approval, RV-136), and not on a fix pass. Run `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-spec-delta" applies {base-ref}`. When its `applies` is `true`, pass the description, as fetched or as `ticket_content:` holds it, to the detector on stdin, as its own Bash call:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-spec-delta" approval {base-ref} <<'CCM_TICKET_EOF'
{the description, verbatim}
CCM_TICKET_EOF
```

Write the description's lines and the closing `CCM_TICKET_EOF` line at the start of the line, without the indentation shown here. When its `approval` is `false`, the ticket is a plain ticket: continue with Step 5's paths and *Spec delta* below as usual. When it is `true`, the ticket is the approval's archive ticket for `change`, and Reeve's gate judges its PR by the archive rules, not the plain-delta rules. Run the *Approval archive procedure* in place of Step 5's paths, *Spec delta*, and Step 6.

## Approval archive procedure

First run `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-spec-delta" record HEAD {base-ref}`. When its `spec_delta` names a folder, an earlier run already archived the change on this branch (a run that resumes the branch after a park): skip steps 1 to 3 and run step 4.

1. Run `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-openspec-version"` and read its JSON. On `ok`, continue. On `newer`, continue and print one warning line: `OpenSpec {version} is newer than {tested}; the format rules were checked against {tested}.` On anything else, stop: `reason: openspec {version, or "missing or unreadable"}; the archive needs {tested} or a newer 1.x release`.
2. Run `openspec archive {change} --yes`, with no other flag. It warns that the tasks are incomplete; that is expected.
3. Run `openspec validate --all --strict --no-interactive`. A failure stops with the validator's first lines, joined into one line, as the reason. Never edit a file to make validation pass.
4. Run `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-openspec-scope" --worktree --approval {change} archive {base-ref}`. Unless it exits 0, stop: `reason: approval archive check failed ({rule}): {detail}` (or `cannot run the approval archive check: {detail}` when it printed no `rule`). Exit 0: keep its `folder` (`openspec/changes/archive/<date>-{change}`) as the run's `spec_delta`.
5. Continue with Step 7. The PR carries only the result of the archive: change no code, test, or doc, and leave every task in the archived `tasks.md` unchecked, as the approval wrote it (a ticked box fails the gate's `folder-content`). The ticket's own acceptance criteria are what the archive does, so Step 6's scope comparison is the check in step 4. The handshake carries `spec_delta: {folder}` and no `tasks_done:` line.

A stop in any of steps 1 to 4 restores `openspec/` with two separate Bash calls, `git checkout -- openspec` and then `git clean -fd -- openspec`, opens no PR, and returns `needs-human` with the reason, with no `spec_delta:` line; when running interactively, tell the user instead.

## Spec delta

Runs after the implementation and before Step 6, and not on a fix pass (*Fix pass* below says what a fix pass does). A plain ticket that changes specified behavior carries its own spec delta, archived in the same PR as the code, so the reviewer reads both together and the specs never lag behind the default branch. Work that needs more than one PR is a planned OpenSpec change, not a plain ticket. A requirements approval's archive ticket (the *Approval check* returned `approval: true`) skips this section: its *Approval archive procedure* runs instead.

First run `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-spec-delta" applies {base-ref}`. When its `applies` is `false`, the base has no `openspec/specs/<cap>/spec.md`: skip the rest of this section, and the handshake carries no `spec_delta:` line.

**A branch that already carries the archive.** A run can resume a branch an earlier run worked on (a redispatch after a park, or a retry). Run `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-spec-delta" record HEAD {base-ref}`. When its `spec_delta` names a folder, the branch already adds this ticket's archive, whichever run archived it: do not write or archive a delta again. Run step 9 below, and keep its `spec_delta`, that folder, for the PR body, the handshake, and the run record. When the code you changed in this run changes specified behavior the archived delta does not cover, or step 9 fails, correct the delta as *Fix pass* below does for a delta that does not match the code.

**Decide whether specified behavior changed,** after the implementation and before Step 6:

1. Take the capabilities from the `applies` output. For each file the diff changes, search `openspec/specs/` (Grep) for the behavior it touches: routes, response fields, UI text and states, config keys, limits, error messages, and the ticket's own terms. Read each requirement and scenario you find.
2. It changed when a `SHALL` sentence, or a scenario's `WHEN` and `THEN`, held for the base code and is false for the new code, or when the change adds behavior that a user, an API client, an operator, or another system can observe, inside a capability's `## Purpose`, that no requirement states.
3. It did not change for a refactor, tests, docs, dependencies, the build, internal structure, performance with no stated bound, logs no requirement names, or a fix that makes the code do what a requirement already says (the spec was right, and a delta would restate it).
4. When the spec and the base code disagreed and the ticket keeps the code's behavior, write a delta: the spec was the wrong one.
5. Behavior that no capability covers gets no delta. Name it in the PR body ("no capability covers {area}") and add a follow-up to write a baseline spec for that area. A plain ticket never creates a capability and never retires one.

**When nothing changed,** run no `openspec` command. The run's `spec_delta` is `none`, and the PR body says why (Step 7).

**When it changed,** write and archive the delta:

1. Run `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-openspec-version"` and read its JSON. On `ok`, continue. On `newer`, continue and print one warning line: `OpenSpec {version} is newer than {tested}; the format rules were checked against {tested}.` On anything else, stop: `reason: openspec {version, or "missing or unreadable"}; a spec delta needs {tested} or a newer 1.x release`.
2. Run `openspec validate --all --strict --no-interactive` on the unchanged `openspec/`. A failure stops: the base already fails, so CI fails on every PR, and the fix is outside the ticket.
3. Run `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-spec-delta" name {TICKET-ID} '{title}' {base-ref}`, with the ticket title in single quotes and any `'` in it replaced by a space, and use its `name` from here on. Exit 1 (the ticket key alone breaks Reeve's change-name rule) stops with its `detail`.
4. Write `openspec/changes/{name}/`:
   - `proposal.md`: `# Proposal`, then `## Why` (the ticket identifier and one to three sentences on what changed and why), then `## What Changes` (one bullet per requirement, `- {cap}: MODIFIED "{requirement}"`).
   - `specs/{cap}/spec.md` for each capability whose behavior changed, with any of these sections. `## MODIFIED Requirements`: copy the requirement's whole current block from `openspec/specs/{cap}/spec.md` under its exact `### Requirement:` name, then edit it, since the archive replaces the whole block and drops any scenario you leave out. `## ADDED Requirements`: each with at least one `#### Scenario:` that has a `WHEN` and a `THEN` line. `## REMOVED Requirements`: each with a `**Reason**` and a `**Migration**` line. `## RENAMED Requirements`: `- FROM: ` and `- TO: ` lines, each holding a `### Requirement:` heading in backticks.
   - Nothing else: no `tasks.md`, no `.openspec.yaml`, no `design.md`. US English, no em or en dash, no email address or other personal identifier.
5. Run `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-spec-delta" collision {name} {base-ref}`. Exit 1 means an active change at the base also names one of your requirements for the same capability, and archiving it later would overwrite this fix or fail. Stop with `reason: the spec delta changes requirement {requirement} of {capability}, which active change {change} also changes; a person decides whether to wait for that change or fold this fix into it`.
6. Run `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-spec-delta" check --worktree {name} {base-ref}`. Exit 1: its `findings` name what to correct. A `capability-new` finding means behavior no capability covers: remove that capability's delta and handle it as in item 5 of the decision above.
7. Run `openspec archive {name} --yes`, with no other flag.
8. Run `openspec validate --all --strict --no-interactive`.
9. Run `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-spec-delta" scope --worktree {TICKET-ID} {base-ref}`. Exit 0: keep its `spec_delta` (the archive folder's path) for the PR body, the handshake, and the run record.

The base passed step 2, so a failure in steps 6 to 9 (exit 1 from a script, or a nonzero exit from `openspec`) is the delta's own. Correct it in the session: restore `openspec/` with two separate Bash calls, `git checkout -- openspec` and then `git clean -fd -- openspec`, rewrite the delta, and repeat from step 4. Make at most two corrections, then stop. On a fix pass, where the archive is already committed, the restore brings the committed archive back, so run `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-spec-delta" reopen {base-ref}` again after it and before rewriting. Any other stop (steps 1 to 3 and 5, a third failure, or exit 3 or 4 from a script: it could not read or run, or was called wrongly) restores `openspec/` the same way, opens no PR, and returns `needs-human` with the reason; when running interactively, tell the user instead. The archive folder carries the local date, as `openspec archive` writes it.

## Fix pass

A fix pass changes nothing under `openspec/` unless a listed item concerns the spec delta:

- An item saying the delta does not match the code, or that the main spec does not match the delta: run `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-spec-delta" reopen {base-ref}`. It moves the archived folder back to `openspec/changes/{name}/` and restores each capability's `spec.md` from the merge base. Edit the delta, then run steps 6 to 9 of *Spec delta*, with the same correction limit.
- An item saying a delta is missing: run the whole *Spec delta* procedure, from the version check.
- An item naming another `scope` rule (`delta-active`, `delta-folders`, and the like): run `reopen` as in the first bullet and then steps 6 to 9. When `reopen` exits 1 (the branch does not add exactly one archive folder), stop with `needs-human` naming the rule: the branch's OpenSpec files need a person.

Either way the handshake carries `spec_delta:` with the new value. On a requirements approval's archive ticket (the *Approval check* returned `approval: true`; run it again as there, since a fix pass skips Step 5) none of these bullets apply: the fix pass changes nothing under `openspec/` and no file outside it, since the PR carries only the archive, and before it reports `done` it runs `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-openspec-scope" --worktree --approval {change} archive {base-ref}`; a failure, or an item that needs any change, is a `needs-human` naming it. Every other fix pass leaves `openspec/` alone and emits no `spec_delta:` line, and the finish step's scope check holds the branch to that.
