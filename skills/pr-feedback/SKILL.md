---
name: pr-feedback
user-invocable: true
allowed-tools: Read(*), Bash(git:*, gh:*, timeout:*), Write(*), Bash(${CLAUDE_SKILL_DIR}/../../bin/ccm-context *), Bash(${CLAUDE_SKILL_DIR}/../../bin/ccm-pr-threads *), Bash(${CLAUDE_SKILL_DIR}/../../bin/ccm-pr-reply *), Glob(*), Grep(*), Task(*), TodoWrite(*), AskUserQuestion(*), Edit(*), Skill(*)
description: Review PR comments and plan fixes for valid concerns
model: sonnet
argument-hint: "[PR#]"
---

# PR Feedback Command

Review comments on a pull request, verify each against the actual code, and create a grouped fix plan for valid concerns.

> **Philosophy:** Bias toward action. Reviewers took time to leave feedback — respect that by fixing legitimate issues rather than punting them. But never blindly accept or reject: read the code first.

## Step 0: Parse Arguments

$ARGUMENTS

If a PR number is provided, use it. Otherwise, detect the PR for the current branch:
```bash
gh pr view --json number,url,title,baseRefName --jq '{number, url, title, baseRefName}'
```

If no PR is found, stop with: "No PR found for the current branch. Provide a PR number or push your branch first."

Store `{PR_NUMBER}`, `{PR_URL}`, `{PR_TITLE}`, and `{BASE_BRANCH}` for later use.

## Step 1: Load Project Conventions

Read these files if they exist (silent skip if missing):
1. `CLAUDE.md` in project root
2. `.claude/CLAUDE.md`
3. `context/conventions.md`

Collect into `{PROJECT_CONVENTIONS}`. These are used in Step 4 to evaluate whether reviewer suggestions align with or contradict project rules.

## Step 2: Fetch PR Comments and Threads

Retrieve all feedback with one call:

```bash
"${CLAUDE_SKILL_DIR}/../../bin/ccm-pr-threads" {PR_NUMBER}
```

(The script is also on the Bash `PATH` as `ccm-pr-threads` while the plugin is enabled; use the bare name if the `${CLAUDE_SKILL_DIR}` path doesn't resolve.)

It prints JSON with:

- `author`: the PR author's login.
- `threads[]`: line-level review threads, already grouped, each with `id`, `path`, `line`, `is_resolved`, `is_outdated`, `open`, `disposition`, `fix_verified`, and `comments[]` in order (`id`, `author`, `by_author`, `created_at`, `url`, `body`). A thread is handled (`open: false`) when it is resolved, or when its last comment is the PR author's reply carrying a disposition marker from `ccm-pr-reply` (for `fixed`, only once the cited commit is verified on the branch). An author reply without a marker, such as "will fix", leaves the thread open.
- `reviews[]`: review submissions with `state` (`APPROVED`, `CHANGES_REQUESTED`, `COMMENTED`) and `body`.
- `issue_comments[]`: general PR conversation comments.
- `truncated`: true if a page limit was hit (100 threads, 50 comments per thread). Say so in the report if it happens.

Read the **full thread** before evaluating any comment in it. Earlier replies may already address the concern or add context that changes its meaning.

Triage the reviewer comments, not the PR author's own (`by_author: true`). Keep the author's comments in view as thread context. Threads with `open: false` need no new action. A reviewer reply after the author's answer, or an unverified `fixed` marker, shows up as `open: true` and gets triaged again.

When replying in autonomous mode, the thread's first comment `id` is the one to reply to (`gh api repos/{owner}/{repo}/pulls/{PR}/comments/{id}/replies`).

## Step 3: Classify Comment Severity

Load `${CLAUDE_SKILL_DIR}/triage-guide.md` for detailed classification criteria.

Assign each reviewer comment a severity level:

| Severity | Meaning | Action required |
|----------|---------|----------------|
| **must-fix** | Blocking — bugs, security, data loss, broken API contract | Fix before merge |
| **should-fix** | Valid improvement — error handling, edge cases, clarity, naming, test gaps | Fix in this PR (default for valid feedback) |
| **style/preference** | Optional — subjective style, alternative approaches, taste | Fix only if project conventions agree |
| **question** | Needs response only — reviewer asks for clarification | Reply, no code change |

**Default bias: should-fix.** When uncertain whether feedback is valid, classify as should-fix. Only downgrade after verification in Step 4.

## Step 4: Verify Each Comment Against Code

This is the critical step. For every comment classified must-fix, should-fix, or style/preference:

### 4a. Read the Actual Code

Read the file and surrounding context at the location the reviewer referenced. Do not rely solely on the diff hunk in the comment — read the full function/block.

### 4b. Check Reviewer's Claim

- **Is the concern factually accurate?** Does the code actually do what the reviewer claims?
- **Is it already handled?** Check callers, error boundaries, middleware, guards, try/catch blocks
- **Is there a test covering this?** Search for test files that exercise the flagged code path
- **Does the project convention agree?** Check `{PROJECT_CONVENTIONS}` — if the reviewer suggests a pattern and the project explicitly uses a different one, the convention wins

### 4c. Assign Final Verdict

After verification, each comment gets one of:

| Verdict | Meaning |
|---------|---------|
| **address-now** | Valid, fix in this PR |
| **defer** | Valid but out of scope — would touch unrelated files, needs design discussion, or requires benchmarking |
| **decline** | Invalid — already handled, based on misunderstanding, contradicts conventions, or would make code worse |
| **respond** | No code change needed — answer the reviewer's question |

### 4d. Detect Conflicting Reviewer Feedback

When two reviewers give contradictory feedback on the same code (e.g., reviewer A says "add error handling here" and reviewer B says "this error handling is unnecessary"):

1. Present both positions clearly
2. Note which aligns with project conventions (if applicable)
3. Use `AskUserQuestion` to let the user decide:
   > **Conflicting feedback on `{file}:{line}`**
   > - **{reviewer_a}**: {summary of position A}
   > - **{reviewer_b}**: {summary of position B}
   > - **Convention alignment**: {which side conventions support, or "no convention applies"}
   > Choose: **A** | **B** | **Skip both**

## Step 5: Group Fixes by File

Batch all address-now comments that touch the same file or concern area. This minimizes context switching during implementation.

### Grouping Rules

1. **Same file** — comments on different lines of the same file become one fix group
2. **Same concern across files** — if multiple comments flag the same pattern (e.g., "add input validation" in 3 different handlers), group them as a single concern
3. **Dependent fixes** — if fixing comment A requires also changing code referenced by comment B, group them

### Priority Ordering

Within each group, order by:
1. must-fix items first
2. should-fix items second
3. style/preference items last

Across groups, order by:
1. Groups containing must-fix items
2. Groups with the most comments (highest reviewer concern density)
3. Remaining groups by file path (alphabetical for predictability)

## Step 6: Create Fix Plan with TodoWrite

Create structured TodoWrite entries for all address-now items, grouped by file:

**For must-fix and should-fix items:**
- One todo per fix group (file-level granularity)
- Format: `PR #{PR_NUMBER}: {file} — {summary of fixes}`
- Include the specific line numbers and what to change

**For style/preference items (approved):**
- One summary todo grouping all style fixes
- Format: `PR #{PR_NUMBER}: Style fixes — {count} items`

**For respond items:**
- One todo for all responses needed
- Format: `PR #{PR_NUMBER}: Reply to {count} reviewer questions`

**For defer items:**
- Ask user preference via `AskUserQuestion` before creating todos:
  > **{count} comments marked for deferral:**
  > {list with one-line summaries}
  > For each: **Create issue** | **Add to backlog** | **Address in this PR anyway** | **Dismiss**

## Step 7: Present Report

```markdown
## PR Comment Triage: #{PR_NUMBER} — {PR_TITLE}

**Comments analyzed**: {total} from {reviewer_count} reviewers
**Convention sources**: {files loaded, or "none found"}

### Must-Fix ({count}) — Blocking
| # | File:Line | Reviewer | Issue | Planned Fix |
|---|-----------|----------|-------|-------------|
| 1 | `path:line` | @user | summary | what to change |

### Should-Fix ({count}) — Valid, Non-Blocking
| # | File:Line | Reviewer | Issue | Planned Fix |
|---|-----------|----------|-------|-------------|

### Style/Preference ({count}) — Optional
| # | File:Line | Reviewer | Issue | Convention Says |
|---|-----------|----------|-------|-----------------|

### Questions to Answer ({count})
| # | Reviewer | Question | Suggested Response |
|---|----------|----------|--------------------|

### Declined ({count}) — No Action
| # | File:Line | Reviewer | Comment | Reason |
|---|-----------|----------|---------|--------|

### Deferred ({count}) — Out of Scope
| # | File:Line | Reviewer | Comment | Reason |
|---|-----------|----------|---------|--------|

### Fix Groups (Implementation Order)
1. **{file}** — {count} fixes: {one-line summary}
2. **{file}** — {count} fixes: {one-line summary}
...
```

## Step 8: Post-Fix Validation

After presenting the plan, suggest validation steps:

> **Recommended next steps after implementing fixes:**
> 1. `/ccmagic:validate` — Run pre-commit checks to catch regressions
> 2. `/ccmagic:test` — Run tests to verify fixes don't break existing behavior
> 3. `gh pr view {PR_NUMBER} --comments` — Review to confirm all threads addressed
>
> When replying to review threads, use `ccm-pr-reply {PR} {comment_id} --disposition fixed|declined|answered|deferred ...` (see *Autonomous mode*, step 4). A plain reply leaves the thread counted as open by `/ccmagic:auto-ticket`.

## Autonomous mode

By default this skill **triages and plans** (Steps 1–8) and hands the fix plan back to you. Autonomous mode is **opt-in and additive**: it keeps the full triage, then **executes** it — apply fixes, reply to reviewers, file follow-ups, and push — so an unattended run leaves the PR actually addressed, not just analyzed.

### When autonomous mode is active

Autonomous mode is ON when the first present signal (in priority order) resolves truthy:

1. `--autonomous` in the skill arguments.
2. An `autonomous: true` line in the grounding/context block a parent skill (e.g. `/ccmagic:auto-ticket`) prepends when invoking this skill.
3. `autonomous: true` in `ccmagic.local.md` frontmatter — the project file `.claude/ccmagic.local.md` first, then the user file `~/.claude/ccmagic.local.md`.

Absent all three, run the interactive plan-only path exactly as documented above.

**Tracker for follow-ups.** Reuse `tracker:` / `ticket:` / `transport:` if the grounding block carries them (trust the grounding block's `transport:` rather than re-detecting). Otherwise run `"${CLAUDE_SKILL_DIR}/../../bin/ccm-context"` (bare `ccm-context` works too, since plugin `bin/` is on `PATH`) and read its JSON: `config.tracker` when it is pinned (`linear`, `github`, or `jira`), else `tracker_hint` (from the ticket ID parsed from the branch, and `config.ticket_url_base`), `gh_available`, and `config.github_repo`. Do not re-read the config files or re-parse the branch. The MCP probe and the rest of the cascade stay as in `/ccmagic:work-ticket` Step 0b, because a shell can't see MCP servers. **Under prompt-relay** (contract §7), **or when orchestrated** (`orchestrator:` in the grounding block, contract §8, any transport): skip tracker resolution for follow-ups, because this skill files no tickets there; see the defer/out-of-scope rule below for how deferred items are recorded instead. **Orchestrated vs. standalone** works as in `/ccmagic:work-ticket` → *Autonomous mode*.

### What changes: triage → execute

Run Steps 1–5 exactly as written (load conventions, fetch threads, classify, verify, detect conflicts, group). Then, instead of building a plan and stopping (Steps 6–7), do these in order:

1. **address-now** → apply the fix with `Edit`, grouped by file per Steps 5–6. For a thread that reports a security issue, or one whose correctness depends on an invariant over untrusted input, follow contract §9 (`skills/auto-ticket/autonomous-contract.md`) before the push: run the reviewer's triggering inputs and any fuzzed or enumerated corpus against the fix within the scratch-program limits (`timeout 60`), and add a property or parameterized test stating the invariant. A fix that still fails those inputs is not pushed or replied to as `fixed`; emit `needs-human` naming the thread and the first failing input.
2. **defer / out-of-scope** → file **one follow-up ticket per item** in the active tracker (Linear via `mcp__*Linear*__save_issue`, GitHub via `gh issue create`, JIRA via the Atlassian MCP) and record its ID in `follow_ups`. **Under prompt-relay or when orchestrated** (contract §7 `file_followup`, §8): do not file a ticket; record a short description of the item in `follow_ups` (contract §3's handshake accepts "ticket ids or short descriptions"); the reply in step 4 uses `--ticket requested`. The orchestrator files these, or lists them with a reason, in its final summary.
3. **Push**: invoke `/ccmagic:push` with the autonomous grounding block prepended (it commits the grouped fixes and pushes; if push returns `needs-human`, propagate that and skip step 4). Replies come after the push because a `fixed` reply must cite a pushed commit.
4. **Reply on every triaged thread with `ccm-pr-reply`**, using the response templates in `${CLAUDE_SKILL_DIR}/triage-guide.md` for the body. The script appends the disposition marker that `ccm-pr-threads` reads, replies to the thread's root comment, and resolves the thread for `fixed`:
   ```bash
   R="${CLAUDE_SKILL_DIR}/../../bin/ccm-pr-reply"   # or bare `ccm-pr-reply` on PATH
   "$R" {PR} {comment_id} --disposition fixed    --commit {sha that fixed it} --body "..."
   "$R" {PR} {comment_id} --disposition declined --body "..."
   "$R" {PR} {comment_id} --disposition answered --body "..."
   "$R" {PR} {comment_id} --disposition deferred --ticket {TICKET-ID} --body "..."
   ```
   Find the fixing commit with `git log --format=%H -1 -- {path}` after the push. The `--commit` must touch the thread's file; if the fix landed only in another file, cite a commit that touches the thread's file too, or reply `answered` and explain where the fix is. The thread then stays open for the orchestrator to see, which is the honest state. A non-zero exit means the reply was refused or failed; the thread stays open, and the orchestrator's next pass sees it. Never hand-write the marker or reply with plain `gh api` in autonomous mode: a reply without a marker leaves the thread open by design.

   Questions and comments in the general PR conversation (not line threads) get a normal `gh pr comment` reply; they don't count toward open threads.

### Behavior at each human-gate

- **Step 4d (Conflicting reviewers):** do not ask. Conventions already win in this skill — if a project convention decides the conflict, take that side automatically and cite it in the reply. Only a **genuine tie** (no convention applies) → `needs-human` (the `reason` names the `file:line` and both positions).
- **Step 4c (`defer` / out-of-scope verdict):** do not ask. Default action is **create a follow-up ticket** for each deferred/out-of-scope item; **under prompt-relay or when orchestrated**, record it as a short description in `follow_ups:` instead (contract §7 `file_followup`, §8).

### Handshake (emit last, in autonomous mode)

```
status: done | needs-human
reason: applied {A} / declined {D} / deferred {F}   (or the blocking tie on needs-human)
follow_ups: [<follow-up ticket ids filed, or short descriptions when orchestrated or under prompt-relay>]
```

`done` = this pass's fixes are applied, replies posted, follow-ups filed (or recorded as short descriptions when orchestrated or under prompt-relay), and the branch pushed. `needs-human` = a genuine reviewer tie (or a fix that can't be made safely) surfaced; if top-level, route-and-stop (park to `needs_human_state`, or `needs_human_label` if that state doesn't exist — on GitHub create the label first if missing; comment) before emitting — otherwise hand the handshake to the parent. **Under prompt-relay** (contract §7), that top-level park applies contract §4's *Under the prompt-relay transport* adjustments — no state move or label, parked note to the PR only, emitted (with `Requested state: {needs_human_state}`) wrapped in the §7 final-message delimiters as your final output. The parent orchestrator recomputes overall "clean" (CI green + zero unresolved actionable threads) after CI and any new bot review land.

## Execution

Begin immediately when invoked:

1. **Fetch** — Get the PR, all comments, and review state
2. **Load conventions** — Read project convention files
3. **Read threads** — `ccm-pr-threads` returns them already grouped
4. **Classify** — Assign severity to each comment (must-fix / should-fix / style / question)
5. **Verify** — Read actual code for every actionable comment. Check if the concern is valid, already handled, or contradicts conventions
6. **Detect conflicts** — Flag contradictory reviewer feedback and ask user to decide
7. **Group** — Batch verified fixes by file for efficient implementation
8. **Plan** — Create TodoWrite entries grouped by file
9. **Report** — Present the full triage with fix groups
10. **Suggest validation** — Recommend post-fix checks

**Bias toward action.** Reviewers took time to leave feedback — respect that by fixing legitimate issues rather than punting them. A PR that addresses all reasonable feedback ships cleaner code and builds reviewer trust. Only defer when the work truly doesn't fit this PR's scope. But always verify first: read the code, check the conventions, and confirm the concern is real before committing to a fix.
