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

The orchestrator prepends this block to the arguments of **every** sub-skill invocation. Sub-skills read `autonomous: true` to switch modes, and may reuse `tracker` / `transport` / `ticket` to skip re-resolution:

```
AUTONOMOUS RUN CONTEXT
autonomous: true
orchestrator: auto-ticket
run_id: {short id}
tracker: {linear | github | jira}
transport: {mcp | prompt-relay}
ticket: {TICKET-ID}
ticket_url: {url}
pr: {PR number/url, once known}
base_branch: {base}
needs_human_state: {value}
needs_human_label: {value}
max_feedback_passes: {n}
review_pass: {n — only on Step 3 re-reviews; absent on the first review pass}
```

Under the **prompt-relay transport** (§7) the block also carries the ticket content, because no tracker MCP is available to fetch it. The orchestrator appends a `ticket_content:` section:

```
ticket_content:
~~~
{title}

{description}
~~~
```

The `~~~` fence is deliberate — issue bodies routinely contain backtick fences, so tildes keep the ticket body from prematurely closing the block. Under prompt-relay, sub-skills read the ticket's title and description from this section **instead of** calling the Linear MCP.

`review_pass:` appears only when the orchestrator re-invokes `review-ticket` inside its Step 3 fix loop (2 on the first re-review, incrementing). `review-ticket` uses it to switch to a delta report (see its *Autonomous mode*); all other sub-skills ignore it. On those re-invocations the orchestrator also appends a `previous_findings:` section to the grounding block — a short fenced list of the findings it just applied in the fix loop (id/title + file per finding) — so the fresh review subagent knows exactly what to verify as fixed:

```
previous_findings:
~~~
- {id/title} — {file}
- {id/title} — {file}
~~~
```

A sub-skill that sees `orchestrator:` in its grounding block must **not** park on `needs-human` — it emits the handshake and returns control so the orchestrator performs the single route-and-stop.

`auto-ticket` always runs each step in a per-step subagent (`agents/auto-*.md`) on the step's model, passing this grounding block as the child's task prompt and reading back the child's handshake (§3). The child agents preload their lifecycle skill rather than invoking it, so the step runs on the agent's model. The grounding block and handshake are unchanged by this — they're identical to how a directly-invoked sub-skill reads and emits them.

## 3. The status handshake

In autonomous mode, every sub-skill ends its output with a fenced block:

```
status: clean | fixable-findings | needs-human | done
reason: <one line, when not clean/done>
follow_ups: [<ticket ids or short descriptions of anything filed/deferred>]
requested_state: <intended tracker state — prompt-relay transport only; omit otherwise>
```

Which values each sub-skill can emit:

| Sub-skill | Emits |
|-----------|-------|
| `work-ticket` | `done` \| `needs-human` |
| `review-ticket` | `clean` \| `fixable-findings` \| `needs-human` |
| `pr-feedback` | `done` \| `needs-human` |
| `validate` | `done` \| `needs-human` |
| `push` | `done` \| `needs-human` |
| `finish-ticket` | `done` \| `needs-human` |

Parse the **last** such block in the sub-skill's output. If a sub-skill fails to emit one (crash, tool error), treat it as `needs-human` with `reason: "{skill} produced no handshake"`.

Under the prompt-relay transport, a sub-skill that would have transitioned ticket state reports the intended state in `requested_state:` (per §7 `set_state`); the orchestrator folds it into its final relayed summary as an intent line `Requested state: {X}`.

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
**Stage:** {work-ticket | review-ticket | pr-feedback | validate | finish-ticket}
**PR:** {pr_url or "not created"}
**State moved to:** {needs_human_state, or "unchanged — applied label `{needs_human_label}`" | prompt-relay: "not moved — Requested state: {needs_human_state}"}

**Autonomous decisions so far:**
{bullet list — classification, minor choices made, drift flagged}

**Follow-ups {filed | to file (prompt-relay)}:** {ticket ids or short descriptions, or "none"}

Nothing was merged. Resolve the item above, then re-run `/ccmagic:auto-ticket {TICKET-ID}` (or continue manually).
```

### Under the prompt-relay transport

When the run is on the **prompt-relay transport** (§7), the park routine changes at two points, and the parked-comment template above renders its **State moved to** and **Follow-ups** lines per their prompt-relay alternatives:

- **Step 2 (state move) is skipped.** There is no Linear API in the environment, so the ticket state is not moved — the harness/human owns the transition. A park that can't move state is **never** a failure. Emit `Requested state: {needs_human_state}` as an intent line in the final output so the tracker (and the human reading the relay) knows where the ticket should go.
- **Step 3 (comment)** still posts the parked-comment template to the **PR** via `gh pr comment` (the GitHub side is intact). It is *additionally* emitted as the orchestrator's final top-level output, wrapped in the §7 final-message delimiters, so the relay delivers the parked note to the tracker as the run's single Linear-facing message.

## 5. Config keys

| Key | Type | Default | Meaning |
|-----|------|---------|---------|
| `autonomous` | bool | `false` | Default mode when no `--autonomous` flag and no grounding block is passed. |
| `needs_human_state` | string | *(none)* | Tracker state a parked ticket is moved to (e.g. `Blocked`, `Needs Human`). |
| `needs_human_label` | string | `needs-human` | Fallback label applied when `needs_human_state` doesn't exist (and always on GitHub). |
| `max_feedback_passes` | int | `3` | Cap on the `pr-feedback` loop (orchestrator Step 4) before parking. |
| `max_review_fix_passes` | int | `3` | Cap on the ticket-review fix loop (orchestrator Step 3) before parking. |
| `max_validate_attempts` | int | `2` | Cap on local `/ccmagic:validate` fix attempts (orchestrator Step 4b) before parking. |
| `ci_timeout_minutes` | int | `30` | Max minutes to wait for CI to settle (orchestrator Step 4c) before parking on timeout; quantized up to whole 10-minute watch cycles (`CYCLES = ceil(minutes / 10)`). |
| `ci_poll_interval_seconds` | int | `60` | Interval passed to `gh pr checks --watch` during the CI wait (orchestrator Step 4c). |
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

## 7. Prompt-relay transport

A **transport** is *how* a tracker is reached, independent of *which* tracker it is. The default transport is `mcp` — Linear/JIRA via their MCP, GitHub via `gh` — and every skill behaves exactly as documented in §1–§6. The **prompt-relay** transport covers headless-harness runs where the tracker is Linear but **no Linear MCP exists in the environment**: the harness injects the ticket into the prompt, the agent works the cycle, and the harness relays the session's final output back to the tracker as a comment. Reads arrive with the invocation; writes leave as the single relayed message. The GitHub/PR half of the cycle (`gh` for PR, push, merge, CI) is untouched.

### Detection

transport = `prompt-relay` when ALL of: (a) the tracker resolves to `linear`; (b) **no Linear MCP server is available to the session** (definition below); (c) ticket content (title + description) was explicitly provided in the invocation arguments or grounding block. Otherwise transport = `mcp`. The check runs *before* any "none available → stop" branch. Content-presence (c) is a *transport* signal, not a tracker tiebreaker — condition (a) still resolves the tracker via config or the detection cascade, so a headless deployment with no MCP should pin `tracker: linear` (or a Linear-shaped `ticket_url_base:`) to keep (a) deterministic.

**A Linear MCP server is "available"** if ANY of these hold (the pattern is **case-insensitive** — Cyrus registers its server lowercase as `mcp__linear__*`):

1. a `mcp__*[Ll]inear*__*` tool (e.g. `mcp__linear__get_issue`, `mcp__claude_ai_Linear__get_issue`) is directly callable; or
2. `mcp__*[Ll]inear*__*` tool names appear in the session's deferred / loadable tool list (discoverable via `ToolSearch`); or
3. the session reports a Linear MCP server that is registered but **still connecting** (e.g. a system-reminder naming a `linear` server as connecting).

A registered-but-connecting server (signals 2–3) is **present, not absent** — do not fall to prompt-relay on the strength of a tool not being *immediately* callable.

**Loading the tools (bounded, non-blocking).** When a Linear MCP server is present but its tools are not yet callable in *this* context, make a bounded attempt to load them: run `ToolSearch` for `mcp__*linear*__get_issue` (plus the other tools the step needs) 2–3 times. If they resolve, `transport = mcp`. If they do not, **do not block or sleep waiting** — on Cyrus the server connects in well under a second, but its tools populate the deferred-tool index on a **per-context lag**: a forked sub-skill frequently cannot see tools the top-level session already has, and a short wait does not reliably bridge that gap. Fall through to `prompt-relay`, which must **always** be viable because the run's ticket content travels with the invocation (see §2 — inline `ticket_content:` or the working-directory handoff file). If neither the MCP tools nor injected content is available, stop with the §7 `fetch_ticket` setup-error (never hang, never guess). When the tools are immediately callable (e.g. a laptop's always-on connector) the first attempt resolves.

### Operations

Each tracker-I/O step in the lifecycle skills carries a one-line "in prompt-relay transport, see contract §7" pointer to this table instead of a duplicated branch:

| Op | Prompt-relay behavior |
|---|---|
| `fetch_ticket(id)` | Read the title + description from the invocation arguments / grounding block's `ticket_content:` section (§2), or — for a forked orchestrator whose parent injected the content — from a `.ccmagic-ticket.md` handoff file in the working directory (read it, then `rm` it so it is never committed). Absent from all → **setup error, stop and say so** — never guess, never park (the caller should have injected it). |
| `set_state(In Progress)` | No-op — the harness already moved the ticket to "started" on assignment. |
| `set_state(In Review \| Done \| needs_human)` | No-op at the API level; report the intended state via the handshake's `requested_state:` field (§3), and the orchestrator emits `Requested state: {X}` as an intent line in the final message. The harness lifecycle / tracker automation owns the actual move. Never a failure or a park trigger. |
| `comment(ticket, body)` | **Skip.** No accumulation machinery — the PR carries the detailed audit trail via `gh`, and the orchestrator's single Step 6 summary is the only Linear-facing message. |
| `link_pr(url)` | Include the PR URL in the final summary. Linear's GitHub integration auto-links the PR via the issue-id branch name anyway; there is no attachment API. |
| `file_followup(desc)` | No create API — record the item as a short description in `follow_ups:` (§3) and list it under "Follow-ups to file" in the final summary for a human. |

### Final message

Under prompt-relay the orchestrator's Step 6 summary (or parked note) is emitted as its own final top-level output, ending with a delimited block opened by the exact line `=== FINAL MESSAGE TO RELAY (reproduce verbatim) ===` and closed by `=== END FINAL MESSAGE ===`:

```
=== FINAL MESSAGE TO RELAY (reproduce verbatim) ===
{the Step 6 run summary or parked note}
=== END FINAL MESSAGE ===
```

Only the top-level session's output reaches the tracker — per-step subagent output stays internal — and the harness's main-loop model may **paraphrase** the forked skill's return before relaying it. The delimited block above, together with the deployment-side prompt instruction to *repeat the returned final message verbatim*, is the mitigation: the two together keep the relayed comment faithful to what the orchestrator produced.

### Scope

This transport adds no config keys and changes nothing when an MCP is present — it is a purely additive branch, gated on the detection rule above.
