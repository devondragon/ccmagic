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
merge_owner: {self | reeve}
merge_handoff_state: {value}
max_feedback_passes: {n}
review_pass: {n — only on Step 3 re-reviews; absent on the first review pass}
fix_pass: {n, only on a fix pass of the work step (Step 3 or 4b); absent otherwise}
fix_source: {review | validate, only with fix_pass}
```

`merge_owner` and `merge_handoff_state` come from config (§5) with defaults `self` and `Awaiting Merge`; only `finish-ticket` acts on them.

The block always carries the ticket content, on every transport. The orchestrator fetches the ticket once in its Step 0 (under prompt-relay it takes the content from the invocation instead, §7) and appends a `ticket_content:` section:

```
ticket_content:
~~~
{title}

{description, as written}

{acceptance criteria, as written, when the tracker keeps them in a separate field}
~~~
```

The `~~~` fence is deliberate — issue bodies routinely contain backtick fences, so tildes keep the ticket body from prematurely closing the block. Copy the text as written; do not summarize it, because the step agents parse acceptance criteria out of it. Sub-skills in an orchestrated run read the ticket from this section **instead of** fetching it (§8).

`review_pass:` appears only when the orchestrator re-invokes `review-ticket` inside its Step 3 fix loop (2 on the first re-review, incrementing). `review-ticket` uses it to switch to a delta report (see its *Autonomous mode*); all other sub-skills ignore it. On those re-invocations the orchestrator also appends a `previous_findings:` section to the grounding block: a short fenced list of the findings the work step's fix pass just applied (its `applied_findings:`, id/title and file per finding), so the fresh review subagent knows exactly what to verify as fixed:

```
previous_findings:
~~~
- {id/title}: {file}
- {id/title}: {file}; invariant test: {test file and name}
~~~
```

The `invariant test:` suffix appears only for a security or invariant finding fixed under §9; the reviewer checks that the test states the invariant and passes, and does not re-derive the invariant from scratch. The list is the `applied_findings:` section the work step's fix pass reported (below), copied as reported.

**Fix passes.** The orchestrator never edits code. When a review returns `fixable-findings` (its Step 3) or local validation fails (its Step 4b), it runs the work step (`auto-work`) again as a **fix pass**: the grounding block carries `fix_pass:` and `fix_source:` and a `findings_to_fix:` section, and no `review_pass:` or `previous_findings:`:

```
findings_to_fix:
~~~
{review: each CRITICAL finding and fixable missing-AC item, copied from the review report as written,
 with its id, title, file and line, detail, systemic: enumeration, and Reproduction}
{validate: the validate step's failures: section as reported (§3)}
~~~
```

On a fix pass `work-ticket` skips its Steps 2 to 4 and follows its *Fix pass* section in place of Steps 5 to 8: it stays on the PR's branch, applies only the listed items (a `systemic:` finding as a class, a security or invariant finding under §9), runs the narrowest tests that cover them, and leaves the changes **uncommitted**. It does not re-implement the ticket, commit, push, or open a PR: the orchestrator's push step is the one commit and push of the pass, and it runs only after a `done`. All other sub-skills ignore the fix-pass keys. The orchestrator checks the git state around each fix pass (its Step 3, *Fix-pass git check*) and parks a pass that committed, switched branch, or changed no files.

The push step's grounding block after a fix pass may carry a `commit_notes:` section, copied from the fix pass's report (§3); only `push` reads it.

A sub-skill that sees `orchestrator:` in its grounding block must **not** park on `needs-human` — it emits the handshake and returns control so the orchestrator performs the single route-and-stop.

`auto-ticket` always runs each step in a per-step subagent (`agents/auto-*.md`) on the step's model, passing this grounding block as the child's task prompt and reading back the child's handshake (§3). The child agents preload their lifecycle skill rather than invoking it, so the step runs on the agent's model. The grounding block and handshake are unchanged by this — they're identical to how a directly-invoked sub-skill reads and emits them.

## 3. The status handshake

In autonomous mode, every sub-skill ends its output with a fenced block:

```
status: clean | fixable-findings | needs-human | done
reason: <one line, when not clean/done>
follow_ups: [<ticket ids or short descriptions of anything filed/deferred>]
requested_state: <intended tracker state: orchestrated runs (§8) and the prompt-relay transport; omit otherwise>
```

Which values each sub-skill can emit:

| Sub-skill | Emits |
|-----------|-------|
| `work-ticket` | `done` \| `needs-human` (on a fix pass, `done` means every listed item was applied and is uncommitted) |
| `review-ticket` | `clean` \| `fixable-findings` \| `needs-human` |
| `pr-feedback` | `done` \| `needs-human` |
| `validate` | `done` \| `needs-human` |
| `push` | `done` \| `needs-human` |
| `finish-ticket` | `done` \| `needs-human` (with `merge_owner: reeve`, `done` carries `reason: handed off to reeve; ...` and the PR is not merged) |

On a fix pass (§2) the work step's report carries an `applied_findings:` section and, when there is something to note, a `commit_notes:` section, both fenced and just **before** the handshake block, so the handshake stays last:

```
applied_findings:
~~~
- {id/title}: {file}
- {id/title}: {file}; invariant test: {test file and name}
~~~
commit_notes:
~~~
- {file}: {a line for the fix commit's body, such as a §9 corpus sampled down or an invariant derived from a finding with no inputs}
~~~
```

`applied_findings:` lists every item from `findings_to_fix:`, one line each, in the `previous_findings:` format; for a validate fix the id/title is the check name. The orchestrator copies it into the re-review's `previous_findings:` and treats a missing section, or a missing item, as a failed pass. `commit_notes:` is omitted when there is nothing to note. Each line starts with the repository file it concerns (for a §9 note, the invariant test). The orchestrator appends the section to the push step's grounding block, and `push` writes each line into the body of the commit that holds that file, or into the first commit's body when no commit holds it, so no note is dropped. The fix pass's handshake is `status: done | needs-human`, `reason: fix pass {n} ({fix_source}): applied {k} items` (or on `needs-human`, the item it could not fix; for a §9 fix that still fails, the finding and the first failing input), and `follow_ups:`, with no `requested_state:`.

When a check fails, the validate step's report carries a `failures:` section just before its handshake, and its `reason` starts with `failed:`. The orchestrator copies the section into a validate fix pass's `findings_to_fix:`:

```
failures:
~~~
- {check}: `{command}`, exit {exit_code}{, timed out}; log: {log path}
  {the lines of the check's tail that show the cause, indented}
~~~
```

Parse the **last** such block in the sub-skill's output. If a sub-skill fails to emit one (crash, tool error), treat it as `needs-human` with `reason: "{skill} produced no handshake"`.

The plugin's SubagentStop hook (`hooks/subagent-stop-handshake.sh`) enforces this on the `ccmagic:auto-*` step agents: a final message without a valid block (a `status:` value allowed for that step, then `reason:` and `follow_ups:`, with nothing after) sends the agent back once to add it. A second miss is let through, and the rule above applies.

**Delivering the handshake from a step agent.** Some harnesses deliver a background subagent's report through a `SubagentHandback` tool call, and the caller then sees only that call's `message`, not the agent's final text. So a step agent:

- ends its final report with the handshake block, with nothing after it;
- when it delivers the report with `SubagentHandback`, puts the full report, ending with the handshake, in `message` (never an empty `message`), and then ends its final text with the same handshake, which is what the hook checks;
- never writes tool-call tags such as `<SubagentHandback>` as text;
- runs helper agents in the foreground, or keeps waiting for background ones, rather than ending its turn to wait for them (the hook fires on every stop).

In an orchestrated run (§8) a sub-skill that would have transitioned ticket state reports the intended state in `requested_state:`, and the orchestrator applies it after the step returns. Under the prompt-relay transport the orchestrator cannot apply it either, so it folds it into its final relayed summary as an intent line `Requested state: {X}` (§7 `set_state`).

## 4. Route-and-stop (park the ticket)

The single routine the orchestrator (or a standalone top-level sub-skill) runs whenever an outcome is `needs-human`, the feedback-pass cap is hit still-not-clean, or CI/validation can't be made green within bounds. **Never merge in this path.**

1. **Do not merge.** Leave the PR open.
2. **Move the ticket to `needs_human_state`:**
   - **Linear** — `mcp__*Linear*__save_issue` transitioning to the state whose name matches `needs_human_state` (case-insensitive). If no such state exists, apply `needs_human_label` via `save_issue` labels and leave the state unchanged.
   - **GitHub** — GitHub issues have no custom states. Apply `needs_human_label` with `gh issue edit {N} --add-label "{label}"` (create the label first with `gh label create` if missing). Leave the issue open.
   - **JIRA** — transition to the matching status via the Atlassian MCP; if no transition matches, apply `needs_human_label` as a label and leave the status unchanged.
3. **List uncommitted changes.** Run `git status --porcelain`. A non-empty result is work that was not pushed, such as a fix pass that failed; it goes in the parked comment's **Uncommitted changes** line so a human reviews it before anything re-runs. Leave the files as they are.
4. **Comment the reason** on both surfaces (skip a surface only if it doesn't exist):
   - PR comment (`gh pr comment {PR} --body ...`) and ticket comment (`save_comment` / `gh issue comment` / Atlassian MCP), using the parked-comment template below.
5. **Emit the run's final status** (see the orchestrator's Step 6 summary) and exit cleanly. Never wait for input.

### Parked-comment template

````markdown
## 🅿️ Autonomous run summary for {TICKET-ID} (parked for a human)

`/ccmagic:auto-ticket` stopped this run because it needs a human decision.

**Waiting on:** {the one-line reason from the sub-skill's handshake}
**Stage:** {work-ticket | review-ticket | pr-feedback | validate | finish-ticket}
**PR:** {pr_url or "not created"}
**Uncommitted changes:** {the files from step 3, with "left in the working tree, not pushed; review or discard them before re-running"; omit this line when the tree is clean}
**State moved to:** {needs_human_state, or "unchanged — applied label `{needs_human_label}`" | prompt-relay: "not moved — Requested state: {needs_human_state}"}

**Autonomous decisions so far:**
{bullet list — classification, minor choices made, drift flagged}

**Follow-ups:** {filed ticket ids with one-liners; items not filed with the reason; under prompt-relay, "to file:" short descriptions; or "none"}

### Run record
```json
{"ccmagic": {"version": 1, "run_id": "{run_id}", "ticket": "{TICKET-ID}", "outcome": "parked", "classification": "{class}", "merge_owner": "{self | reeve}", "pr": {pr_number or null}, "review_passes": {n}, "feedback_passes": {n}, "ci_attempts": {n}, "findings": {"critical": {n}, "high": {n}}, "steps": [{"step": "work-ticket", "status": "done"}, {"step": "review-ticket", "status": "needs-human", "reason": "{one line}"}], "follow_ups": []}}
```

Nothing was merged. Resolve the item above (and any uncommitted changes), then re-run `/ccmagic:auto-ticket {TICKET-ID}` (or continue manually).
````

The keys and rules are the same as the Step 6 `### Run record` block (contract §2's grounding block feeds `merge_owner`; see `skills/auto-ticket/SKILL.md` Step 6). This block is what lets Reeve's `parseRunRecord` read a parked run: it matches on a comment containing "Autonomous run summary" and reads that comment's final ```json fence, so the heading above must keep that exact phrase.

### Under the prompt-relay transport

When the run is on the **prompt-relay transport** (§7), the park routine changes at two points, and the parked-comment template above renders its **State moved to** and **Follow-ups** lines per their prompt-relay alternatives:

- **Step 2 (state move) is skipped.** There is no Linear API in the environment, so the ticket state is not moved — the harness/human owns the transition. A park that can't move state is **never** a failure. Emit `Requested state: {needs_human_state}` as an intent line in the final output so the tracker (and the human reading the relay) knows where the ticket should go.
- **Step 4 (comment)** still posts the parked-comment template to the **PR** via `gh pr comment` (the GitHub side is intact). It is *additionally* emitted as the orchestrator's final top-level output, wrapped in the §7 final-message delimiters, so the relay delivers the parked note to the tracker as the run's single Linear-facing message.

## 5. Config keys

| Key | Type | Default | Meaning |
|-----|------|---------|---------|
| `autonomous` | bool | `false` | Default mode when no `--autonomous` flag and no grounding block is passed. |
| `needs_human_state` | string | *(none)* | Tracker state a parked ticket is moved to (e.g. `Blocked`, `Needs Human`). |
| `needs_human_label` | string | `needs-human` | Fallback label applied when `needs_human_state` doesn't exist (and always on GitHub). |
| `merge_owner` | string | `self` | Who owns merging the PR: `self` merges here, `reeve` hands off to an external merge gate instead of merging. |
| `merge_handoff_state` | string | `Awaiting Merge` | Tracker state a handed-off ticket moves to when `merge_owner: reeve`. |
| `max_feedback_passes` | int | `3` | Cap on the `pr-feedback` loop (orchestrator Step 4) before parking. |
| `max_review_fix_passes` | int | `3` | Cap on the ticket-review fix loop (orchestrator Step 3) before parking. |
| `max_validate_attempts` | int | `2` | Cap on local `/ccmagic:validate` fix attempts (orchestrator Step 4b) before parking. |
| `ci_timeout_minutes` | int | `30` | Max minutes to wait for CI to settle (orchestrator Step 4c) before parking on timeout; quantized up to whole 10-minute watch cycles (`CYCLES = ceil(minutes / 10)`). |
| `ci_poll_interval_seconds` | int | `60` | Interval passed to `gh pr checks --watch` during the CI wait (orchestrator Step 4c); when the Checks API is unreadable (fine-grained PAT 403), the wait falls back to the Actions/Status APIs (Step 4c item 5) and this interval no longer applies. |
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
- **Every exit is `merged`, `handed-off` (only with `merge_owner: reeve`), or `parked-needs-human` (with a reason).** Never `stalled`, never a silent hang, never a merge on a guess.

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

## 8. Tracker access in orchestrated runs

In an **orchestrated** run (the grounding block carries `orchestrator: auto-ticket`) the orchestrator is the only part of the run that reads or writes the tracker, on every transport. Step agents list only built-in tools, so tracker MCP tools do not reach them; they must not work around that by spawning helper agents to fetch or update the ticket, or by calling a tracker API or CLI themselves. A step agent and every sub-skill it runs apply the §7 operations table as if the transport were prompt-relay, with these specifics:

| Op | Orchestrated step behavior | The orchestrator then |
|---|---|---|
| `fetch_ticket(id)` | Read the title, description, and acceptance criteria from the grounding block's `ticket_content:` (§2). If it is missing, emit `needs-human` with `reason: grounding block has no ticket_content` (never guess, never fetch). | Nothing: it fetched the ticket in Step 0. |
| `set_state(In Progress)` | Skip. | Assigns the ticket and moves it to In Progress in Step 0. |
| `set_state(In Review \| Done \| merge_handoff_state)` | Report it in the handshake's `requested_state:`. | Applies it after the step returns (mcp), or relays it as `Requested state:` (prompt-relay). |
| `comment(ticket, body)` | Skip. Put anything the ticket should carry (for example finish-ticket's closing or hand-off comment) in the step's final report. | Posts its run summary to the ticket in Step 6 (mcp). |
| `link_pr(url)` | Skip; the PR URL is in the handshake's `reason` (work-ticket). | Links the PR to the ticket after the work step (mcp). |
| `file_followup(desc)` | Record a short description in `follow_ups:`; reply to a deferred PR thread with `ccm-pr-reply ... --ticket requested`. | Files it or lists it with a reason (its *Follow-ups* rule). |

Needs-human parking is already the orchestrator's (§4). Comments on the PR (`gh pr comment`, `ccm-post-review`, `ccm-pr-reply`) are not tracker writes and stay in the steps. A sub-skill invoked without a grounding block (interactive or standalone autonomous) keeps its full tracker behavior; this section changes nothing there.

## 9. Fixing security and invariant findings

This applies wherever an autonomous run fixes a finding: the work step's fix pass in the review-fix loop (`auto-ticket` Step 3, run by `auto-work`, §2) and `pr-feedback`'s address-now fixes (the `auto-feedback` step). It covers a finding tagged security (`specialist: security`, or a review comment that reports a vulnerability) and any finding whose correctness depends on an invariant over untrusted input, such as "no filename can produce the fence marker". A few hand-picked cases do not show such a fix is complete, and every gap the next review pass finds costs a full fix, push, and review cycle. So before committing the fix:

1. **Reproduce the verifier's inputs.** Take the triggering inputs from the finding's `reproduction:` field (`skills/review/finding-schema.md`; the review report shows it as **Reproduction**), or from its detail or the review comment when the field is absent. Run each one against the fixed code in a scratch program kept outside the repository (for example under `$TMPDIR`), so it is never committed. Every input must now satisfy the invariant.
2. **Rerun the corpus.** If the verifier fuzzed or enumerated, rebuild that corpus from its stated generator or rule and run it against the fix. Keep it within the scratch-program limits in `skills/review/agent-instructions.md`: a hard timeout of about 60 seconds (`timeout -k 5 60 ...`, or `gtimeout -k 5 60 ...` on macOS where GNU `timeout` is missing) and the smallest corpus that exercises the behavior. If the verifier's corpus does not fit, sample it down and say so in the commit body (on a fix pass, in `commit_notes:`, §3, which the push step writes there). The result is zero failures, or the first failing input.
3. **State the invariant as a test.** Add a property or parameterized test to the repository that asserts the invariant over the verifier's inputs plus a generated or enumerated set, using the project's existing test framework (a property-testing library only if the project already uses one). Run it with the project's normal targeted test command; the 60-second limit is for scratch programs, not the project's test runner, which can take longer than that on a JVM build. The fix commit includes the test, so the next review pass checks the invariant instead of rediscovering it.
4. **Do not push a fix that fails.** If any verifier input or corpus input still breaks the invariant, keep fixing within the pass. If the fix cannot be made to pass, do not commit or push it as fixed: the fix pass emits `needs-human` and the orchestrator route-and-stops (§4) without running the push step, and `pr-feedback` does not reply `fixed` and emits `needs-human`. Either way the reason names the finding and the first failing input, written in its escaped form (as in `reproduction:`) so the handshake `reason:` stays on one line.

When a finding carries no inputs, derive the invariant and inputs from its detail, and name both in the commit body (on a fix pass, in `commit_notes:`). This section changes nothing for other findings.
