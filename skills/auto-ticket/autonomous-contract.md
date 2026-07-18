# Autonomous Contract

The shared contract `/ccmagic:auto-ticket` uses to drive the ticket-lifecycle skills unattended. Every sub-skill's "Autonomous mode" section is written against this contract, so the orchestrator and the skills it calls agree on how to signal, hand off results, and park work.

---

## 1. The autonomous signal

A sub-skill enters autonomous mode when the first present signal (in priority order) resolves truthy:

1. `--autonomous` in the skill arguments.
2. An `autonomous: true` line in the **grounding/context block** the orchestrator prepends when invoking the skill.
3. `autonomous: true` in `ccmagic.local.md` frontmatter — the project file `.claude/ccmagic.local.md` first, then the user file `~/.claude/ccmagic.local.md` (see §5 for the full config precedence).

`/ccmagic:auto-ticket` always drives sub-skills via signal **#2** (the grounding block), which also marks the sub-skill as **orchestrated** — meaning the orchestrator, not the sub-skill, owns parking on a `needs-human` outcome.

## 2. The grounding block

The orchestrator prepends this block to the arguments of **every** sub-skill invocation. Sub-skills read `autonomous: true` to switch modes, and may reuse `tracker` / `ticket` to skip re-resolution:

```
AUTONOMOUS RUN CONTEXT
autonomous: true
orchestrator: auto-ticket
run_id: {short id}
tracker: {linear | github | jira}
ticket: {TICKET-ID}
ticket_url: {url}
pr: {PR number/url, once known}
base_branch: {base}
needs_human_state: {value}
needs_human_label: {value}
max_feedback_passes: {n}
```

A sub-skill that sees `orchestrator:` in its grounding block must **not** park on `needs-human` — it emits the handshake and returns control so the orchestrator performs the single route-and-stop.

When `fork_steps` is true, `auto-ticket` runs each step in a per-step subagent (`agents/auto-*.md`) on the step's model, passing this grounding block as the child's task prompt and reading back the child's handshake (§3). The child agents preload their lifecycle skill rather than invoking it, so the step runs on the agent's model. With `fork_steps: false`, steps run inline via the `Skill` tool. Either way the grounding block and handshake are identical.

## 3. The status handshake

In autonomous mode, every sub-skill ends its output with a fenced block:

```
status: clean | fixable-findings | needs-human | done
reason: <one line, when not clean/done>
follow_ups: [<ticket ids or short descriptions of anything filed/deferred>]
```

Which values each sub-skill can emit:

| Sub-skill | Emits |
|-----------|-------|
| `work-ticket` | `done` \| `needs-human` |
| `review-ticket` | `clean` \| `fixable-findings` \| `needs-human` |
| `pr-feedback` | `done` \| `needs-human` |
| `push` | `done` \| `needs-human` |
| `finish-ticket` | `done` \| `needs-human` |

Parse the **last** such block in the sub-skill's output. If a sub-skill fails to emit one (crash, tool error), treat it as `needs-human` with `reason: "{skill} produced no handshake"`.

## 4. Route-and-stop (park the ticket)

The single routine the orchestrator (or a standalone top-level sub-skill) runs whenever an outcome is `needs-human`, the feedback-pass cap is hit still-not-clean, or CI/validation can't be made green within bounds. **Never merge in this path.**

1. **Do not merge.** Leave the PR open.
2. **Move the ticket to `needs_human_state`:**
   - **Linear** — `mcp__*Linear*__save_issue` transitioning to the state whose name matches `needs_human_state` (case-insensitive). If no such state exists, apply `needs_human_label` via `save_issue` labels and leave the state unchanged.
   - **GitHub** — GitHub issues have no custom states. Apply `needs_human_label` with `gh issue edit {N} --add-label "{label}"` (create the label first with `gh label create` if missing). Leave the issue open.
   - **JIRA** — transition to the matching status via the Atlassian MCP; if no transition matches, apply `needs_human_label` as a label and leave the status unchanged.
3. **Comment the reason** on both surfaces (skip a surface only if it doesn't exist):
   - PR comment (`gh pr comment {PR} --body ...`) and ticket comment (`save_comment` / `gh issue comment` / Atlassian MCP), using the parked-comment template below.
4. **Emit the run's final status** (see the orchestrator's Step 6 summary) and exit cleanly. Never wait for input.

### Parked-comment template

```markdown
## 🅿️ Parked for a human — {TICKET-ID}

`/ccmagic:auto-ticket` stopped this run because it needs a human decision.

**Waiting on:** {the one-line reason from the sub-skill's handshake}
**Stage:** {work-ticket | review-ticket | pr-feedback | finish-ticket}
**PR:** {pr_url or "not created"}
**State moved to:** {needs_human_state, or "unchanged — applied label `{needs_human_label}`"}

**Autonomous decisions so far:**
{bullet list — classification, minor choices made, drift flagged}

**Follow-ups filed:** {ticket ids, or "none"}

Nothing was merged. Resolve the item above, then re-run `/ccmagic:auto-ticket {TICKET-ID}` (or continue manually).
```

## 5. Config keys

| Key | Type | Default | Meaning |
|-----|------|---------|---------|
| `autonomous` | bool | `false` | Default mode when no `--autonomous` flag and no grounding block is passed. |
| `needs_human_state` | string | *(none)* | Tracker state a parked ticket is moved to (e.g. `Blocked`, `Needs Human`). |
| `needs_human_label` | string | `needs-human` | Fallback label applied when `needs_human_state` doesn't exist (and always on GitHub). |
| `max_feedback_passes` | int | `3` | Cap on the `pr-feedback` loop (orchestrator Step 4) before parking. |
| `max_review_fix_passes` | int | `2` | Cap on the ticket-review fix loop (orchestrator Step 3) before parking. |
| `max_validate_attempts` | int | `2` | Cap on local `/ccmagic:validate` fix attempts (orchestrator Step 4b) before parking. |
| `ci_timeout_minutes` | int | `30` | Max minutes to wait for CI to settle (orchestrator Step 4c) before parking on timeout. |
| `ci_poll_interval_seconds` | int | `60` | Interval between CI status polls (orchestrator Step 4c). |
| `fork_steps` | bool | `true` | Run each lifecycle step in its own forked subagent; `false` runs them inline in the orchestrator. |
| `model_work_ticket` | string | `opus` | Model for the work step's agent (`auto-work`). |
| `model_review_ticket` | string | `opus` | Model for the review step's agent (`auto-review`). |
| `model_pr_feedback` | string | `sonnet` | Model for the pr-feedback step's agent (`auto-feedback`). |
| `model_finish_ticket` | string | `sonnet` | Model for the finish step's agent (`auto-finish`). |
| `model_validate` | string | `sonnet` | Model for the validate step's agent (`auto-validate`). |
| `model_push` | string | `haiku` | Model for the push step's agent (`auto-push`). |

**Where keys are read — precedence (highest first):**

1. An explicit arg, or a value in the orchestrator's grounding block (§2).
2. The **project** file: `.claude/ccmagic.local.md` at the repo root.
3. The **user** file: `~/.claude/ccmagic.local.md` (personal defaults across every project).
4. The built-in default listed above.

A project file overrides the user file, which overrides the built-in default. This lets a solo dev set, say, a longer `ci_timeout_minutes` or `autonomous: true` once in `~/.claude/ccmagic.local.md` and still override it per-repo. The user file is optional — nothing changes until it exists.

## 6. Invariants

- **Autonomous is additive.** Interactive behavior is never changed; every autonomous default is gated behind the signal above.
- **Every decision is recorded** in the PR body/comments and/or a ticket comment, so an unattended run leaves an audit trail.
- **Every exit is either `merged` or `parked-needs-human` (with a reason).** Never `stalled`, never a silent hang, never a merge on a guess.
