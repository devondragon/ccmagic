---
name: settings
user-invocable: true
allowed-tools: Read(*), Write(*), AskUserQuestion(*)
description: Configure CCMagic preferences (tracker, QA workflow, ticket regex)
model: haiku
---

# ccmagic Settings

Configure persistent ccmagic preferences for this project. Settings live in `.claude/ccmagic.local.md` (which is also read by the tracker-aware skills).

## Process

### 1. Load Current Settings

Check if `.claude/ccmagic.local.md` exists. If so, read its YAML frontmatter and display the current values.

```
Current Settings (.claude/ccmagic.local.md):
- Tracker:               {linear | github | jira | auto}
- Ticket URL base:       {ticket_url_base}
- Ticket ID regex:       {ticket_id_regex}
- GitHub repo:           {github_repo or "auto-detect"}
- Default QA workflow:   {true | false}
- QA label (GitHub):     {qa_label or "(unset)"}
```

If the file doesn't exist, say so and offer to create it via this skill.

### 2. Gather Preferences

Use `AskUserQuestion` to set each knob:

#### Tracker

```
Which ticket tracker does this project use?
```
Options:
- **auto** (Recommended) — Detect at runtime via MCP/CLI availability and branch hints. Best for projects that switch trackers or have ambiguous setups.
- **linear** — Pin Linear. Requires a Linear MCP server to be connected.
- **github** — Pin GitHub Issues. Requires `gh` CLI and authentication.
- **jira** — Pin JIRA. Requires an Atlassian MCP server.

#### Ticket URL base

Ask for the URL prefix used in ticket links. Examples:
- Linear: `https://linear.app/yourteam/issue`
- JIRA: `https://your-org.atlassian.net/browse`
- GitHub: `https://github.com/owner/repo/issues`

#### Ticket ID regex

```
Ticket ID format regex?
```
Options:
- **Default `[A-Z][A-Z0-9]+-[0-9]+`** (Recommended) — Matches Linear and JIRA IDs. GitHub integers are recognized separately.
- **Custom** — Provide a regex specific to your team's ticket format.

#### GitHub repo (only if tracker is `github` or `auto`)

```
GitHub repo as owner/repo? (Leave blank to auto-detect via `gh repo view`.)
```

#### Default QA workflow

```
Should /ccmagic:finish-ticket default to the QA disposition?
```
Options:
- **No** (Recommended) — Default is "Done". Use `--qa` to opt into the QA path when needed.
- **Yes** — Default is the QA path. Tickets get moved to a QA state and reassigned automatically.

#### QA label (GitHub only)

```
For GitHub QA path, which label should be applied when finishing a ticket?
```
Skip this question entirely if the tracker isn't GitHub. Otherwise prompt for a label name (e.g. `needs-qa`).

### 3. Write Settings File

Save configuration to `.claude/ccmagic.local.md` as YAML frontmatter (mirroring `docs/ccmagic.local.md.example`):

```markdown
---
tracker: {chosen}
ticket_url_base: {url}
ticket_id_regex: "{regex}"
github_repo: {owner/repo or omit}
default_qa_workflow: {true|false}
qa_label: {label or omit}
---

# ccmagic project settings

These settings were configured via `/ccmagic:settings`. Edit this file directly or re-run the skill to change them.
```

If the file already existed with a markdown body below the frontmatter, **preserve the body** — replace only the frontmatter block.

### 4. Confirm

Display the saved configuration:

```
Saved to .claude/ccmagic.local.md.

Active Configuration:
- Tracker:              {tracker}
- Ticket URL base:      {url}
- Ticket ID regex:      {regex}
- GitHub repo:          {repo or "auto-detect"}
- Default QA workflow:  {true|false}

These settings are used by:
- /ccmagic:work-ticket   (tracker resolution, ticket lookup, branch naming)
- /ccmagic:finish-ticket (disposition default, tracker comments)
- /ccmagic:review-ticket (ticket context for grounded review)

Run /ccmagic:settings again to change, or edit .claude/ccmagic.local.md directly.
```

## Notes

- Settings live in `.claude/ccmagic.local.md`, which should be committed to the repo (so the team shares config) unless you have a reason to keep it local. Add to `.gitignore` if it contains secrets.
- For most non-tracker preferences (review threshold, agent model, etc.), pass them as flags to the relevant skill — ccmagic deliberately keeps the persistent config small.
- Haiku model is sufficient for this configuration task.
