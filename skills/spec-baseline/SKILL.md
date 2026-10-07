---
name: spec-baseline
user-invocable: true
allowed-tools: Read(*), Glob(*), Grep(*), Agent(Explore), Task(Explore), AskUserQuestion(*), Skill(*), Write(openspec/**), Edit(openspec/**), Write(docs/openspec-baseline.md), Edit(docs/openspec-baseline.md), Bash(openspec:*), Bash(${CLAUDE_PLUGIN_ROOT}/bin/ccm-openspec-version *), Bash(ccm-openspec-version *), Bash(git status:*, git diff:*, git log:*, git show:*, git rev-parse:*, git ls-files:*, git merge-base:*, git symbolic-ref:*, git switch:*, git checkout -b:*, git add:*, git commit:*), Bash(${CLAUDE_PLUGIN_ROOT}/bin/ccm-baseline-check *), Bash(ccm-baseline-check *), Bash(${CLAUDE_PLUGIN_ROOT}/bin/ccm-context *), Bash(ccm-context *)
description: Write OpenSpec baseline specs describing an existing codebase's current behavior, with a committed evidence file of code citations and tests, two review stops, and deterministic checks. Use when a repository has no openspec/specs yet, before a change has to MODIFY a capability that has no spec, or with --check to find citations gone stale.
argument-hint: "[--capability <name>] [--check]"
---

# Spec Baseline

Write `openspec/specs/<capability>/spec.md` files that describe what the code does today, at a named commit, so that later OpenSpec changes can `MODIFY`, `REMOVE`, or `RENAME` their requirements and `openspec archive` applies cleanly. The evidence (code citations, pinning tests, flags) goes in one committed file, `docs/openspec-baseline.md`, never in a spec.

A wrong baseline is worse than none: every later delta copies its requirement blocks, Reeve renders them into ticket bodies, and `openspec archive` matches them by name. The quality bar is `${CLAUDE_SKILL_DIR}/quality-checklist.md`; the evidence format is `${CLAUDE_SKILL_DIR}/evidence-format.md`. Read both before Step 3.

This skill is standalone and interactive. No ticket workflow (`auto-ticket`, `work-ticket`, `finish-ticket`, or any `auto-*` agent) runs it.

## What this skill may write

Only `openspec/**` and `docs/openspec-baseline.md`. It never changes code, tests, CI, configuration, or policy files. The `Write` and `Edit` grants above are restricted to those paths, and `ccm-baseline-check` fails on any other changed or untracked path before the commit. If a fix seems to need another file, report it at Stop 2 instead.

Never write a secret. Configuration files often hold credentials; refer to keys by name only.

## Step 0: Parse arguments

| Argument | Mode | What it does |
|---|---|---|
| *(empty)* | full | Map every capability, specify the accepted ones, commit, open a PR |
| `--capability <name>` | one | Specify one capability in a repository that may already have specs; touch only its spec, its evidence section, and its map row |
| `--check` | check | Re-run the checks and report citations gone stale since the baseline commit; writes nothing |

`--check` with `--capability` is a usage error. Run the scripts by `${CLAUDE_PLUGIN_ROOT}/bin/<name>`, and fall back to the bare name only when the path form is not found or is denied.

## Step 1: Preflight

Stop with a plain message, before any write, when any of these fails:

1. The current directory is the top level of a git repository (`git rev-parse --show-toplevel` equals the working directory). The path-restricted grants are relative to it.
2. The installed OpenSpec CLI is a supported version. Run `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-openspec-version"` (the bare name only when the path form is not found or is denied) and read its JSON. Print `version`. On `status` `ok`, continue. On `newer` (a later 1.x release), continue and print one warning line: `OpenSpec {version} is newer than {tested}; the format rules here were checked against {tested}.` On `too-old`, `unsupported`, or `missing` (exit 1), stop with a message that names the required minimum and the install command: `openspec {version, or "is missing or unreadable"}; this skill needs {tested} or a newer 1.x release (npm i -g @fission-ai/openspec@{tested})`.
3. Full and one modes: `git status --porcelain` is empty. Record `BASELINE_SHA=$(git rev-parse HEAD)`; every citation will refer to this commit.

**`--check` mode** stops here and runs:

```bash
openspec validate --all --strict --no-interactive
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-baseline-check" --stale
```

Report the validator's result, every finding, and every stale citation grouped by capability and requirement with the commits that touched the file (the `stale` array; a citation on a flag line names its flag in `flag`). Under `--stale` the checker skips the changed-paths check, since code changing after the baseline is what staleness measures. A stale citation does not mean the spec is wrong, only that someone should look at that requirement against the current code. Exit 3 from the checker means the evidence file, the specs, or a baseline commit is missing; say which. Write nothing and end.

Full and one modes continue:

4. If `openspec/` is missing, run `openspec init --tools none --no-animation .` (it creates `openspec/config.yaml`, `openspec/specs/.gitkeep`, and `openspec/changes/archive/.gitkeep`). The `config.yaml` it writes is a commented template with no `context:` block; Step 5 replaces it.
5. Read every existing `openspec/specs/*/spec.md` and `docs/openspec-baseline.md`, so the run extends them rather than overwriting them. An existing spec or evidence section is never rewritten, except the one capability named in one mode.

## Step 2: Orientation

Read the repository's own docs first: `CLAUDE.md`, `README*`, `docs/`, `.planning/`, `context/knowledge/` (written by `/ccmagic:map-codebase`, if it ran), and the CI workflow for the build and test commands. Docs are for orientation; code is the source of every fact, and docs often disagree with it.

Then inventory entry points by search, not by reading everything: HTTP routes and router files, listening ports, scheduled or cron jobs, filters and middleware, CLI commands, message or queue consumers, startup hooks. Note the test layout and the configuration files (base and per environment). The inventory is the raw material for the map.

## Step 3: Capability map, then Stop 1

Propose the map, using the capability rules in the quality checklist. For each capability:

- name: single-segment kebab-case, a behavior noun, not on Reeve's routing word list;
- purpose: one line stating observable behavior;
- implementing files and the tests that may pin it;
- estimated requirement count (3 to 12; otherwise split or merge).

Then a "not specified" list: cross-cutting wiring, unreachable code, log-only behavior, deployment files, each with a one-line reason. Note any configuration value that looks like a credential, by key name.

**One mode:** propose the named capability's row, plus one row marked `not yet specified` for each neighbor: a capability that owns behavior the named one's files touch but that has no spec yet (a neighbor that already has a spec keeps its row). Name neighbors as capabilities, with the same naming rules. Check the name against existing `openspec/specs/` folders, and compare its purpose with each existing spec's `## Purpose`; report any overlap, since two specs describing one behavior make a later MODIFIED ambiguous.

In every mode, a behavior may be left out of a capability as belonging to another capability only when that other capability is in the map. Behavior handed to a capability nobody mapped falls out of every spec.

**Stop 1.** Present the map as a table plus the not-specified list, and use `AskUserQuestion` to ask the user to accept it, rename, merge, or split capabilities, or restrict the run to a subset. Do not extract anything before the answer. Apply the answer and confirm the final list in one line. The map is where a wrong decision is expensive to undo: renaming a capability later renames a folder every change refers to.

## Step 4: Extraction

For each accepted capability, dispatch one read-only subagent with the prompt in `${CLAUDE_SKILL_DIR}/extraction-template.md`, filled in for that capability (`subagent_type: Explore`, `model: "sonnet"`). Its `{neighbors}` are only capabilities in the map. Dispatch at most 4 at once, each batch in one message, then wait until every agent in the batch has returned before dispatching the next batch or authoring anything. The subagents never write files. Order: specify a client-side capability (browser script, UI) last.

When an agent's "Capability boundary" note says the cut is wrong, decide before authoring: move the behavior to the right capability, or come back to the user with a revised map row (a second Stop 1 for that row). When it hands behavior to a capability not in the map, either add that capability to the map (in one mode, as a `not yet specified` row) or keep the behavior in the capability being specified.

## Step 5: Authoring

The session writes every spec and evidence section itself, from the extraction output. Do not delegate it: naming, granularity, and consistency across capabilities are the judgment calls, and extraction output always needs reshaping (several of an agent's behaviors become one requirement with scenarios; a behavior with two clocks becomes one requirement with a scenario per clock).

For each capability, applying `${CLAUDE_SKILL_DIR}/quality-checklist.md` item by item:

0. Verify every extraction claim that something is unreachable, unused, dead, or has no effect before acting on it: grep for its callers, readers, or references yourself (method and function names, configuration keys, routes, event names) and read each hit. Extraction agents miss callers. A claim that turns out wrong makes the item a behavior, specified like any other.
1. Write `openspec/specs/<capability>/spec.md`: `# <capability> Specification`, `## Purpose`, `## Requirements`, then `### Requirement:` blocks with `#### Scenario:` blocks. One decision per requirement, named by concern; one branch per scenario, named by condition, never by a value; SHALL statements of current behavior, bugs included; configuration keys with their shipped default; no code, file, class, method, line, or citation in a spec.
2. Write the capability's section of `docs/openspec-baseline.md` in the exact format of `${CLAUDE_SKILL_DIR}/evidence-format.md`: a `### Requirement:` heading per requirement, a `- Scenario:` line per scenario with full-path citations and `Tests:`, then the flag lines from the extraction, then `### Left out of the spec on purpose`. Re-read each cited line before writing its citation; never cite from the agent's numbers alone.
3. On the first capability, write the evidence file's header with `Baseline commit: $BASELINE_SHA`, the `## 1. Capability map` table (every capability from Stop 1, specified, mapped, or not yet specified), `### Not specified`, and `### Secrets in configuration`. Both subsections are written in every mode, one mode included; when one has nothing in it, it holds `None found.`
4. Every behavior the extraction left out as another capability's goes in that capability's spec, or, when that capability is not specified in this run, under its name in `### Not specified` (format: `evidence-format.md`). Nothing the extraction found disappears without a line in a spec or in the evidence file.

**One mode:** write only `openspec/specs/<name>/spec.md` and that capability's section, replacing the section if it exists and appending it otherwise. If the evidence file's header names a different commit than `$BASELINE_SHA`, put `Baseline commit: $BASELINE_SHA` as the section's first line. Update the capability's row in the map table (add it if the map never listed it), add a `not yet specified` row for each neighbor the map does not list, and list each behavior excluded to a neighbor under that neighbor in `### Not specified`. If the evidence file does not exist yet, create it with the header, the map (the capability's row and its neighbors' rows), `### Not specified`, `### Secrets in configuration`, and the section. Leave every other spec and section alone.

**`openspec/config.yaml`:** if it holds no top-level `context:` block (the template `openspec init` writes has none, only comments), replace the whole file with `schema: spec-driven` and a `context:` block of 20 to 30 lines: what the project is, the stack, the build and test commands, that `openspec/specs/` describes current behavior at the commit named in `docs/openspec-baseline.md` and that evidence lives there, that a behavior change ships as a change with delta specs folded in by `openspec archive` (direct edits to `openspec/specs/` only to baseline a capability or correct a baseline error), that requirement and scenario names are identifiers (name by concern and condition), the Reeve constraints (one-segment kebab-case capability folders, requirement bodies under 500 characters, at most 4 scenarios per requirement), and never to write secrets into a spec. Keep an existing `context:` and add only missing points.

## Step 6: Checks

After each capability, and once more after the last:

```bash
openspec validate --all --strict --no-interactive
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-baseline-check"
```

`ccm-baseline-check` prints JSON: exit 0 clean, 1 with `findings` (each a `rule`, `file`, `line`, `message`), 3 when it cannot read the repository, the specs, or the evidence file. Fix every validator error and every finding before moving on. Fix the cause: correct the citation, rename a scenario by its condition, split a requirement. Never silence a check: no placeholder text, no Purpose padded with filler, no scenario dropped to make a name unique, no `UNTESTED` written over a test reference that did not resolve without first looking for the right test. An `outside-allowlist` finding means something outside `openspec/` and the evidence file changed; stop and tell the user, since this skill never writes there.

## Step 7: Review, Stop 2, commit, PR

**Stop 2.** Present, per capability: the requirement and scenario counts, the number of `UNTESTED` scenarios, and every `Looks unintended`, `Open question`, and `Docs disagree` item with its citation. Add a warning for every configuration key seen with a credential-looking value (by name only), and the final validator and checker results. Use `AskUserQuestion` to ask whether to commit and open the PR, change something first, or stop without committing. Do not commit without a yes.

On yes:

1. Read `base_branch` from `"${CLAUDE_PLUGIN_ROOT}/bin/ccm-context"`; it gives no naming convention. If the current branch is the base branch, create a branch from it: named by the repository's documented branch convention when it has one (`CLAUDE.md`, `CONTRIBUTING*`, `context/branching.md`), else `docs/openspec-baseline` in full mode and `docs/openspec-baseline-<name>` in one mode.
2. Run `ccm-baseline-check` one last time; it must be clean.
3. `git add openspec docs/openspec-baseline.md`, then one commit: `docs(openspec): baseline <capabilities>` (comma-separated names; the repository's commit convention if it differs). No attribution lines.
4. Invoke `/ccmagic:pr`. The description's first section is the capability map, copied from the evidence file; the second is the Stop 2 review summary; then a line pointing at `docs/openspec-baseline.md` as the evidence and saying `/ccmagic:spec-baseline --check` reports stale citations later.

On a repository Reeve governs, the PR lands at whatever tier its policy gives `openspec/**`; keep baseline specs out of any tier that merges without review.

## Error handling

| Situation | Action |
|---|---|
| `ccm-openspec-version` reports `too-old`, `unsupported`, or `missing` | Stop at Step 1; name the minimum `tested` version and the install command `npm i -g @fission-ai/openspec@{tested}` |
| `ccm-openspec-version` reports `newer` | Continue; print the one-line warning that the rules were checked against `tested` |
| Dirty working tree | Stop at Step 1; ask the user to commit or stash first |
| An extraction agent fails or returns no citations | Re-dispatch it once; then tell the user and skip that capability, recording it as mapped |
| Validator or checker finding that cannot be fixed without changing code | Leave the capability out of the commit, report why at Stop 2 |
| User declines at Stop 2 | Leave the files uncommitted in the working tree and say so |
