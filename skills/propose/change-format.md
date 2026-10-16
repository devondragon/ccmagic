# Change format

How `/ccmagic:propose` writes an OpenSpec change so that `openspec validate --strict` passes, Reeve's planner accepts it, and each section ticket passes intake. `ccm-propose-check` checks the parts that need no model; this file is the rest.

Reeve plans a merged change into a parent ticket, one ticket per `## N.` section of `tasks.md`, and an archive ticket. Each section ticket is built by a coding agent in one session and merged as one PR. Its body is rendered from the change: the proposal's Why, the requirements, the section's tasks, and every earlier section's tasks. Once planned, sections are append-only.

## The folder

```
openspec/changes/<name>/
  proposal.md
  tasks.md
  .openspec.yaml
  specs/<capability>/spec.md     one per capability added or modified
```

No `design.md` unless the owner asked for one. No other file. (`/ccmagic:spec-polish` later adds `.reeve.yml`, its record of the review loop, which strict validation ignores.)

## The name

- Lower-case kebab-case, a verb first, naming the outcome: `add-csv-export`, `trim-client-ip-in-range-match`. Keep it under 40 characters.
- Never `as-delegation`, `label-based-prompt`, `as-refine`, `linear`, or `profiles` anywhere in it, in any case (Reeve's `change-name` rule: the name is rendered raw into tickets, where these could start or steer a Cyrus session). Say "tracker" instead of "linear".
- Not `archive`, not the name of an active change, and not a name an archive folder already holds (`YYYY-MM-DD-<name>`).

## .openspec.yaml

```yaml
schema: spec-driven
created: YYYY-MM-DD
```

The keys the tested openspec release (`ccm-openspec-version`) knows are `schema`, `created`, `goal`, `affected_areas`, `initiative`, `skip_specs`, and `retire_capabilities`; strict validation rejects any other. Reeve reads only `skip_specs: true` (a change with no behavior change and no delta specs: a refactor, tooling, docs) and `retire_capabilities: true` (a change that deletes a capability's spec). Set either only when it applies.

## proposal.md

```markdown
# Proposal

## Why

<1 to 3 sentences: the problem, who has it, why now. Reeve copies this into every ticket, cut at 1,500 characters.>

## What Changes

- <one bullet per observable change; mark a breaking one **BREAKING**>

## Capabilities

### New Capabilities
- `<capability>`: <what it covers>

### Modified Capabilities
- `<capability>`: <which requirement changes>

## Impact

- <files, APIs, data, and callers affected, with paths>

## Coverage

Source: <the document's title or path>.

| Requirement | Covered by |
|---|---|
| R1. <paraphrase> | Section 1 |
| R4. <paraphrase> | Not covered: <reason> |
```

`## Coverage` appears only for a document input. It lists every requirement of the document that this change touches, and the ones it leaves to another change (name it) or leaves uncovered (give the reason). The final report repeats the uncovered list across all changes.

## tasks.md

```markdown
## 1. <Section title: the outcome of this PR>

- [ ] 1.1 <task>
- [ ] 1.2 <task>

## 2. <Section title>

- [ ] 2.1 <task>
```

Reeve's parser rejects, and `ccm-propose-check` reports with the same rule names:

- a section heading that is not `## N. Title` with a positive integer and a title (`section-title`), numbers that do not increase (`section-order`), or no section at all (`no-section`);
- a section with no task (`empty-section`), a task outside a section (`task-outside-section`), a numbered list marker on a task (`task-marker`);
- a task with no id, an id that does not start with its section number, a repeated id, or no text (`unnumbered-task`, `task-prefix`, `duplicate-task`, `task-text`);
- a section number or task id part past 9007199254740991 (`number-range`).

Every box is empty in a new change (`task-checked`). Two or three sections per change; more than three is `section-count`, so the later sections become another change.

Each section ticket is graded on five dimensions, 1 to 5, and needs 4 on each:

| Dimension | What earns a 4 or 5 in a section |
|---|---|
| clarity | The title states the outcome; a reader can state the goal in one sentence |
| scope | One repository, one coherent slice, one PR; nothing in it depends on a later section |
| acceptance_criteria | Each task names an observable, testable result, and at least one task adds or changes a test with its file |
| context | Tasks name the files, functions, routes, or config keys they change (`src/counter.js`, `increment`) |
| actionability | An engineer could start now: no "decide", "investigate", "consider", or "if needed"; every decision is already made in the task text |

Write tasks as instructions with the result in the sentence: "Add `reset(counter)` to `src/counter.js`, setting `counter.value` to 0 and returning 0, and export it", not "Implement reset". A task that needs an owner decision is a Step 3 question, not a task.

Order sections by dependency: section 2 may use what section 1 built, never the reverse. A section's ticket body lists every earlier section's tasks, so a later section may refer to them by id.

## Delta specs

`specs/<capability>/spec.md`, one folder per capability, one segment of kebab-case (`capability-name`; a nested path such as `identity/user-auth` is refused). Use the capability's exact folder name under `openspec/specs/` when it exists.

```markdown
## Purpose

<For a new capability only: 50 characters or more stating the observable behavior it owns.>

## ADDED Requirements

### Requirement: <name by concern>
The system SHALL <one decision>.

#### Scenario: <name by condition>
- **WHEN** <condition>
- **THEN** <result>

## MODIFIED Requirements

### Requirement: <exact current name>
<the whole current block, edited>

## REMOVED Requirements

### Requirement: <exact current name>
**Reason**: <why>
**Migration**: <what replaces it>

## RENAMED Requirements

- FROM: `### Requirement: <exact current name>`
- TO: `### Requirement: <new name>`
```

- A delta for a capability with no `openspec/specs/<capability>/spec.md` on the base branch needs `## Purpose` with text (Reeve's `new-capability-purpose`: `openspec archive` would otherwise write a placeholder Purpose that strict validation rejects, and the archive ticket could not finish).
- A MODIFIED requirement copies the whole current block, its body and every scenario, by its exact name, then edits it. `openspec archive` replaces the block by name, so a scenario left out is deleted. A MODIFIED, REMOVED, or RENAMED FROM name not in the current spec is `requirement-not-found`. A capability needing a MODIFIED delta but having no spec needs `/ccmagic:spec-baseline --capability <name>` first; say so at Stop 1.
- Every ADDED or MODIFIED requirement has at least one scenario with a WHEN and a THEN.
- Requirement bodies under 500 characters, at most 4 scenarios per requirement, names free of backticks, `@`, `<`, `>`, `&`, URLs, and trailing punctuation (Reeve rewrites these in ticket bodies).
- SHALL statements of behavior, not of code: no file, class, or function names in a spec. Those belong in `tasks.md` and the proposal's Impact.

## Writing

US English. No em dash or en dash anywhere (`dash`). No written email address, even spelled out (`personal-identifier`), no secret, no personal identifier: name the role or the config key.
