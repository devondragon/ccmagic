---
name: work-ticket
description: End-to-end ticket workflow. Detects your tracker (Linear, GitHub Issues, or JIRA), looks up the ticket, assigns it to you, moves it to In Progress, triages the work type, creates a branch, executes the work (delegating to /ccmagic:debug for bugs), validates scope, then commits and opens a PR.
user-invocable: true
allowed-tools: Read(*), Write(*), Edit(*), Bash(git:*, gh:*, mkdir:*), Glob(*), Grep(*), Task(*), TodoWrite(*), AskUserQuestion(*), Skill(*)
argument-hint: Ticket ID (e.g. ENG-123, PROJ-456, or a GitHub issue number like 42)
model: sonnet
---

# /work-ticket — End-to-End Ticket Workflow

Given a ticket ID, handles the full development lifecycle from ticket lookup through PR creation. Works with Linear, GitHub Issues, or JIRA.

**On invocation, announce:** "I'll resolve your tracker, look up the ticket, classify it (quick fix / complex feature / debugging), create a branch, execute the work, review it, and open the PR. I'll pause at the classification and PR steps for your confirmation."

## Sacred Rule: Never Guess Ticket Content

**If the ticket cannot be found, stop immediately and tell the user. Do not infer, guess, or fabricate what the ticket might contain.** The ticket system is the source of truth.

---

## Step 0: Load project settings & resolve tracker

### 0a. Load settings

If `.claude/ccmagic.local.md` exists at the repo root (`git rev-parse --show-toplevel`), read its YAML frontmatter. Relevant keys:

- `tracker:` — `linear` | `github` | `jira` | `auto` (default `auto`)
- `ticket_url_base:` — for display links
- `ticket_id_regex:` — defaults to `[A-Z][A-Z0-9]+-[0-9]+`
- `github_repo:` — `owner/repo` (only used when tracker is GitHub)

### 0b. Resolve tracker (cascade — runs when `tracker: auto` or unset)

1. **Arg shape hint:** if the ticket ID is a pure integer (e.g. `42`) and `gh` is available, lean GitHub. If it matches the `ticket_id_regex` (e.g. `ENG-123`), it could be Linear or JIRA.
2. **MCP probe:** check which tools are available in the current session.
   - Linear MCP: any tool matching `mcp__*Linear*__get_issue` (e.g. `mcp__claude_ai_Linear__get_issue`, `mcp__plugin_linear_linear__get_issue`).
   - Atlassian/JIRA MCP: any tool matching `mcp__*atlassian*__*` or `mcp__*Atlassian*__*`.
   - Pick the first match. If both Linear and JIRA MCPs are available, prefer Linear unless `ticket_url_base` looks JIRA-shaped (`*.atlassian.net`).
3. **CLI probe:** `command -v gh && gh repo view --json nameWithOwner 2>/dev/null` — if available and inside a repo, GitHub is a candidate.
4. **Branch hint:** if the current branch matches the `ticket_id_regex`, prefer whichever tracker the URL base points at.
5. **Ambiguous:** ask the user via `AskUserQuestion`. Offer to write the choice to `.claude/ccmagic.local.md` so they're not asked again.
6. **None available:** stop. Tell the user: "I couldn't find a Linear MCP, GitHub CLI, or Atlassian MCP. Install one or set `tracker:` in `.claude/ccmagic.local.md`."

Record the resolved tracker (`linear`, `github`, or `jira`) for use in steps 1, 2, and 8.

---

## Step 1: Look up the ticket

Validate the ticket ID against `ticket_id_regex` (or the integer fallback for GitHub). Then fetch the ticket using the resolved tracker:

### Linear

Use the available Linear MCP tool (e.g. `mcp__claude_ai_Linear__get_issue`) with the ticket ID. Extract:

- `title`
- `description`
- `state.name` (current status)
- `assignee`
- `labels` and `priority` (helpful for triage)
- URL: from the response, or `{ticket_url_base}/{TICKET-ID}` if available

### GitHub

```bash
gh issue view {N} --repo {github_repo or auto-detected} --json title,body,state,assignees,labels,url
```

Extract `title`, `body` (treat as description), `state`, `assignees`, `labels`, `url`.

### JIRA

Use the available Atlassian MCP tools (e.g. `mcp__plugin_atlassian_atlassian__*` or `mcp__claude_ai_Atlassian__*`). Common operations: get issue by ID, update assignee, transition status, add comment. Extract `summary` (title), `description`, `status.name`, `assignee`, `issuetype.name`, URL.

### If not found

Stop. Tell the user:

> "I could not find ticket `{TICKET-ID}` in {tracker}. Please verify the ticket ID and confirm the tracker integration is connected."

Do not proceed.

---

## Step 2: Assign the ticket and move to In Progress

### Linear

Use the Linear MCP tool to save the issue with the current user as assignee and state transitioned to "In Progress" (or the closest equivalent in the workflow).

### GitHub

```bash
gh issue edit {N} --add-assignee @me
# GitHub issues don't have a built-in "In Progress" state — labels are commonly used.
# If a project board with an "In Progress" status exists, the user can configure that;
# otherwise add a label if one is defined in .claude/ccmagic.local.md, else skip silently.
```

### JIRA

Use the available Atlassian MCP tools to assign to current user and transition to "In Progress".

**If this step fails:** Warn the user ("Could not update ticket status — continuing with local work"), then proceed. Work can happen even if the ticket update failed.

---

## Step 3: Triage the ticket

Read the full ticket title and description carefully. Reason about the type of work this represents.

Present your classification to the user in this exact format:

```
Ticket: {TICKET-ID} — "{title}"
Classification: {Quick Fix | Complex Feature | Debugging}
Reasoning: {2-3 sentences explaining your reasoning, citing specific evidence from the ticket}
Proposed branch: {branch-name}

Is this classification correct? (yes / quick fix / complex feature / debugging / cancel)
```

**Classification rules:**

- **Quick Fix** — Small, bounded change. Likely touches one or two files. No new abstractions, no new UI flows, no API contract changes. Examples: typo fix, wrong color, off-by-one error, missing null check, single config value change.
- **Complex Feature** — New capability that introduces new abstractions, UI flows, or API behavior. Touches multiple files. Has multiple acceptance criteria or a non-trivial implementation path.
- **Debugging** — The ticket reports something "not working", "broken", a regression, an unexpected error, or incorrect behavior. The root cause is unknown. The ticket describes symptoms, not a solution.

Wait for the user to confirm or override before proceeding. If they cancel, stop.

---

## Step 4: Create the feature branch

Check `git branch --show-current`.

If already on a branch that contains `{TICKET-ID}` (matched against `ticket_id_regex`, or the literal integer for GitHub issues), use it — skip branch creation.

Otherwise derive a slug from the ticket title: lowercase, kebab-case, max 40 characters, no special characters. Create the branch using the prefix matching the confirmed classification:

| Classification | Branch prefix |
|----------------|---------------|
| Quick Fix (bug) | `bugfix/{TICKET-ID}-{slug}` |
| Quick Fix (chore/maintenance) | `chore/{TICKET-ID}-{slug}` |
| Complex Feature | `feature/{TICKET-ID}-{slug}` |
| Debugging | `bugfix/{TICKET-ID}-{slug}` |

For GitHub issues use the integer as the `{TICKET-ID}` segment (e.g. `bugfix/42-fix-cart-total`).

```bash
git checkout -b {branch-name}
```

---

## Step 5: Execute the work

### Quick Fix path

1. Implement the fix directly in this session. Read the relevant files first to understand the codebase. Make the minimal change that addresses the ticket scope. Follow the project's coding standards from `context/conventions.md`.
2. Do not over-engineer. If the fix is genuinely one line, make it one line.
3. **Run `/ccmagic:review`** on the change. The auto-router will usually pick QUICK for a one-or-two-file fix and DEEP if it touches risky paths. Address any CRITICAL findings before moving on.

### Complex Feature path

Implement the feature inline in this session, following these phases:

1. **Discovery** — read the ticket carefully, identify acceptance criteria.
2. **Exploration** — use `/ccmagic:analyze-impact` if the change touches risky paths, or read the relevant files directly to understand existing patterns.
3. **Clarifying questions** — ask the user about any underspecified details. Do not guess.
4. **Architecture** — propose a brief implementation plan before writing code; pause for confirmation on non-trivial designs.
5. **Implementation** — write the code following `context/conventions.md`.
6. **Review** — invoke `/ccmagic:review-ticket` so the review is grounded in the ticket scope. Address CRITICAL findings.

> If you want the multi-agent feature workflow (parallel codebase exploration, architecture review), consider `/ccmagic:research` for the exploration phase and `/ccmagic:codex-review` for the review phase.

### Debugging path

Invoke the `ccmagic:debug` skill via the Skill tool. Pass the ticket details as context:

```
Bug report: {TICKET-ID} — {title}

Symptoms: {description}

{any reproduction steps or error messages from the ticket}
```

The debug skill runs its systematic investigation. After it finishes, **run `/ccmagic:review-ticket`** on the resulting fix — debug focuses on correctness of the fix, not code quality or ticket coverage.

---

## Step 6: Validate scope

After work is complete (regardless of path), re-read the original ticket title and description. Compare against what was actually built.

**Determine `{base-branch}`** using the same logic as `/ccmagic:pr`:
1. `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` — use the repo's default branch.
2. If `gh` isn't available, check for `develop`: `git show-ref --verify --quiet refs/heads/develop || git show-ref --verify --quiet refs/remotes/origin/develop`.
3. Otherwise fall back to `main`.

Then run:

```bash
git diff {base-branch}...HEAD --stat
git diff {base-branch}...HEAD
```

Read the changed files to confirm the implementation aligns with the ticket.

For each acceptance criterion or stated goal in the ticket, report:
- **Addressed** — describe how.
- **Partially addressed** — explain the gap.
- **Not addressed** — ask the user how to proceed.

If there are gaps, offer two options:
1. Continue working to address them.
2. Proceed to commit and note the gaps in the PR description.

> Note: scope validation is complementary to the code review run in Step 5 — review checks code quality, scope validation checks ticket coverage. Both matter. If you ran `/ccmagic:review-ticket` in Step 5, the scope drift section already gives you a head start here.

---

## Step 7: Commit and open PR

### Commits

Invoke `/ccmagic:push` to commit the work. The commit-format hook (installed alongside ccmagic) will validate the conventional-commit format post-commit.

If there are multiple logical groups (e.g. model changes, then API changes, then UI changes), invoke push once per group so each commit stays focused.

### PR

Invoke `/ccmagic:pr`. The PR skill will:
- Detect the base branch (via `gh repo view`, falling back to `develop`/`main`).
- Compose the PR title and body using the standard template.
- Include the ticket link as `{ticket_url_base}/{TICKET-ID}` (or the GitHub issue URL).

Confirm the PR with the user before creating it.

After the PR is created, capture the PR URL returned by `gh pr create`.

---

## Step 8: Update ticket with PR link and move to In Review

Once the PR exists, update the ticket to reflect that work is ready for review.

### Linear

Save the issue with state transitioned to "In Review" (or the closest equivalent — Linear teams often customize this). Add the PR link via the `mcp__*Linear*__create_attachment` tool, or as a comment using `save_comment` if attachments aren't available.

### GitHub

```bash
gh issue comment {N} --body "PR ready for review: {pr_url}"
# Optionally update labels or project board status if configured.
```

GitHub issues don't auto-transition; the PR-to-issue link (via `Closes #N` in the PR body) handles closure on merge.

### JIRA

Use the available Atlassian MCP tools to transition the issue to "In Review" (or "Ready for Review"). Post a comment in this format:

```markdown
## Pull Request Ready for Review

**PR:** [{pr_title}]({pr_url})

Work is complete and ready for code review. See the PR for full details on changes, testing instructions, and checklist.
```

### If transition fails

Warn the user ("Could not move ticket to In Review — continuing"), then proceed. If the comment also fails, provide the PR URL so the user can add it manually.

---

## Error handling

| Situation | Action |
|-----------|--------|
| No tracker available (no MCP, no `gh`) | Stop. Tell user to install one or set `tracker:` in `.claude/ccmagic.local.md`. |
| Ticket not found | Stop. Tell user clearly. Do not proceed. |
| MCP server not connected for the chosen tracker | Stop. Tell user which integration is needed. |
| Ticket assign/status update fails | Warn user, continue with work |
| Already on correct branch | Skip branch creation, continue |
| Branch already exists locally | Ask user: switch to it, or create a new one? |
| Sub-skill fails (`/ccmagic:debug`, `/ccmagic:review`, etc.) | Surface the error clearly. Do not silently skip or retry blindly. |
| Scope validation finds gaps | Present gaps. Ask: continue working, or commit with gaps noted? |
| User cancels at triage | Stop cleanly. No branch was created yet, so no cleanup needed. |
| In Review state not found | Warn user, list available states, leave status unchanged. |
| PR comment fails | Warn user, provide PR URL for manual addition. |
