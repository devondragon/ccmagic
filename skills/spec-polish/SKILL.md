---
name: spec-polish
user-invocable: true
allowed-tools: Read(*), Glob(*), Grep(*), Agent(Explore), Task(Explore), AskUserQuestion(*), Write(openspec/changes/**), Edit(openspec/changes/**), Bash(openspec:*), Bash(${CLAUDE_PLUGIN_ROOT}/bin/ccm-openspec-version *), Bash(ccm-openspec-version *), Bash(${CLAUDE_PLUGIN_ROOT}/bin/ccm-propose-check *), Bash(ccm-propose-check *), Bash(${CLAUDE_PLUGIN_ROOT}/bin/ccm-spec-polish *), Bash(ccm-spec-polish *), Bash(${CLAUDE_PLUGIN_ROOT}/bin/ccm-context *), Bash(ccm-context *), Bash(git status:*, git diff:*, git log:*, git show:*, git rev-parse:*, git ls-files:*, git fetch:*, git branch --show-current:*, git checkout -b:*, git add openspec/changes/:*, git commit:*, git push origin HEAD:*), Bash(reeve openspec render:*)
description: Review an OpenSpec change in rounds before Reeve plans it, each round in a fresh context against the repository, with you accepting or rejecting each finding, until two rounds in a row raise nothing you accept; then write the polish record (.reeve.yml) that Reeve reads at planning. Use on a change's proposal branch, before its PR merges.
argument-hint: "<change> [--max-rounds N]"
---

# Spec Polish

Reeve plans an OpenSpec change into tickets as soon as it reaches the default branch, and after that its sections are append-only. Intake grades each section ticket on its own, so it cannot see problems that span the change: tasks that miss a delta requirement, sections in an order that cannot build, a Why that does not match What Changes, a MODIFIED block that drops a scenario. This skill finds those before the merge. It runs review rounds over the whole change, each in a fresh context, and you decide every finding. It stops when two rounds in a row raise nothing you accept, and it writes a record of the loop to `openspec/changes/<change>/.reeve.yml`. Reeve carries that record on `spec-planned`, splits `reeve stats` by it, and with `openspec.require_polish` on plans only a change whose record matches its files.

The review prompt is `${CLAUDE_SKILL_DIR}/review-prompt.md`. Read it before Step 2.

This skill is standalone and interactive. No ticket workflow (`auto-ticket`, `work-ticket`, `finish-ticket`, or any `auto-*` agent) runs it.

## What this skill may write

Only files under `openspec/changes/<change>/`, plus one commit, and a push of the current branch when it already tracks a remote. Never another change, `openspec/specs/**`, code, tests, CI, or configuration. The `Write` and `Edit` grants are restricted to `openspec/changes/**`, and `ccm-propose-check` reports any other changed path as `outside-change`. Never tick a task box. Never merge, never push with `--force`, and never commit on the default branch.

Never copy a secret, a credential, a personal email address, a phone number, or an account identifier into the change.

## Step 0: Parse arguments

`<change>` is required: the folder name under `openspec/changes/`. `--max-rounds N` caps the rounds (default 6, at least 2). Anything else is a usage error: say what the arguments are and stop. Run the scripts by `${CLAUDE_PLUGIN_ROOT}/bin/<name>`, and fall back to the bare name only when the path form is not found or is denied.

## Step 1: Preflight

Run each as its own Bash call, at the repository root, and stop with a plain message when one fails:

1. `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-context"`: keep `base_branch` and `branch`. Stop when it fails (not a git repository).
2. `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-openspec-version"`: on `ok` continue; on `newer` continue with the one-line warning `OpenSpec {version} is newer than {tested}; the format rules here were checked against {tested}.`; on `too-old`, `unsupported`, or `missing`, stop and name the install command `npm i -g @fission-ai/openspec@{tested}`.
3. `git fetch origin {base_branch}` (skip it when there is no `origin` remote), then `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-spec-polish" preflight <change>`. Exit 1 lists findings; stop and name them. A `planned` finding means the change is already on the default branch: Reeve has planned it (or recorded it as a baseline), so an edit now is drift for `reeve replan`, not polish.
4. `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-propose-check" --probe-reeve`: keep `cli`, `repo`, and `grade`. The loop needs `reeve openspec render --grade`, so stop when `grade` is false, naming what `missing` lists and how to set the CLI up (put `reeve` on PATH, or set `REEVE_CLI` to a command such as `npx tsx /path/to/reeve/src/cli.ts`, with Reeve's config by `REEVE_CONFIG` and `LINEAR_API_KEY` and `ANTHROPIC_API_KEY` set). Use `{cli}` in place of `reeve` below when it is a `REEVE_CLI` command (the user approves those calls, which the grant does not cover).
5. `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-propose-check" <change>`: any `outside-change` finding stops the skill (commit or stash the other work first). Other findings are kept for round 1, which must fix them.

Then run the checks of Step 3 once on the unchanged change, as the baseline, and keep the rubric hash from the render's `summary:` line (`rubric <hash>`). A check that fails now is a finding round 1 must close.

## Step 2: One round

A round has a number `n`, starting at 1.

1. Dispatch one read-only reviewer, `subagent_type: Explore`, `model: "opus"`, with the prompt in `${CLAUDE_SKILL_DIR}/review-prompt.md` filled in: the change name, its folder, the base branch, the findings rejected in earlier rounds with your reason for each (so it does not raise them again), and the failures from the latest checks. A new agent every round: the fresh context is what lets a round find what the last one missed. Never send it this conversation or earlier rounds' accepted findings.
2. Present its findings as a numbered list: id, file and line, the problem, why it matters, the edit it proposes. Then use `AskUserQuestion` to ask which to accept: `Accept all`, `Accept none`, or the numbers to accept typed into Other (for example `1, 3, 4`). Ask once per round; never accept a finding the user did not pick. A round whose reviewer returned no findings asks nothing.
3. Apply each accepted finding yourself, inside the change folder only: rewrite a task with a file, a function, and an observable result; reorder or split sections; copy a missing scenario back into a MODIFIED block; fix the Why. Never tick a box and never change the change's name.
4. Run Step 3's checks. Fix every failure the edits caused and run them again; after three tries on the same failure, stop the loop and bring it to the final stop as an open problem.
5. Record the round: findings raised, accepted, rejected (with the reason the user gave, when given), files changed, and whether the checks passed. A round is **clean** when the user accepted none of its findings and no file in the change folder changed during it, a fix for a failing check included. A round that changed a file is not clean, whatever its findings, so the next reviewer reads the new text.

Repeat with `n + 1` until two consecutive rounds are clean, or `n` reaches `--max-rounds`. Since a clean round changes no file, the last two reviewers read exactly the files the record names.

## Step 3: The checks

Each as its own Bash call:

```bash
openspec validate <change> --strict --no-interactive
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-propose-check" <change>
reeve openspec render --dir . --change <change> --as <repo> --grade
```

The validator must pass, the checker must exit 0, and the render must exit 0 (every section ticket and the archive ticket passed intake's rubric; 1 is a parse rejection, 2 a failed or unparseable grade; read each grade's notes). Never silence a check: no filler text, no requirement dropped to pass, no box ticked.

## Step 4: Write the record

Write it only after every check passed on the last round, and make it the last write to the folder; any edit after it makes the record stale, and Reeve reads a stale record as unpolished.

- Converged (two consecutive clean rounds): `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-spec-polish" write <change> <rounds> <clean rounds> <rubric hash>`, where `<clean rounds>` is the count of consecutive clean rounds at the end and `<rubric hash>` is the hash from the last render.
- Stopped at `--max-rounds` without converging: use `AskUserQuestion` to ask whether to write the record anyway (Reeve reads fewer than two clean rounds as `unconverged`, so it counts as unpolished) or to stop without one.

`write` exits 3 when a kept file (`tasks.md`, `proposal.md`, `.openspec.yaml`, or a `specs/<capability>/spec.md`) is a symlink: git commits the link's target path, not the content Reeve plans from, so no record can cover it and Reeve never counts the change as polished. Stop and name the file; replacing the link with a regular file is the owner's call.

Then confirm it, each as its own Bash call:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-spec-polish" check <change>
reeve openspec render --dir . --change <change> --as <repo>
```

`check` exits 0 only for `polished`. The render's second line is what Reeve will read at planning, `# polish: polished: <rounds> rounds, <clean> clean, files match; files hash <hash>`; when it says anything else, stop and show it. One exception: the render hashes the bytes on disk, while `check` and GitHub see the blob git commits, so in a checkout whose filters rewrite files on commit (`core.autocrlf`, `.gitattributes` `eol` or `filter`) a render line of `stale` beside a `polished` check means line endings, not an edit. Say so, and run the render again from a clean clone after the commit if the user wants Reeve's own reading.

## Step 5: Final stop, then commit

**Final stop.** Present the round table (per round: raised, accepted, rejected, checks), every accepted finding with its edit in one line, every rejected finding with its reason, the final check results with each section's five scores, and the record. Use `AskUserQuestion` to ask whether to commit, change something first, or stop without committing. Do not commit without a yes; on "change something", the change starts a new round (the record is now stale) and the loop continues.

On yes, each as its own Bash call:

1. When the current branch is `base_branch`, create one: `git checkout -b docs/polish-<change>` (the repository's documented branch convention when it has one).
2. `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-propose-check" <change>`; it must be clean.
3. `git add openspec/changes/<change>/`, then one commit, `docs(openspec): polish <change> (<rounds> rounds)` (the repository's commit convention if it differs). No attribution lines.
4. Read the upstream with `git rev-parse --abbrev-ref @{upstream}`. When it is `origin/<current branch>` and the current branch is not `base_branch`, `git push origin HEAD:<current branch>`. Otherwise (no upstream, another remote, or an upstream named differently, such as `origin/main` on a branch made from it) say the branch is not pushed and leave the push to the user; a bare `git push` could update the default branch. **Never merge**: the change's PR still waits for review, and Reeve plans it once that PR merges.

## Step 6: Final report

One message the user can paste onto the change's ticket: the change, the round count and how many were clean, each round's raised, accepted, and rejected counts, the accepted findings in one line each, the rejected ones with their reasons, the record's `files_hash` and `rubric_hash`, the commit, and the push or the note that the branch is local.

## Error handling

| Situation | Action |
|---|---|
| A missing or invalid argument | Stop at Step 0 with the usage |
| `ccm-openspec-version` reports `too-old`, `unsupported`, or `missing` | Stop at Step 1; name the install command |
| The preflight reports `planned` | Stop; the change is on the default branch already, so the fix is `reeve replan`, not this skill |
| The Reeve CLI or its grading config is missing | Stop at Step 1; the loop needs `render --grade` |
| `ccm-propose-check` reports `outside-change` | Stop; this skill writes only under the change folder |
| A check still fails after three tries | End the loop; report it at the final stop and write no record unless the user asks |
| The reviewer agent fails or returns nothing readable | Dispatch it once more; then end the round as not clean and say so |
| The render says `stale` while `check` says `polished` | Line endings rewritten by the checkout's filters; say so (Step 4) |
| The user declines at the final stop | Leave the edits and the record uncommitted and say so |
