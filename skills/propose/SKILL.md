---
name: propose
user-invocable: true
allowed-tools: Read(*), Glob(*), Grep(*), Agent(Explore), Task(Explore), AskUserQuestion(*), Write(openspec/changes/**), Edit(openspec/changes/**), Bash(openspec:*), Bash(${CLAUDE_PLUGIN_ROOT}/bin/ccm-openspec-version *), Bash(ccm-openspec-version *), Bash(${CLAUDE_PLUGIN_ROOT}/bin/ccm-propose-check *), Bash(ccm-propose-check *), Bash(${CLAUDE_PLUGIN_ROOT}/bin/ccm-context *), Bash(ccm-context *), Bash(git status:*, git diff:*, git log:*, git show:*, git rev-parse:*, git ls-files:*, git ls-tree:*, git fetch:*, git switch:*, git checkout -b:*, git add openspec/changes/:*, git commit:*, git push -u origin:*), Bash(gh repo view:*, gh pr create:*, gh pr list:*, gh issue create:*), Bash(reeve openspec render:*)
description: Turn an idea, a ticket, or a document such as a BRD into reviewed OpenSpec changes (one PR per change) on a repository with OpenSpec, or into Linear tickets that pass intake grading on one without. Interactive, with a stop after the split and before anything is opened or created. Use when work needs to be broken into shippable increments before anyone builds it.
argument-hint: "<a sentence | TICKET-ID | path/to/document>"
---

# Propose

Turn `<input>` into work that Reeve (or a person) can build one increment at a time: OpenSpec changes on a repository that has OpenSpec, Linear tickets on one that does not. The split is the product of this skill. Each change or ticket must ship on its own, and each section of a change is one pull request.

The rules for a change folder are in `${CLAUDE_SKILL_DIR}/change-format.md`; the rules for a ticket are in `${CLAUDE_SKILL_DIR}/ticket-format.md`. Read the one for the mode before Step 4.

This skill is standalone and interactive. No ticket workflow (`auto-ticket`, `work-ticket`, `finish-ticket`, or any `auto-*` agent) runs it. The steps are numbered so another caller can follow them; an unattended caller would replace each question and stop with its own decision rule, and that caller does not exist yet.

## What this skill may write

OpenSpec mode: only `openspec/changes/<name>/**` for the changes this run creates, plus a branch, a commit, a push, and a pull request per change. Never `openspec/specs/**`, an existing change, code, tests, CI, or configuration. The `Write` and `Edit` grants above are restricted to `openspec/changes/**`, and `ccm-propose-check` fails on any other changed or untracked path before the commit. Never merge a pull request, and never push with `--force`.

Ticket mode: only new tickets in the tracker, created after Stop 2. It edits no file and no existing ticket.

In both modes, never copy a secret, a credential, a personal email address, a phone number, or an account identifier from the input or the repository. Name the key or the role instead.

## Step 0: Parse the input

`<input>` is one of:

| Input | Kind | How to read it |
|---|---|---|
| A path to a readable file (`.md`, `.txt`, `.pdf`, `.docx` export) | document | Read it in full |
| A string matching `ticket_id_regex` from `ccm-context` (`ENG-123`), or `#42` on GitHub | ticket | Fetch it the way `/ccmagic:work-ticket` Step 1 does, with the tracker resolved as in its Step 0b; stop if it cannot be found, and never guess its content |
| Anything else | idea | The sentence itself |

Empty input is a usage error: say what the three kinds are and stop. A path that does not exist is not an idea; say so and stop.

For a document, number its requirements before anything else: `R1`, `R2`, ... in the document's order, one per distinct thing it asks for (a "shall", a user story, an acceptance line, a constraint), each with a one-line paraphrase and its location (`section 3.2`, `page 4`). This list drives Step 6 and the final report. Never put a requirement's personal or secret details in the paraphrase.

## Step 1: Preflight and mode

Run, at the repository root:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-context"
```

Stop when it fails (not a git repository). Keep `base_branch`, `config`, and the repository's `owner/name`.

**Mode.** OpenSpec mode when `openspec/specs/` or `openspec/changes/` exists, else ticket mode. Say which, in one line, with the reason.

OpenSpec mode also needs:

1. `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-openspec-version"`: on `ok` continue; on `newer` continue with the one-line warning `OpenSpec {version} is newer than {tested}; the format rules here were checked against {tested}.`; on `too-old`, `unsupported`, or `missing`, stop and name the install command `npm i -g @fission-ai/openspec@{tested}`.
2. A clean working tree (`git status --porcelain` empty), and the current branch is `base_branch` (switch to it when the tree is clean; otherwise stop and ask the user to commit or stash).
3. `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-propose-check" --probe-reeve`, kept for Step 5: `cli`, `repo`, `grade`, and `missing`. It never prints a key's value.

Ticket mode also needs the tracker, resolved as `/ccmagic:work-ticket` Step 0b does. Linear is the supported tracker. GitHub Issues (`gh issue create`) and JIRA (the Atlassian MCP) work on a best-effort basis: say so at Stop 2.

## Step 2: Read the repository

Read before asking anything, so the questions are only what the repository cannot answer.

- `CLAUDE.md`, `README*`, `docs/`, `context/knowledge/` (from `/ccmagic:map-codebase`), and the CI workflow for the test command.
- The code the input touches: find it by search (routes, modules, config keys, terms from the input). For a large area, dispatch at most 4 read-only `Explore` agents (`model: "sonnet"`) in one message, each with one question and a request for `path:line` citations, and wait for all of them.
- OpenSpec mode: every `openspec/specs/*/spec.md` the work may touch (read each in full: its Purpose, requirement names, and scenarios), every active change under `openspec/changes/` (not `archive/`): its `proposal.md` and `tasks.md`, and the folder names under `openspec/changes/archive/`. Note any active change that overlaps the input; a new change never edits the same requirement as an active one, and never reuses an active or archived name.
- Ticket mode on Linear: open tickets in the team that overlap the input (search by its key terms), so a ticket is not proposed twice.

## Step 3: Questions

List what the repository did not settle: owner intent (what done looks like, who uses it), business constraints (deadlines, compatibility, cost), risk (data migration, security, a public API), and any conflict between the input and the code. Drop every question the code, the docs, the specs, or the input already answer.

Ask the rest with `AskUserQuestion`, **one question at a time**, each with 2 to 4 concrete options and your recommendation first. Wait for each answer before the next. Stop asking once the split in Step 4 no longer depends on the answer. No questions is a fine outcome; say so in one line.

## Step 4: The split, then Stop 1

Split the work in two levels:

1. **Increments.** Each increment ships on its own and leaves the product working: something a user or an operator can see, or a refactor that the next increment needs. In OpenSpec mode an increment is one change; in ticket mode it is a group of tickets.
2. **Sections.** Each section is one pull request a coding agent can finish in one session, with concrete, testable tasks. OpenSpec mode: two or three sections per change (one is fine for a small change; four or more means split the change), in dependency order. Ticket mode: one ticket per section, with blocking relations in the same order.

Follow `change-format.md` or `ticket-format.md` for names, task wording, and size. When one change would MODIFY a requirement another change in this run adds or modifies, it cannot be written until the first is archived: keep it out of this run and list it in the final report as "propose after `<change>` is archived".

**Stop 1.** Present the split before writing anything:

- per increment: the change name (or ticket group), one line of why, and the capabilities it adds or modifies (OpenSpec mode);
- per section: its title, its tasks in one line each, and what it depends on;
- for a document input, the coverage table: each `R<n>` and the change and section (or ticket) that covers it, or `not covered` with the reason;
- what is out of scope, and each overlap with an active change or open ticket.

Use `AskUserQuestion` to ask whether to accept the split, change it (merge, split, rename, reorder, drop), or stop. Apply changes and show the revised split; do not write until the user accepts one. The split is where a mistake is expensive: once Reeve plans a change, its sections are append-only.

## Step 5: OpenSpec mode, write and check

For each accepted change, in order:

1. Write `openspec/changes/<name>/proposal.md`, `tasks.md`, `.openspec.yaml`, and one `specs/<capability>/spec.md` per capability, exactly as `change-format.md` says. A MODIFIED requirement copies the whole current block by its exact name from `openspec/specs/<capability>/spec.md` and edits it; a new capability's delta has a `## Purpose`.
2. Run the checks, each as its own Bash call:

   ```bash
   openspec validate <name> --strict --no-interactive
   "${CLAUDE_PLUGIN_ROOT}/bin/ccm-propose-check" <every change name in this run>
   ```

   `ccm-propose-check` prints JSON: exit 0 clean, 1 with `findings` (each a `rule`, `file`, `line`, `message`), 3 when it cannot read the repository, 4 on a usage error. An `outside-change` finding means something outside the new folders changed; stop and tell the user, since this skill never writes there.
3. Reeve's render, when the probe found a `cli`:

   ```bash
   reeve openspec render --dir . --change <name> --as <repo>
   ```

   with `{cli}` in place of `reeve` when the probe's `cli` is a `REEVE_CLI` command (the user approves that call), and `--grade` added when the probe's `grade` is true. It exits 0 when every graded section ticket and the archive ticket passed, 1 on a parse rejection (`rejected (<rule>) in <file>:<line>: <reason>`), 2 when a graded ticket failed or came back unparseable; read each grade's notes. When the probe found no `cli`, skip this step and keep a note for Stop 2: the render was not run, and how to run it (put `reeve` on PATH, or set `REEVE_CLI` to a command such as `npx tsx /path/to/reeve/src/cli.ts`). When it found a `cli` but `grade` is false, run without `--grade` and note the `missing` names (Reeve's config by `REEVE_CONFIG`, `LINEAR_API_KEY`, `ANTHROPIC_API_KEY`). ccmagic never requires Reeve.
4. Fix and repeat until the validator, the checker, and the render (when run) all pass. Fix the cause: a vague task gets a file, a function, and an observable result; a failing `context` grade gets the paths; a name collision gets a new name. Never silence a check: no filler text, no requirement dropped to pass, no box ticked. After three rounds on the same failure, stop and bring it to Stop 2 as an open problem.

## Step 6: Ticket mode, draft

Draft each ticket as `ticket-format.md` says: a title, the problem, the change, acceptance criteria, context with `path:line` citations, out of scope, and for a document input a `Covers:` line naming its `R<n>`. Resolve the team and project: `config.linear_team` and `config.linear_project` from `ccm-context`, else ask with `AskUserQuestion` (offer the teams and projects the Linear MCP lists, and offer to save the answer to `.claude/ccmagic.local.md` by telling the user the two lines to add; this skill does not write that file). Create nothing yet.

## Step 7: Stop 2, then open or create

**Stop 2.** Present:

- OpenSpec mode: per change, the file list, the section titles with their task counts, the validator and checker results, and the render result per ticket (each grade's five scores when graded, or the note saying why the render or the grading was skipped).
- Ticket mode: every ticket in full (title and description), its blocking relations, and the team, project, and state (`Backlog`) it will be created in.
- For a document input, the final coverage table and the uncovered list.

Use `AskUserQuestion` to ask whether to proceed, change something first, or stop. Do nothing below without a yes.

**OpenSpec mode, on yes,** for each change in order, each command as its own Bash call:

1. Branch from `base_branch`: named by the repository's documented branch convention when it has one (`CLAUDE.md`, `CONTRIBUTING*`, `context/branching.md`), else `docs/propose-<name>`. `git checkout -b <branch> <base_branch>`.
2. `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-propose-check" <every change name in this run>` once more; it must be clean.
3. `git add openspec/changes/<name>/`, then one commit, `docs(openspec): propose <name>` (the repository's commit convention if it differs). No attribution lines.
4. `git push -u origin <branch>`, then `gh pr create --base <base_branch> --head <branch> --title "docs(openspec): propose <name>" --body "<body>"`. The body: the change's Why, the sections with their tasks, the capabilities added or modified, the checker and validator results, the render and grade results or the note that they were skipped, and for a document input the coverage table. A section is planned into a Reeve ticket once this PR merges, so say that its sections are append-only after the merge.
5. `git switch <base_branch>` before the next change; the next change's folder is still untracked and moves with you.

**Never merge.** Each PR waits for review.

**Ticket mode, on yes:** create the tickets in dependency order, so each one's blockers already have identifiers. Linear: `save_issue` with `team`, `project`, `state: "Backlog"`, `title`, `description`, and `blockedBy` naming the earlier tickets it depends on. GitHub: `gh issue create --title ... --body ...`, with a `Blocked by #N` line in the body. JIRA: the Atlassian MCP create call, then an "is blocked by" link where the MCP offers one. Print each created ticket's identifier and URL. If a create fails, stop, list what was created, and do not retry blindly: a create that landed and errored would make a duplicate, so search for the title first.

## Step 8: Final report

One message:

- OpenSpec mode: each change with its PR URL; ticket mode: each ticket's identifier, title, and blockers.
- Checks run and their results; any check skipped, and how to run it.
- For a document input: the coverage table and the list of requirements nothing covers, each with the reason (out of scope by the owner's answer, needs a decision, belongs to another system, or deferred to a later change).
- Changes left for later ("propose after `<change>` is archived") and open problems from Step 5.

## Error handling

| Situation | Action |
|---|---|
| Empty input, a missing path, or a ticket that cannot be fetched | Stop at Step 0 with the reason |
| `ccm-openspec-version` reports `too-old`, `unsupported`, or `missing` | Stop at Step 1; name the install command |
| Dirty working tree (OpenSpec mode) | Stop at Step 1; ask the user to commit or stash |
| `ccm-propose-check` reports `outside-change` | Stop; this skill writes only under the new change folders |
| A check still fails after three fix rounds | Report it at Stop 2; the user decides whether to stop or open the PR as a draft for discussion |
| The Reeve CLI or its config is missing | Skip the render or the grading with a note; never stop for it |
| A ticket create fails partway | Stop; list what was created; search before any retry |
| User declines at a stop | Leave written change folders uncommitted in the working tree and say so; create no ticket |
