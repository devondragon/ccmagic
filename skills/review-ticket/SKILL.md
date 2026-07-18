---
name: review-ticket
description: Ticket-grounded code review. Fetches the ticket from Linear, GitHub Issues, or JIRA, then runs /ccmagic:review with the ticket scope as the primary intent source. Adds an explicit Ticket-scope drift section (in-scope / out-of-scope / missing-from-ticket).
user-invocable: true
allowed-tools: Read(*), Edit(*), Bash(git:*, gh:*), Glob(*), Grep(*), Agent(*), Task(*), TodoWrite(*), AskUserQuestion(*), Skill(*)
argument-hint: "[TICKET-ID] [--threshold N]"
model: inherit
---

# /review-ticket — Ticket-Grounded Code Review

Runs a full code review with the **ticket as the ground truth for intent**. The reviewer sees not just the diff but the ticket's stated problem, scope, and acceptance criteria — so it can flag both code-quality issues *and* drift from what was actually asked for.

**On invocation, announce:** "I'll resolve your tracker, fetch the ticket, run the scope-drift check against acceptance criteria, then call /ccmagic:review with the ticket context attached. The final report includes a Ticket-scope drift section."

## When to use this vs `/ccmagic:review`

- Use `/ccmagic:review` when you want a code-quality review against generic best practices.
- Use `/ccmagic:review-ticket` when there's a tracker ticket driving the work and you want the review to also catch scope creep, missing acceptance criteria, or work that doesn't match what was requested.

---

## Step 0: Load project settings & resolve tracker

Same cascade as `/ccmagic:work-ticket`:

1. Read `.claude/ccmagic.local.md` (if present) for `tracker:`, `ticket_url_base:`, `ticket_id_regex:`, `github_repo:` — and fall back to the user-level `~/.claude/ccmagic.local.md` for any key the project file omits (project overrides user).
2. If `tracker:` is `auto` or unset, run the detection cascade:
   - **Arg shape:** integer-only ticket ID → GitHub; `[A-Z][A-Z0-9]+-[0-9]+` → Linear or JIRA.
   - **MCP probe:** Linear MCP (`mcp__*Linear*__get_issue`), Atlassian/JIRA MCP (`mcp__*atlassian*__*` or `mcp__*Atlassian*__*`).
   - **CLI probe:** `command -v gh && gh repo view --json nameWithOwner 2>/dev/null`.
   - **Branch hint:** match against `ticket_url_base` if ambiguous.
   - **Prompt-relay fallback:** if the contract §7 detection rule matches (`skills/auto-ticket/autonomous-contract.md` §7), resolve `tracker: linear` with `transport: prompt-relay` instead of stopping.
3. If none found, stop: tell the user to install a tracker integration or set `tracker:`.

Transport is resolved regardless of how the tracker was determined: whenever the tracker is `linear` — pinned in config or detected via the cascade — apply the contract §7 detection rule (`skills/auto-ticket/autonomous-contract.md` §7) to set `transport: mcp | prompt-relay`. A pinned `tracker:` skips the cascade above, never transport resolution — so a standalone headless run against a pinned-Linear repo still resolves `prompt-relay` instead of reaching for a nonexistent MCP.

---

## Step 1: Detect the ticket

1. If `$1` looks like a ticket ID (matches `ticket_id_regex` or is a pure integer), use it.
2. Otherwise parse the current branch (`git branch --show-current`) for a ticket ID. Strip prefixes like `feature/`, `bugfix/`, `hotfix/`, `chore/`.
3. If neither yields a ticket ID, ask:
   > "I couldn't detect a ticket from the branch (`{branch}`) or arguments. What ticket should I use?"

---

## Step 2: Fetch the ticket

### Linear

Use `mcp__*Linear*__get_issue`. Extract `title`, `description`, `state.name`, `labels`, `priority`, comments. The description may contain acceptance criteria as bullet lists, checkboxes, or "Acceptance Criteria" headers — parse them out.

**Under prompt-relay** (contract §7): skip the MCP call — take `title` and `description` from the grounding block's `ticket_content:` section (contract §2). Parse acceptance criteria out of that text exactly as for an MCP fetch (bullets, checkboxes, "Acceptance Criteria" headers). Ticket *comments* are not available under prompt-relay — the AC sources are title + description only. If the `ticket_content:` section is absent, stop with the setup-error message per contract §7 `fetch_ticket` — never guess. The "If not found" stop text below applies only to the MCP path.

### GitHub

```bash
gh issue view {N} --repo {github_repo or auto-detected} --json title,body,state,labels,url,comments
```

Treat `body` as the description. AC may appear as `- [ ]` checkboxes or "Acceptance Criteria" sections.

### JIRA

Use the Atlassian MCP tool to fetch the issue. Extract `summary`, `description`, `status`, `issuetype`, comments. AC may be in a dedicated field, a checklist, or buried in the description.

### If not found

Stop. Tell the user the ticket ID failed and which tracker you tried.

---

## Step 3: Extract acceptance criteria

From the ticket title, description, and recent comments, extract:

- **Goal** — one-sentence summary of what the ticket is asking for.
- **Acceptance criteria** — bulleted list. If the ticket has explicit AC, use it verbatim. If not, infer 2-4 criteria from the description and present them to the user with a brief confirmation prompt:
  > "The ticket has no explicit acceptance criteria. I inferred these from the description — does this look right? {list}"
- **Out-of-scope notes** — anything explicitly called out as "not in scope" or "future work".

If the user disagrees with the inferred AC, ask them to clarify before continuing.

---

## Step 4: Run ticket-scope drift analysis

Compute the diff against the base branch:

```bash
# Determine base branch (same logic as /ccmagic:pr)
BASE=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || \
       (git show-ref --verify --quiet refs/heads/develop && echo develop) || \
       echo main)

git diff --name-only $BASE...HEAD
git diff --stat $BASE...HEAD
git diff $BASE...HEAD
```

Cross-reference the diff against the AC and out-of-scope notes:

- **In-scope** — changes that map to an AC item. List each AC item and which files/changes address it.
- **Out-of-scope** — files or hunks that don't tie to any AC. Flag for justification.
- **Missing-from-ticket** — AC items with no evidence in the diff. List each unfulfilled AC.

Hold this analysis — it will be merged into the final report after `/ccmagic:review` runs.

---

## Step 5: Invoke /ccmagic:review with ticket context

Invoke `/ccmagic:review` via the Skill tool with a grounding block prepended to the arguments. The grounding block looks like:

```
TICKET CONTEXT:
ID: {TICKET-ID}
Title: {title}
URL: {ticket_url}

Goal: {one-sentence goal}

Acceptance Criteria:
- {AC item 1}
- {AC item 2}
- ...

Out-of-scope: {anything explicitly excluded}

(The above is the source of truth for intent. The review's Step 2.5 Scope Drift Detection should treat this ticket as the primary intent source, ahead of plan files, PR description, or commit messages.)
```

Pass through any `--threshold N` argument the user provided.

`/ccmagic:review` will run its full pipeline (4 core agents + conditional specialists + Codex CLI if available + MCP fallback + triage). Wait for its report.

---

## Step 6: Produce the combined report

Prepend a dedicated **Ticket-scope drift** section to the review report:

```markdown
# Ticket-Grounded Review: {TICKET-ID}

## Ticket
- **{TICKET-ID}** — "{title}" ([link]({ticket_url}))
- **State:** {state}
- **Goal:** {one-sentence}

## Acceptance Criteria
- [ ] {AC 1} — {Addressed | Partially addressed | Missing}
- [ ] {AC 2} — {Addressed | Partially addressed | Missing}
- ...

## Ticket-Scope Drift

### In-scope (matches AC)
| File | Lines | AC item |
|------|-------|---------|
| ... | ... | ... |

### Out-of-scope (no AC match — needs justification)
| File | Lines | Concern |
|------|-------|---------|
| ... | ... | ... |

If empty: "No out-of-scope changes detected."

### Missing from ticket (AC items not covered by diff)
- {AC item N} — no evidence in the diff. Recommendation: address before merging, or update the ticket to clarify deferral.

If empty: "All AC items have corresponding changes."

---

{Full code review report from /ccmagic:review here, including its own Scope Check, Critical/High/Medium findings, etc.}
```

The drift section is informational — it does not block. But it gives the user a clear pre-merge signal for whether the work matches the ticket.

---

## Step 7: Handle drift findings

After presenting the report, if there are out-of-scope changes or missing AC items, ask the user:

> "Found {N} out-of-scope changes and {M} missing AC items.
> A) Continue addressing missing AC items now
> B) Revert out-of-scope changes
> C) Update the ticket to reflect actual scope
> D) Acknowledge and proceed (note in PR description)"

Use `AskUserQuestion`. Take the appropriate follow-up action based on the choice. For (C), help the user draft a ticket comment explaining the scope change.

---

## Autonomous mode

`/ccmagic:review-ticket` runs interactively by default. Autonomous mode is **opt-in and additive** — it changes behavior only at the human-gates below (AC confirmation and drift handling) and adds a machine-readable verdict; the review pipeline itself is unchanged. This skill still only **reports and verdicts** — it does not mutate code; the caller (or `/ccmagic:auto-ticket`) applies fixes.

### When autonomous mode is active

Autonomous mode is ON when the first present signal (in priority order) resolves truthy:

1. `--autonomous` in the skill arguments.
2. An `autonomous: true` line in the grounding/context block a parent skill prepends when invoking this skill.
3. `autonomous: true` in `ccmagic.local.md` frontmatter — the project file `.claude/ccmagic.local.md` first, then the user file `~/.claude/ccmagic.local.md`.

Absent all three, run the interactive path exactly as documented above. Also read `needs_human_state:` / `needs_human_label:` from config. **Orchestrated vs. standalone** works exactly as in `/ccmagic:work-ticket` → *Autonomous mode*: a parent's grounding block (#2) means the parent parks on `needs-human`; `--autonomous`/config (#1/#3) means this skill parks (route-and-stop) itself.

### Behavior at each human-gate

- **Step 3 (Confirm inferred AC):** do not pause. Use the inferred acceptance criteria and write them into the report verbatim, marked *(inferred)*.
- **Step 5 (Invoke /ccmagic:review):** prepend the same autonomous grounding block so the review runs without pausing.
- **Step 7 (Drift handling):** apply rules instead of asking:
  - **Out-of-scope changes** stay, but flag each one — leave the out-of-scope table populated and post a PR comment listing them. Do not revert.
  - **Missing AC** → treat as *not-done*: `fixable-findings` if the caller can close it in-scope; `needs-human` if it can't.
  - **CRITICAL findings** from `/ccmagic:review` must be fixed before proceeding → return them under `fixable-findings` (the caller fixes and re-reviews). A CRITICAL finding that needs human judgment → `needs-human`.

### Verdict → handshake mapping

Emit the verdict as the last thing in the report:

```
status: clean | fixable-findings | needs-human
reason: <one line, when not clean>
follow_ups: [<any tickets or deferrals noted>]
```

- **clean** — no CRITICAL findings and no missing AC (out-of-scope items, if any, are flagged only).
- **fixable-findings** — one or more CRITICAL findings and/or missing-AC items that are mechanically fixable in-scope. **List them** in the report so the caller can address them.
- **needs-human** — a finding or missing AC needs human judgment or can't be closed in-scope; `reason` names it. If top-level, route-and-stop (park to `needs_human_state`, or `needs_human_label` if that state doesn't exist — on GitHub create the label first if missing; comment on the PR + ticket) before emitting the handshake.

---

## Error handling

| Situation | Action |
|-----------|--------|
| No tracker available — unless the prompt-relay detection rule matched (contract §7) | Stop. Tell user to install one or set `tracker:` in `.claude/ccmagic.local.md`. |
| Ticket not found | Stop. Tell user clearly which tracker was tried. |
| No diff (on base branch with no changes) | Stop. Tell user there's nothing to review. |
| No AC and user can't confirm inferred AC | Ask user to provide AC explicitly, or proceed without AC checking (drift section will skip AC matrix). (Autonomous: use the inferred AC, mark them *(inferred)*.) |
| /ccmagic:review fails | Surface the error. Do not silently retry. |
| User disputes drift classification | Mark the drift item as "user-acknowledged" in the report. Do not silently drop. |
| Autonomous: CRITICAL findings or fixable missing AC | Emit `fixable-findings` with the list — the caller addresses and re-reviews. |
| Autonomous: finding/AC needs human judgment or can't be closed in-scope | Emit `needs-human`; route-and-stop if top-level, else hand the verdict to the parent. |
