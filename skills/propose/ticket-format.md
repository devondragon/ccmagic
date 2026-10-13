# Ticket format

How `/ccmagic:propose` writes a ticket on a repository without OpenSpec, so that it passes Reeve's intake grader and a coding agent can build it in one session and one PR.

The grader scores each ticket 1 to 5 on five dimensions and passes it only with 4 or more on every one:

| Dimension | The question | What earns a 4 or 5 |
|---|---|---|
| clarity | Can a reader state the goal in one sentence without guessing? | The title states the outcome; the first line of the description says the problem and the change |
| scope | Is the change bounded to one repository and one coherent slice of work? | One repository, one PR, and a written out-of-scope list |
| acceptance_criteria | Are there testable criteria that define done? | A checklist of observable results, each one checkable by a test or a command, including the test to add |
| context | Are the files, docs, or examples the implementer needs named or linked? | `path:line` citations for the code to change and the code to imitate, and links to the docs that apply |
| actionability | Could an engineer start now without asking a question? | Every decision already made in the text; no "decide", "investigate", "consider", or "if needed" |

## Template

Title: an imperative outcome under 80 characters, such as "Reset a counter to zero".

```markdown
## Problem

<1 to 3 sentences: what is wrong or missing today, and for whom.>

## Change

<What to build, in plain steps. Name the files and functions. Every decision is made here.>

## Acceptance criteria

- [ ] <observable result, with the test that proves it and its file>
- [ ] <observable result>
- [ ] Existing tests pass (`<the repository's test command>`)

## Context

- `<path>:<line>`: <what is there and why it matters>
- <link to a doc or an earlier ticket>

## Out of scope

- <what a reader might expect here that belongs to another ticket; name it>

## Covers

<For a document input only: "R2, R5 of <document title>". Leave the section out otherwise.>
```

## Rules

- One ticket per section of the split: one PR's worth of work, built in one session. A ticket that needs two PRs is two tickets with a blocking relation.
- Blocking relations follow dependency order; a ticket never depends on a later one.
- A question for the owner is asked in Step 3, never written into a ticket.
- Never mention an agent or a user with `@`, and never paste a profile URL: Reeve comments as its owner, and a mention can start a session with write access.
- US English. No em dash or en dash. No secret, credential, personal email address, phone number, or account identifier from the document or the code: name the role or the config key.
