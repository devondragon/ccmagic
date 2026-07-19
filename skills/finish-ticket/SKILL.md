---
name: finish-ticket
description: Closes out a development ticket end-to-end. Detects the tracker (Linear, GitHub Issues, or JIRA) and the ticket from the current branch, sanity-checks the PR, confirms disposition (Done by default, or QA when configured/requested), merges the PR, and updates the ticket with a comment, PR link, and final status.
user-invocable: true
allowed-tools: Read(*), Edit(*), Bash(git:*, gh:*), Glob(*), Grep(*), AskUserQuestion(*), Skill(*)
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
git branch --show-current
```

Parse the branch name for a ticket ID using `ticket_id_regex` (or an integer segment if the resolved tracker is GitHub). The ticket ID typically sits between the prefix slash and the first slug separator:

- `feature/ENG-123-add-search` → `ENG-123` (Linear/JIRA)
- `bugfix/PROJ-456-fix-cart` → `PROJ-456` (Linear/JIRA)
- `bugfix/42-fix-cart-total` → `42` (GitHub)

If no ticket ID can be parsed, ask the user:

> "I couldn't detect a ticket ID from the current branch (`{branch-name}`). What is the ticket ID?"

### PR

Run:
```bash
gh pr view --json number,title,body,state,url,reviews,statusCheckRollup,mergeable,baseRefName,headRefName
```

If no PR exists for this branch, stop and tell the user:

> "No open pull request found for branch `{branch-name}`. Please create a PR first (`/ccmagic:pr`), then run `/ccmagic:finish-ticket` again."

Do not proceed without an open PR.

---

## Step 2: Look Up the Ticket

### Linear

Use the available Linear MCP tool (e.g. `mcp__claude_ai_Linear__get_issue`). Extract `title`, `description`, `state.name`, `assignee`, `priority`, `labels`, `url`. Linear states are workflow-defined per team — fetch the full state list so you can match QA/Done targets in Step 7.

**Under prompt-relay** (contract §7): skip the MCP call — take `title` and `description` from the grounding block's `ticket_content:` section (contract §2). There is no team-state list to fetch; state targets are relay intents, not API transitions, so Step 7 skips state-name matching entirely under this transport. If the `ticket_content:` section is absent, stop with the setup-error message per contract §7 `fetch_ticket` — never guess. The "If not found" stop text below applies only to the MCP path.

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

Evaluate these criteria and produce a clear status report:

### 3a. PR State
- Is the PR open (not already merged or closed)?
- Is it mergeable? (check `mergeable` field — `MERGEABLE`, `CONFLICTING`, or `UNKNOWN`)

### 3b. CI Checks
Examine `statusCheckRollup`:
- Are all required checks passing?
- Are any checks pending, failing, or erroring?
- List any failing checks by name.

### 3c. Reviews
Examine `reviews`:
- Are there any blocking review requests (CHANGES_REQUESTED) that have not been addressed?
- Is there at least one approving review?
- A PR can proceed without an approving review, but flag it as a warning.

### 3d. Scope Alignment
Run:
```bash
git log --oneline {baseRefName}...HEAD
git diff {baseRefName}...HEAD --stat
```

Compare the commit history and file changes against the ticket title and description. Briefly assess whether the work looks complete relative to the ticket scope.

Look for:
- Obvious gaps (e.g., ticket mentions a UI change but only backend files changed).
- Scope creep (many unrelated files changed).
- Incomplete implementation signals (TODO comments, skipped tests, WIP commits).

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

Then present a complete summary of what you're about to do:

```
## Ready to close out {TICKET-ID}

Ticket:    {TICKET-ID} — "{ticket title}"
PR:        #{pr_number} — {pr_url}
Merge:     {Squash merge | Merge commit} into {baseRefName}
Action:    Move ticket to "{target_status}"
{If QA path:}
QA:        Assign to {qa_person_name}

Proceed? (yes / no / change something)
```

Wait for explicit confirmation. If the user says "no" or wants to change something, address their concern and re-confirm before proceeding.

---

## Step 6: Merge the PR

Use the merge strategy you determined in Step 5.

### Attempt merge

First detect whether this checkout is a linked worktree (a worktree-per-ticket setup is normal, not an error):

```bash
[ "$(git rev-parse --path-format=absolute --git-dir)" != "$(git rev-parse --path-format=absolute --git-common-dir)" ] && echo worktree || echo primary
```

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

```bash
gh pr view {pr_number} --json state,mergedAt,mergeCommit
```

Confirm `state` is `MERGED`.

---

## Step 7: Update the Ticket

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

**Under prompt-relay** (contract §7): do not post the closing comment to the ticket (contract §7 `comment` — the orchestrator's single summary carries it) and do not transition state — skip state-name matching entirely (per Step 2's prompt-relay note). Instead report `requested_state: Done` via the handshake field (contract §3), and make sure the closing-comment content composed above is present in this skill's final output so the orchestrator's Step 6 summary can include it. **Merging via `gh` is unchanged** — that already happened in Step 6.

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
## Ticket closed out

Ticket:  {TICKET-ID} — "{ticket title}"
PR:      #{pr_number} merged → {baseRefName}
Status:  Moved to "{target_status}"
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

Absent all three, run the interactive path exactly as documented above. Also read `needs_human_state:` / `needs_human_label:` from config. **Orchestrated vs. standalone** works as in `/ccmagic:work-ticket` → *Autonomous mode*.

### Behavior at each human-gate

- **Step 3 (Sanity check) — this is the merge gate.** Merge **only if all** of: PR is `MERGEABLE`, every required CI check has passed (green) — an **empty** `statusCheckRollup` counts as green only when the repo genuinely has no CI (no workflow files under `.github/workflows/`, no required status checks on the base branch); CI configured but zero checks registered on the PR is **not** green — and there are no unaddressed `CHANGES_REQUESTED` reviews. If any is not satisfied → `needs-human` (do **not** merge; the `reason` lists the specific blockers). Do not take the interactive "proceed anyway" option.
- **Step 4 (Disposition):** always take the **Done** path. The QA path needs an interactive hand-off (QA-assignee lookup, status confirmation) that would hang an unattended run, so autonomous mode never enters it — **even if `default_qa_workflow: true`**. If the QA path was explicitly forced (`--qa` passed *together with* an autonomous signal), that's a conflict autonomous mode can't satisfy → `needs-human` (reason: "QA disposition requires a human — re-run without `--qa`, or complete QA manually"); do **not** merge. A project that requires QA on every ticket should not be driven by `/ccmagic:auto-ticket`.
- **Step 5 (Merge confirmation):** proceed with the determined strategy — squash for `feature/`/`bugfix/`/`hotfix/`/`chore/`, merge commit for `release/` — no pause.
- **Step 6 (Merge conflicts):** auto-resolve **trivial** conflicts (version bumps, import lists, config values) exactly as Step 6 already describes. A **business-logic** conflict → `needs-human` (do not merge; leave the branch unmerged, `reason` names the conflicting files).

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
requested_state: <Done — prompt-relay only, omit otherwise>
```

`done` = PR merged, ticket moved to Done, closing comment posted. Under prompt-relay (contract §7), `done` = merged, with `requested_state: Done` reported in the handshake — the harness/tracker automation owns the actual move.

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
