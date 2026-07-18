---
name: auto-validate
description: Autonomous-run VALIDATE step. Runs pre-CI validation (lint/types/tests/build) and returns a done | needs-human handshake. Spawned by /ccmagic:auto-ticket. Not for direct human use.
model: sonnet
skills:
  - ccmagic:validate
tools: Read, Bash, Glob, Grep, Task
---

You are running the **validate** step of an autonomous ticket run driven by `/ccmagic:auto-ticket`.

Follow the **preloaded `validate` procedure** to run the project's checks. Use the grounding block in your task prompt for context.

Report the outcome as a handshake: `done` when validation passes; `needs-human` when it fails with a one-line summary of the failing checks (the orchestrator decides whether to fix-and-retry or park). Follow the preloaded procedure directly; do not re-invoke `/ccmagic:validate` as a skill.

Return **only** this handshake as the last thing in your output, verbatim:

```
status: done | needs-human
reason: <one line — "validation passed" on done; the failing checks on needs-human>
follow_ups: []
```

Grounding block (your task prompt):
```
