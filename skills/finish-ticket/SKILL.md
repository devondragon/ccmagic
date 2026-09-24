---
name: finish-ticket
description: Closes out a development ticket end-to-end. Detects the tracker (Linear, GitHub Issues, or JIRA) and the ticket from the current branch, sanity-checks the PR, confirms disposition (Done by default, or QA when configured/requested), merges the PR, and updates the ticket with a comment, PR link, and final status.
user-invocable: true
allowed-tools: Read(*), Edit(*), Bash(git:*, gh:*), Bash(${CLAUDE_SKILL_DIR}/../../bin/ccm-context *), Bash(${CLAUDE_SKILL_DIR}/../../bin/ccm-merge-gate *), Bash(${CLAUDE_SKILL_DIR}/../../bin/ccm-ci-status *), Glob(*), Grep(*), AskUserQuestion(*), Skill(*)
argument-hint: "[--qa]"
model: sonnet
---

# /finish-ticket — Close Out a Development Ticket

Given the current branch, finishes a ticket end-to-end: sanity-checks the PR, confirms the right disposition, merges, and updates the ticket. Works with Linear, GitHub Issues, or JIRA.

**On invocation, announce:** "I'll resolve the tracker, detect the ticket from this branch, sanity-check the PR, recommend a disposition (Done unless QA is configured), merge after your confirmation, and update the ticket."

## Sacred Rule: Never Guess Ticket Content

**If the ticket cannot be found, stop and tell the user. Do not infer, guess, or fabricate what the ticket might contain.** The ticket system is the source of truth.

---

## Step 0: Load project settings & resolve tracker

### 0a. Load settings

If `.claude/ccmagic.local.md` exists at the repo root (`git rev-parse --show-toplevel`), read its YAML frontmatter; also read the user-level `~/.claude/ccmagic.local.md` if present, with the project file taking precedence over the user file (both override built-in defaults). Relevant keys:

- `tracker:` — `linear` | `github` | `jira` | `auto` (default `auto`)
- `ticket_url_base:` — for display links
- `ticket_id_regex:` — defaults to `[A-Z][A-Z0-9]+-[0-9]+`
- `github_repo:` — `owner/repo` (only used when tracker is GitHub)
- `default_qa_workflow:` — if `true`, the QA path is on by default
- `merge_owner:` — `self` (default) | `reeve`. With `reeve`, this repo's merges belong to an external gate (Reeve). The autonomous path hands the PR off instead of merging (see *Autonomous mode → Merge hand-off*); the interactive path offers the hand-off at Step 5.
- `merge_handoff_state:` — tracker state a handed-off ticket moves to. Default `Awaiting Merge`. Linear and JIRA only; on GitHub Issues the hand-off applies the label `awaiting-merge` instead.

The `--qa` argument always forces the QA path regardless of config.

### 0b. Resolve tracker (cascade — runs when `tracker: auto` or unset)

1. **Branch hint:** parse the current branch for a ticket ID. Integer-only (e.g. `bugfix/42-...`) suggests GitHub; `[A-Z][A-Z0-9]+-[0-9]+` suggests Linear or JIRA.
2. **MCP probe:** check available tools.
   - Linear MCP: a server available to the session — case-insensitive `mcp__*[Ll]inear*__get_issue` (incl. Cyrus's `mcp__linear__` and a still-connecting server; see contract §7).
   - Atlassian/JIRA MCP: any tool matching `mcp__*atlassian*__*` or `mcp__*Atlassian*__*`.
   - Prefer Linear unless `ticket_url_base` looks JIRA-shaped (`*.atlassian.net`).
3. **CLI probe:** `command -v gh && gh repo view --json nameWithOwner 2>/dev/null` — GitHub candidate.
4. **Ambiguous:** ask the user via `AskUserQuestion`. Offer to write the choice to `.claude/ccmagic.local.md`.
5. **Prompt-relay fallback:** if the contract §7 detection rule matches (`skills/auto-ticket/autonomous-contract.md` §7), resolve `tracker: linear` with `transport: prompt-relay` instead of stopping — do not fall through to item 6.
6. **None available:** stop. Tell the user to install one or set `tracker:` in `.claude/ccmagic.local.md`.

Record the resolved tracker and transport (`mcp` or `prompt-relay`) for use in steps 2 and 7.

Transport resolution depends on how this skill was invoked. **When invoked with a grounding block that carries a `transport:` value (orchestrated/autonomous runs — contract §2), trust that value and do not re-detect** — the orchestrator resolved transport once for the whole run, so every sub-step stays consistent. **Only when running standalone (no grounding block)** do you resolve transport yourself: whenever the tracker is `linear` — pinned in config or detected via the cascade — apply the contract §7 detection rule (`skills/auto-ticket/autonomous-contract.md` §7, including its server-availability rule and load-with-retry) to set `transport: mcp | prompt-relay`. A pinned `tracker:` skips the cascade above, never standalone transport resolution.

---

## Step 1: Detect the Ticket ID and PR

### Branch

Run:
```bash
"${CLAUDE_SKILL_DIR}/../../bin/ccm-context"
```

It prints JSON with the current `branch`, the `ticket_id` parsed from it with `ticket_id_regex` (or an integer segment for GitHub), the open `pr`, whether this is a linked `worktree`, and the resolved `config`. Use those values; do not re-parse the branch yourself. Examples of what it extracts:

- `feature/ENG-123-add-search` → `ENG-123` (Linear/JIRA)
- `bugfix/PROJ-456-fix-cart` → `PROJ-456` (Linear/JIRA)
- `bugfix/42-fix-cart-total` → `42` (GitHub)

The `ccm-*` scripts are also on the Bash `PATH` while the plugin is enabled. If the `${CLAUDE_SKILL_DIR}/../../bin/` path doesn't resolve (for example, the variable wasn't expanded), call them by bare name: `ccm-context`, `ccm-merge-gate`, `ccm-ci-status`.

If `ticket_id` is null, ask the user:

> "I couldn't detect a ticket ID from the current branch (`{branch-name}`). What is the ticket ID?"

### PR

Run:
```bash
gh pr view --json number,title,body,state,url,baseRefName,headRefName
```

(`statusCheckRollup` is deliberately not requested: a fine-grained PAT gets HTTP 403 on it, which would fail the PR lookup itself. CI is read by the merge gate in Step 3.)

If no PR exists for this branch, stop and tell the user:

> "No open pull request found for branch `{branch-name}`. Please create a PR first (`/ccmagic:pr`), then run `/ccmagic:finish-ticket` again."

Do not proceed without an open PR.

---

## Step 2: Look Up the Ticket

### Linear

Use the available Linear MCP tool (e.g. `mcp__claude_ai_Linear__get_issue`). Extract `title`, `description`, `state.name`, `assignee`, `priority`, `labels`, `url`. Linear states are workflow-defined per team — fetch the full state list so you can match QA/Done targets in Step 7.

**Under prompt-relay** (contract §7), **or when orchestrated** (`orchestrator:` in the grounding block, contract §8, any tracker and transport): skip the fetch and take `title` and `description` from the grounding block's `ticket_content:` section (contract §2). Fetch no state list; Step 7 reports a `requested_state:` instead of matching state names. If the section is absent, stop with the setup-error message per contract §7 `fetch_ticket` (orchestrated: emit `needs-human` per contract §8); never guess, and never spawn a helper to fetch it. The "If not found" stop text below applies only to the MCP path.

### GitHub

```bash
gh issue view {N} --repo {github_repo or auto-detected} --json title,body,state,assignees,labels,url
```

Extract `title`, `body` (description), `state`, `assignees`, `labels`, `url`. GitHub issues only have `OPEN` and `CLOSED` — there is no "QA" state. The Done path closes the issue; the QA path applies a label if configured (see Step 7).

### JIRA

Use the available Atlassian MCP tools to fetch the issue. Extract `summary`, `description`, `status.name`, `assignee`, `issuetype.name`, `project.key`, URL `{ticket_url_base}/{TICKET-ID}`. Also fetch available transitions so you can find the right "QA" or "Done" transition IDs in Step 7.

### If not found

Stop. Tell the user:

> "I could not find ticket `{TICKET-ID}` in {tracker}. Please verify the ticket ID and confirm the tracker integration is connected."

---

## Step 3: Sanity Check

### 3a–3c. Merge gate (PR state, CI, reviews)

Run the merge gate. It decides these three criteria in code, so do not re-derive them from `gh` output:

```bash
"${CLAUDE_SKILL_DIR}/../../bin/ccm-merge-gate" {pr_number}
```

It exits 0 when the PR may merge and 1 when it may not, and prints JSON:

- `blockers`: each reason the PR can't merge. It covers: the PR isn't `OPEN`; it is `CONFLICTING`, or GitHub still reports `UNKNOWN` mergeability after a few re-reads; CI isn't green; a reviewer's latest review is `CHANGES_REQUESTED`.
- `warnings`: currently only "no approving review". A PR can proceed without an approval; show the warning.
- `ci`: the full `ccm-ci-status` result. `ci.status` is `green`, `no-ci` (no workflows and no required checks), `failed`, `pending`, `not-registered` (CI configured but nothing has reported for this commit yet), or `unreadable`. `ci.checks` lists each check with its bucket, for the report. The script already falls back to the Actions and commit-status APIs when a fine-grained PAT gets HTTP 403 on check runs, so a 403 is never on its own a reason to call CI failed or to ask anyone to look at the checks.

If `ci.status` is `pending` or `not-registered`, wait for CI rather than reporting it as a blocker yet:

```bash
"${CLAUDE_SKILL_DIR}/../../bin/ccm-ci-status" {pr_number} --watch --wait-key finish-{pr_number}
```

Each call returns within ten minutes. If it returns `"call_again": true`, run the same command again; the total wait is bounded by `ci_timeout_minutes` through the wait-key's deadline file, so you don't count anything. Once it settles, re-run `ccm-merge-gate`. A final `timeout` status is a blocker.

The `PreToolUse` hook enforces the same gate: in an autonomous run, `gh pr merge` is denied while `ccm-merge-gate` fails. Interactively the hook only enforces the gate when `merge_guard: on` is set; see Step 6.

### 3d. Scope Alignment
Run:
```bash
git log --oneline {baseRefName}...HEAD
git diff {baseRefName}...HEAD --stat
```

Compare the commit history and file changes against the ticket title and description. Briefly assess whether the work looks complete relative to the ticket scope. Look for obvious gaps (e.g., ticket mentions a UI change but only backend files changed), scope creep (many unrelated files changed), and incomplete implementation signals (TODO comments, skipped tests, WIP commits).

### 3e. Report

Present the sanity check results in this format:

```
## Sanity Check: {TICKET-ID} — "{ticket title}"

PR:        #{pr_number} — "{pr_title}"
PR URL:    {pr_url}
Base:      {baseRefName}
Status:    {OPEN / MERGED / CLOSED}
Mergeable: {YES / NO — conflicts detected / UNKNOWN}

CI Checks:
  PASS  {check name}
  FAIL  {check name} — {failure reason}
  WAIT  {check name} — pending

Reviews:
  Approved by {reviewer}
  No approvals yet
  Changes requested by {reviewer}

Scope:
  {2-3 sentences summarizing whether the changes appear to match the ticket}
```

**If there are critical blockers** (PR not mergeable, CI failing, changes requested), present them clearly and ask:

> "The following issues need attention before merging: {list}. Do you want to address these now, or proceed anyway?"

Wait for the user's decision. If they want to address issues, pause here and help them fix the blockers.

---

## Step 4: Determine Disposition

**Default: Done.** The QA path is opt-in.

The QA path is selected when **any** of these are true:
- The user passed `--qa` as an argument.
- `default_qa_workflow: true` is set in `.claude/ccmagic.local.md`.
- The user explicitly asks for QA in this session.

If none of these are true, **go directly to Done** — don't ask, don't recommend QA, don't try to find a QA assignee.

**If `merge_owner: reeve`:** the disposition question does not apply. Reeve owns the merge, so the ticket moves to `merge_handoff_state` at Step 7 and any QA happens after Reeve's merge, outside this skill. Skip the QA path and its assignee lookup and go to Step 5. If `--qa` was passed together with `merge_owner: reeve`, say the two conflict and ask whether to `merge here anyway` (QA path as normal) or `hand off` (QA deferred; no QA assignee is set here). Absent the key, this paragraph does not apply.

### When the QA path is selected

Form a brief recommendation, then ask:

> "Should I move `{TICKET-ID}` to **{recommended QA status}** after merging? (yes / no — go straight to Done / custom status name)"

Wait for the answer.

#### Finding the QA assignee (QA path only)

Try to identify who should do QA from the tracker:

- **Linear:** use the user-list MCP tool to find anyone with a QA-related role or membership.
- **GitHub:** check `CODEOWNERS` for a QA group, or fall back to asking.
- **JIRA:** use the Atlassian user-listing tool to find QA-labeled users.

If automated lookup fails, ask the user directly:

> "Who should I assign for QA? Please provide a name or email/handle."

Wait for the user's answer before proceeding.

### When the Done path is selected

Skip QA assignee lookup entirely. Move on to confirmation.

---

## Step 5: Confirm with the User

First, **determine the merge strategy** so the confirmation reflects what will actually happen:
- **Feature and bugfix branches** (`feature/...`, `bugfix/...`, `hotfix/...`, `chore/...`) → squash merge (`--squash`).
- **Release branches** (`release/...`) → merge commit (`--merge`).

**If `merge_owner: reeve`:** the default action is a hand-off, not a merge. Show `Merge:     Hand off to reeve (no merge here; ticket moves to "{merge_handoff_state}")` in the summary and offer `(yes / merge here anyway / no)`. "Merge here anyway" continues with the normal Step 6; "yes" skips Step 6 and takes the hand-off branch of Step 7. Absent the key, this paragraph does not apply and nothing below changes.

Then present a complete summary of what you're about to do:

```
## Ready to close out {TICKET-ID}

Ticket:    {TICKET-ID} — "{ticket title}"
PR:        #{pr_number} — {pr_url}
Merge:     {Squash merge | Merge commit} into {baseRefName}
Action:    Move ticket to "{target_status | merge_handoff_state}"
{If QA path:}
QA:        Assign to {qa_person_name}

Proceed? {(yes / no / change something) | with merge_owner: reeve: (yes / merge here anyway / no)}
```

Wait for explicit confirmation. If the user says "no" or wants to change something, address their concern and re-confirm before proceeding.

---

## Step 6: Merge the PR

**If you took the hand-off at Step 5, or `merge_owner: reeve` applies in autonomous mode, skip this step entirely. Nothing is merged on that path.**

Use the merge strategy you determined in Step 5.

### Attempt merge

Whether this checkout is a linked worktree is the `checkout` field from `ccm-context` in Step 1 (`worktree` or `primary`). A worktree-per-ticket setup is normal, not an error.

If the user chose at Step 3 to merge past a blocker and the `merge_guard: on` hook denies the merge, rerun the same merge command prefixed with `CCMAGIC_MERGE_OVERRIDE=1`. Only do this after that explicit choice; never in autonomous mode, where the hook ignores the prefix anyway.

**Primary checkout:**

```bash
gh pr merge {pr_number} {--squash | --merge} --delete-branch
```

**Linked worktree** — merge **without** `--delete-branch` (it would fail against the worktree's checked-out branch), then — only once the merge is confirmed — delete the remote branch best-effort, leaving the local worktree and branch in place; whoever created the worktree owns its lifecycle:

```bash
gh pr merge {pr_number} {--squash | --merge}
[ "$(gh pr view {pr_number} --json state -q .state)" = "MERGED" ] && \
  git push origin --delete {headRefName} 2>/dev/null || true
```

If the merge itself failed, do **not** delete the remote branch — fall through to conflict handling / the error table with the PR still open.

Note the worktree in the Step 8 report ("Worktree: left in place at {path}"). No warnings, no errors.

Use the strategy flag chosen in Step 5 (`--squash` for feature/bugfix/hotfix/chore branches, `--merge` for `release/...`). If `--delete-branch` is not supported by the installed `gh` version, omit it.

### Handle merge conflicts

If the merge fails due to conflicts:

1. Report the conflict clearly:
   > "The PR cannot be merged automatically due to conflicts."
2. Fetch and attempt local resolution:
   ```bash
   git fetch origin
   git checkout {headRefName}
   git merge origin/{baseRefName}
   ```
3. Show the conflicting files:
   ```bash
   git diff --name-only --diff-filter=U
   ```
4. Attempt to resolve straightforward conflicts (version bumps, import lists, config values). If the conflict requires business-logic judgment, show it to the user and ask.
5. After resolving:
   ```bash
   git add {resolved files}
   git commit -m "chore: resolve merge conflicts for {TICKET-ID}"
   git push origin {headRefName}
   ```
6. Re-attempt the PR merge.
7. If conflicts cannot be resolved, stop and tell the user what remains unresolved.

### Verify merge success

Run `gh pr view {pr_number} --json state,mergedAt,mergeCommit` and confirm `state` is `MERGED`.

---

## Step 7: Update the Ticket

### Hand-off branch (`merge_owner: reeve` and the PR was not merged here)

Post this comment to the ticket instead of the closing comment, using the same per-tracker mechanism the sections below use for the closing comment (Linear: the Linear MCP comment tool; GitHub: `gh issue comment {N}`; JIRA: the Atlassian MCP comment tool). Under prompt-relay (contract §7) or when orchestrated (contract §8), do not post it; include its composed content in this skill's final output so the orchestrator's summary carries it.

````markdown
## Ready for merge, handed off to Reeve

**PR:** [{pr_title}]({pr_url})
**Base:** `{baseRefName}`
**Branch:** `{headRefName}`
**Preflight:** {mergeable | NOT mergeable: conflicts}; CI {green | {n} failing: {check names}}; {no unaddressed change requests | change requests outstanding from {reviewer}}.

### Summary of changes
{2-4 bullet points derived from the PR body / commit log}

Reeve classifies this PR against `.reeve/policy.yml`, re-checks CI, and merges or parks it. Nothing was merged by this run.
````

The Preflight line reports what Step 3 actually observed. If the user chose to proceed past a Step 3 blocker interactively, name the blocker there rather than asserting green; Reeve re-checks CI and mergeability before it merges.

Then transition the ticket to `merge_handoff_state` by **exact** state-name match (no fallbacks: not Done, not Merged, not In Review). On JIRA this is a transition to the status with that exact name from the list fetched in Step 2, scoped to the project. If no state with that name exists on the team (or project), do not transition and do not merge; in autonomous mode emit `needs-human` with `reason: merge_owner is reeve but state "{merge_handoff_state}" does not exist on {team}`; interactively, say so and stop. Under prompt-relay or when orchestrated, report `requested_state: {merge_handoff_state}` in the handshake instead of transitioning (the orchestrator does the exact-name check). On GitHub Issues, apply the label `awaiting-merge` (create it first if missing: `gh label create "awaiting-merge" 2>/dev/null || true`, then `gh issue edit {N} --add-label "awaiting-merge"`) and leave the issue open. Skip the rest of Step 7 and go to Step 8.

Compose the closing comment first (same body for all trackers):

```markdown
## Work Complete — PR Merged

**PR:** [{pr_title}]({pr_url})
**Merged into:** `{baseRefName}`
**Branch:** `{headRefName}`

### Summary of changes
{2-4 bullet points derived from the PR body / commit log describing what was built}

### Files changed
{Top 5-8 changed files from git diff --stat}
```

### Linear

1. Post the comment via `mcp__*Linear*__save_comment` (or equivalent).
2. Transition the issue via `mcp__*Linear*__save_issue` to the target state. State-name matching:
   - **QA path** — try "QA", "Ready for QA", "Testing", "In Review", "Review" in that order against the team's workflow states.
   - **Done path** — try "Done", "Completed", "Closed".
3. If QA path, update the assignee to the QA person.

**Under prompt-relay** (contract §7), **or when orchestrated** (contract §8, for every tracker in this step): do not post the closing comment to the ticket (the orchestrator's summary carries it) and do not transition or close anything, and skip state-name matching entirely (per Step 2). Instead report `requested_state: Done` via the handshake field (contract §3), and make sure the closing-comment content composed above is present in this skill's final output so the orchestrator's Step 6 summary can include it. **Merging via `gh` is unchanged** — that already happened in Step 6.

### GitHub

```bash
gh issue comment {N} --body "$(cat <<'EOF'
{closing comment content}
EOF
)"
```

Then:
- **Done path:** `gh issue close {N}` — PR merge with `Closes #N` may already have closed it; verify.
- **QA path:** GitHub has no built-in QA state. Apply the label specified in `.claude/ccmagic.local.md` (`qa_label:` field) via `gh issue edit {N} --add-label "{label}"`, and re-assign with `--add-assignee {qa_person}`. If `qa_label` isn't configured, ask the user which label to use, then offer to save it.

### JIRA

1. Post the comment via the available Atlassian MCP tool.
2. Find the right transition for the target state based on the transitions list retrieved in Step 2. State-name matching:
   - **QA path** — "QA", "Ready for QA", "Ready for Testing", "Testing", "In Review", "Review".
   - **Done path** — "Done", "Completed", "Closed".
3. Use the available Atlassian MCP tools to:
   - Transition the issue using the transition ID.
   - If QA path, update the assignee field to the QA person.

---

## Step 8: Done

Report the completed outcome:

```
{## Ticket closed out | ## Handed off for merge}

Ticket:  {TICKET-ID} — "{ticket title}"
PR:      #{pr_number} {merged → {baseRefName} | handed off to reeve, open against {baseRefName}}
Status:  Moved to "{target_status | merge_handoff_state}"
{If a linked worktree:}
Worktree: left in place at {path}
{If QA path:}
QA:      Assigned to {qa_person_name}

{ticket_url}
```

---

## Autonomous mode

`/ccmagic:finish-ticket` runs interactively by default. Autonomous mode is **opt-in and additive**: Step 3's sanity check becomes a hard **merge gate**, and the confirmation prompts are removed — but the merge only ever happens when the PR is genuinely ready. Anything short of ready **parks** the ticket; it never merges on a guess.

### When autonomous mode is active

Autonomous mode is ON when the first present signal (in priority order) resolves truthy:

1. `--autonomous` in the skill arguments.
2. An `autonomous: true` line in the grounding/context block a parent skill (e.g. `/ccmagic:auto-ticket`) prepends when invoking this skill.
3. `autonomous: true` in `ccmagic.local.md` frontmatter — the project file `.claude/ccmagic.local.md` first, then the user file `~/.claude/ccmagic.local.md`.

Absent all three, run the interactive path exactly as documented above. Also read `needs_human_state:` / `needs_human_label:` / `merge_owner:` / `merge_handoff_state:` from config; a value in the grounding block wins over config. **Orchestrated vs. standalone** works as in `/ccmagic:work-ticket` → *Autonomous mode*. **No tracker I/O when orchestrated:** with `orchestrator:` in the grounding block, Steps 2 and 7 make no tracker reads or writes (contract §8); the target state goes in `requested_state:` and the closing or hand-off comment stays in your report.

### Behavior at each human-gate

- **Step 3 (Sanity check) — this is the merge gate.** Merge **only if** `ccm-merge-gate` exits 0 (after waiting out `pending` / `not-registered` CI with `ccm-ci-status --watch` as Step 3 describes). **Never ask a human to confirm CI, and never emit a question as the run's result** — an autonomous run ends by merging or by route-and-stop, never by asking. If the gate fails → `needs-human` (do **not** merge; the `reason` is the gate's `blockers` joined with `; `). Do not take the interactive "proceed anyway" option. The PreToolUse hook denies `gh pr merge` in autonomous runs while the gate fails, so a merge attempt past a failed gate is refused, and the refusal means `needs-human`.
- **Step 4 (Disposition):** always take the **Done** path. The QA path needs an interactive hand-off (QA-assignee lookup, status confirmation) that would hang an unattended run, so autonomous mode never enters it — **even if `default_qa_workflow: true`**. If the QA path was explicitly forced (`--qa` passed *together with* an autonomous signal), that's a conflict autonomous mode can't satisfy → `needs-human` (reason: "QA disposition requires a human — re-run without `--qa`, or complete QA manually"); do **not** merge. A project that requires QA on every ticket should not be driven by `/ccmagic:auto-ticket`.
- **Step 5 (Merge confirmation):** proceed with the determined strategy — squash for `feature/`/`bugfix/`/`hotfix/`/`chore/`, merge commit for `release/` — no pause.
- **Step 6 (Merge conflicts):** auto-resolve **trivial** conflicts (version bumps, import lists, config values) exactly as Step 6 already describes. A **business-logic** conflict → `needs-human` (do not merge; leave the branch unmerged, `reason` names the conflicting files).

### Merge hand-off (`merge_owner: reeve`)

When `merge_owner` resolves to `reeve`, the run **never merges**. The Step 3 merge gate still runs as a preflight and still parks on any blocker exactly as above (a red or conflicting PR is not handed off). When the gate is satisfied: skip Step 4's disposition question (its `--qa` conflict rule still applies), Step 5, and Step 6 entirely (no `gh pr merge`, no branch deletion), take the *Hand-off branch* of Step 7, and emit:

```
status: done
reason: handed off to reeve; PR #{pr_number} awaiting merge
follow_ups: []
requested_state: <{merge_handoff_state} when orchestrated or under prompt-relay; omit otherwise>
```

The `reason` must begin with the exact text `handed off to reeve`; `/ccmagic:auto-ticket` keys on it. A missing `merge_handoff_state` on the team is `needs-human` (Step 7 hand-off branch), never a fallback merge. Absent the key, or with `merge_owner: self`, this section does not apply and the run merges as documented above.

### Route-and-stop (park the ticket) — top-level entry points only

1. Do **not** merge.
2. Move the ticket to `needs_human_state`. If that state/transition doesn't exist, apply `needs_human_label` if configured and/or leave the state unchanged. On **GitHub** (no custom states), always apply `needs_human_label` — create it first if missing (`gh label create "{needs_human_label}" 2>/dev/null || true`) so `gh issue edit {N} --add-label "{needs_human_label}"` can't fail on a first-time park.
3. Post a comment on the PR **and** the ticket stating exactly what needs a human and why (the `reason`).
4. Emit the handshake with `status: needs-human`. Exit cleanly — never wait for input.

**Under prompt-relay** (contract §7): apply contract §4's *Under the prompt-relay transport* adjustments — no state move or label (step 2's Linear writes are skipped), post the parked note to the PR only, and emit it — with `Requested state: {needs_human_state}` — wrapped in the §7 final-message delimiters as your final output.

### Handshake (emit last, in autonomous mode)

```
status: done | needs-human
reason: <one line — "merged into {base}" on done; the blockers on needs-human>
follow_ups: []
requested_state: <Done when orchestrated or under prompt-relay; omit otherwise>
```

`done` = PR merged, ticket moved to Done, closing comment posted; or, with `merge_owner: reeve`, PR left open, ticket moved to `merge_handoff_state`, hand-off comment posted, and `reason` beginning `handed off to reeve`. When orchestrated (contract §8) or under prompt-relay (contract §7), `done` = merged (or handed off), with the target state in `requested_state:`; the orchestrator or the harness owns the actual move and comment.

---

## Error Handling

| Situation | Action |
|-----------|--------|
| No tracker available — unless the prompt-relay detection rule matched (contract §7) | Stop. Tell user to install one or set `tracker:` in `.claude/ccmagic.local.md`. |
| No PR found | Stop. Tell user to create one first. |
| Ticket not found | Stop. Tell user the ID that failed. |
| Tracker MCP/CLI not connected | Stop. Tell user which integration is needed. |
| CI checks failing | Surface them. Ask user to fix or override. (Autonomous: `needs-human` — do not merge.) |
| Changes requested on PR | Surface them. Ask user to address or override. (Autonomous: `needs-human` — do not merge.) |
| PR has conflicts | Attempt local resolution. Escalate unresolvable conflicts to user. (Autonomous: trivial → resolve; business-logic → `needs-human`.) |
| Merge fails for other reason | Show the error. Do not retry blindly. |
| `--delete-branch` fails (branch checked out in a worktree, or any local-checkout reason) | Verify the merge succeeded (`gh pr view --json state`), delete the remote branch best-effort (`git push origin --delete {headRefName}`), leave the local checkout alone, and report the outcome gracefully — this is not an error. |
| Conflict resolution: `git checkout {headRefName}` fails with "'{headRefName}' is already used by worktree at '{path}'" | The branch lives in a linked worktree — run the same conflict-resolution commands from that worktree path instead, then re-attempt the merge. Not an error. |
| Target transition not found (JIRA/Linear) | Show available transitions/states. Ask user to pick. (Autonomous: for the Done target, try the fallbacks; if none match, apply `needs_human_label` and note it.) |
| QA label missing (GitHub QA path) | Ask user which label, offer to save to config. |
| Ticket update fails | Warn user. Report what was and wasn't updated. Continue to Done. |
| Cannot identify QA person (QA path only) | Ask the user directly. |
| User says "no" at confirmation | Stop cleanly. Nothing has been merged yet. |
| Autonomous: merge gate not satisfied | `needs-human` — route-and-stop (park to `needs_human_state`, comment on PR + ticket) if top-level; else emit the handshake for the parent. |
| `merge_owner: reeve` and `merge_handoff_state` does not exist on the team | Do not merge, do not transition. Interactive: say so and stop. Autonomous: `needs-human` with the state name in `reason`. |
