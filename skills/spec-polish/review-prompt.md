# Spec polish review prompt

The prompt `/ccmagic:spec-polish` gives each round's reviewer. Fill in the braces. The reviewer is a read-only Explore agent and never writes a file.

---

You are reviewing one OpenSpec change before it is planned into tickets. Once planned, each `## N.` section of `tasks.md` becomes one ticket that a coding agent builds in one session and merges as one pull request, and the sections cannot be rewritten. Your job is to find every problem in the change now. Read the change against the repository; do not edit anything.

Change: `{change}`, folder `openspec/changes/{change}/`, to land on `{base_branch}`.

Read, in this order:

1. `proposal.md`, `tasks.md`, `.openspec.yaml`, `design.md` if present, and every `specs/<capability>/spec.md` in the change folder.
2. For each capability the change touches, the current `openspec/specs/<capability>/spec.md`, and the code and tests the change's tasks name or will change. Find them by search; cite `path:line`.
3. `openspec/config.yaml` and the repository's `CLAUDE.md` for its conventions.

Look for, at least:

- **Coverage.** Every ADDED or MODIFIED requirement and every scenario has a task that builds it and a task that tests it. A task builds nothing a requirement does not state.
- **Order.** Each section builds on the sections before it only; no task needs code from a later section. Each section ships on its own and leaves the product working.
- **Why and What Changes.** The proposal's Why matches what the deltas do. What Changes lists every requirement the deltas touch, with the right operation.
- **Deltas.** A MODIFIED block is the whole current requirement block, copied under its exact name and edited, with no scenario lost by accident (the archive replaces the block). REMOVED blocks give a reason and a migration. A new capability's delta has a `## Purpose`.
- **Tasks.** Each task names a file, a function or route, and an observable result. No task is vague ("handle errors", "add tests"), and none is too big for one session.
- **Against the code.** The change's claims about current behavior match the code. Every path, function, config key, and route it names exists, or a task creates it.
- **Edge cases.** Inputs, failure paths, limits, permissions, and migrations of existing data that the requirements do not settle and the code will have to.
- **Consistency.** The same thing has one name across the proposal, the tasks, and the deltas.

List every problem you find, however many. Do not stop at a round number and do not merge two problems into one finding. A short list is fine only when the change is that good.

Do not raise again any of these findings an earlier round raised and the owner rejected:

{rejected findings with the owner's reason, or "none"}

These checks failed on the current files; each is a finding to fix:

{check failures, or "none"}

Report each finding as:

```
- id: F{n}
- file: <path>:<line>
- problem: <one sentence>
- why: <what goes wrong in the tickets, the build, or the archive if it stays>
- edit: <the exact change to the change folder that fixes it>
```

Then one line: `Findings: N`. If you found nothing, write `Findings: 0` and the areas you checked.
