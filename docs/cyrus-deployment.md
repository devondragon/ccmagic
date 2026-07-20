# Deploying auto-ticket inside Cyrus

How to run `/ccmagic:auto-ticket` unattended inside [Cyrus](https://github.com/cyrusagents/cyrus) — a Dockerized, Linear-triggered Claude Code worker. Cyrus assigns an issue, spins up a container with a fresh worktree, and runs a Claude Code session against it.

That container **does** provide the official hosted **Linear MCP** (`https://mcp.linear.app/mcp`, authed with the workspace OAuth token), so the **`mcp` transport is primary** — the ticket lifecycle reads and writes Linear directly via `mcp__linear__*` (verified end-to-end 2026-07-19: a FullAuto ticket ran implement → review → merge → Done entirely over MCP; and again 2026-07-20 across a 3-ticket smoke test). ccmagic's **prompt-relay transport** (`skills/auto-ticket/autonomous-contract.md` §7) remains the **fallback**: it covers the brief window at session start where Cyrus's non-blocking MCP is still connecting, and any other headless harness with no Linear MCP at all.

> **This is a reference for the actual `server.tr0n.io` deployment.** It is more concrete than the companion blog post ("FullAuto: Wiring ccmagic's auto-ticket into Cyrus"), which generalizes these steps. Where stock Cyrus can't do something through config, this deployment carries a small **build-time source patch** — those are documented in full below.

## Architecture at a glance

Three things make FullAuto work in-container; two of them are build-time patches to `cyrus-edge-worker` because stock Cyrus has no config surface for them:

| Concern | Mechanism | Where |
|---|---|---|
| `FullAuto` label → auto-ticket template on any repo | **Build-time patch** to `PromptBuilder.js` | `apply-fullauto-patch.cjs` |
| Plugin dir readable by the session (SDK read-deny) | **Build-time patch** to `EdgeWorker.js` (`allowedDirectories`) | `apply-pluginread-patch.cjs` |
| Plugin dir readable by the session (bwrap FS sandbox) | `sandbox.filesystem.allowRead` | `~/.claude/settings.json` |
| Linear read/write | `mcp__linear` in each repo's `allowedTools` | `~/.cyrus/config.json` |
| Deterministic tracker detection | `tracker: linear` pin | `~/.claude/ccmagic.local.md` (global) |
| CI status under a fine-grained PAT | Actions-API / commit-status fallback (ccmagic ≥ v3.6.0) + token read perms | ccmagic skill + GitHub token settings |

The image is built from a small Docker context (Dockerfile + `docker-compose.yml`) that installs `cyrus-ai` from **npm at a pinned version**, then applies the two codemods. Both codemods **abort the build** if their upstream anchors have moved, so a `cyrus-ai` bump can never silently drop the feature — bump deliberately and re-verify the patches.

## Build-time patch 1 — FullAuto label routing (`PromptBuilder.js`)

Stock Cyrus routes issues to prompts by Linear label via `labelPrompts` in `~/.cyrus/config.json`, but `labelPrompts` **only maps labels onto Cyrus's built-in preset modes** (`scoper`, `debugger`, `builder`). There is no config key that binds an arbitrary `FullAuto` label to a custom prompt template — so this cannot be done through configuration alone.

The patch adds a global, case-insensitive `FullAuto` handler with two edits to `cyrus-edge-worker/dist/PromptBuilder.js`:

1. `determineSystemPromptFromLabels()` — a `FullAuto` label returns `undefined`, opting the issue out of role-based routing so it falls through to the standard issue-context path (mirrors the existing hardcoded `orchestrator` behavior).
2. `buildIssueContextPrompt()` — a `FullAuto` label forces `templatePath = process.env.CYRUS_FULLAUTO_TEMPLATE` (else the default `/home/cyrus/.cyrus/ccmagic-auto-ticket-template.md`), regardless of the repo's own `promptTemplatePath`.

Net: a `FullAuto` label runs ccmagic `/auto-ticket` on **any** repo; no label → normal Cyrus flow; **zero per-repo config**. The Dockerfile runs `apply-fullauto-patch.cjs` right after `npm install -g cyrus-ai@<pinned>`, then `node --check`s the patched file.

## Build-time patch 2 — plugin-dir read access (`EdgeWorker.js`)

ccmagic skills read support files from their own skill directory at runtime — `auto-ticket` loads its shared `autonomous-contract.md` this way. The plugin lives under a home path (`~/.cyrus/user-skills-plugin`), and **two independent layers** block reads there:

- **The Claude Code SDK's home-directory read-deny** (`buildHomeDirectoryDisallowedTools`) — blocks the `Read` tool.
- **The bubblewrap filesystem sandbox** — each session runs inside bwrap with its own read allowlist.

Granting one without the other still strands the run (a fork hits `File is in a directory that is denied by your permission settings` reading its contract). Both are fixed:

1. `apply-pluginread-patch.cjs` patches `EdgeWorker.js` `buildAgentRunnerConfig()` (the single choke point all platforms funnel through) to add the plugin dirs to `allowedDirectories` — which both **grants** `Read` and **exempts** the path from the home-dir deny. Default dirs (override via `CYRUS_EXTRA_READ_DIRS`, colon-separated): `/home/cyrus/.cyrus/user-skills-plugin` and `/home/cyrus/.cyrus/cyrus-skills-plugin`. Writes to the plugin dir stay blocked by the sandbox `allowWrite` list (defense in depth).
2. `~/.claude/settings.json` lists the plugin dir under `sandbox.filesystem.allowRead`, e.g.:

   ```json
   {
     "sandbox": {
       "enabled": true,
       "filesystem": {
         "allowWrite": ["/home/cyrus/.cyrus/repos", "/home/cyrus/.cyrus/worktrees"],
         "allowRead": [
           "/home/cyrus/.cyrus/user-skills-plugin",
           "/home/cyrus/.claude/ccmagic.local.md"
         ]
       }
     }
   }
   ```

## Configuration prerequisites

1. **ccmagic installed.** On this instance ccmagic is installed **once, globally** at `~/.cyrus/user-skills-plugin` (Cyrus's `SkillsPluginResolver` loads `user-skills-plugin` + `cyrus-skills-plugin` for every session), so all repos get it with no per-repo install. Update path: `docker exec cyrus git -C /home/cyrus/.cyrus/user-skills-plugin pull` (skills are read per session — no restart needed unless a new skill/agent/config key was added).

2. **Tracker pinned to `linear`.** A **global** `~/.claude/ccmagic.local.md` with `tracker: linear` covers every repo. The pin makes detection deterministic in-container, where there is no Linear MCP to probe and an `ENG-123`-shaped ID is otherwise ambiguous between Linear and JIRA. `github_repo:` is optional — ccmagic reads it from the git remote — so the global file omits it; set it per-repo only where you want to be explicit. The same file works unmodified on a laptop.

   ```yaml
   # ~/.claude/ccmagic.local.md  (or per-repo at .claude/ccmagic.local.md)
   ---
   tracker: linear
   ---
   ```

3. **`allowedTools` must include `mcp__linear`.** A verbatim `allowedTools` override in Cyrus config *replaces* the platform default (`LINEAR_DEFAULT_ALLOWED_TOOLS`, which includes `mcp__linear`) — it does not extend it — so an override that omits `mcp__linear` silently strips Linear MCP and forces every run onto prompt-relay. The list granted per repo on this instance:

   ```json
   "allowedTools": [
     "Read", "Edit", "Write", "Bash", "Bash(git:*)", "Bash(gh:*)", "Bash(npm:*)",
     "Task", "Skill", "Glob", "Grep", "TodoWrite", "WebFetch", "WebSearch",
     "mcp__linear", "mcp__cyrus-tools", "mcp__cyrus-docs"
   ]
   ```

   `~/.cyrus/config.json` is **not** hot-reloaded; edits require `docker restart cyrus` (sessions persist and resume).

4. **`gh` authenticated — and mind the token type.** Verified on a live instance: `gh` is present and logged in via the `GH_TOKEN` environment variable. The entire PR/git/CI half of the cycle — branch, push, PR, review comments, merge — runs through `gh` exactly as on a laptop; only the Linear side changes transport.

   **Caveat (this instance uses a fine-grained PAT):** a fine-grained GitHub PAT **cannot read check runs authored by GitHub Apps** (GitHub Actions is an App; so are bot reviewers). `gh pr checks` returns `Resource not accessible by personal access token` (HTTP 403) even with `Checks: read` granted. ccmagic **v3.6.0+** handles this: the `auto-ticket` CI wait and the `finish-ticket` merge gate fall back to the **Actions API** (`gh run list` / `gh run watch`; green = every run `completed` with a `success`/`skipped`/`neutral` conclusion) and the **commit-status API** (`gh api commits/<sha>/status`), and **park** ("cannot read CI status") only when both are unreadable — an autonomous run never ends by asking a human. Grant the token `Actions: read` and `Commit statuses: read` (in addition to Contents + Pull requests write) for the fallback to work. If your required checks come from a third-party CI App rather than GitHub Actions, no fine-grained token can read them and those runs park rather than fake a green.

5. **Linear's GitHub integration with auto-close automation — required only under prompt-relay.** Under `mcp` (the primary path) `finish-ticket` moves the issue to Done directly via `mcp__linear__save_issue`, so no automation is needed. Under **prompt-relay** the agent never calls a state-transition API — it only emits state *intents* (`Requested state: Done`) — so the team's GitHub auto-close automation is what moves a merged ticket to Done; without it, a prompt-relay ticket stays in whatever state Cyrus set on assignment (typically In Progress).

## The prompt template (load-bearing)

Cyrus builds the prompt for each container run from a template. FullAuto uses the template at `CYRUS_FULLAUTO_TEMPLATE` (else the default path); the `ccmagic` repo also points `promptTemplatePath` at the same file. For that prompt to work with ccmagic it must do two things:

1. **Write the issue title + description to `.ccmagic-ticket.md` in the working directory, then invoke `/ccmagic:auto-ticket {{issue_identifier}}`.** `auto-ticket` is `context: fork` — it only ever sees its own arguments, not anything else in the top-level prompt. Sibling text ("the issue is already in the prompt somewhere") never reaches the fork; the handoff file does — parent and fork share the worktree, so `auto-ticket` reads the content from `.ccmagic-ticket.md` (contract §7 `fetch_ticket`) and `rm`s it afterward. This also makes prompt-relay an always-available floor regardless of how the MCP connection race plays out.
2. **Instruct the session to reproduce the skill's returned final-message block verbatim.** `auto-ticket` ends its output with a delimited block:

   ```
   === FINAL MESSAGE TO RELAY (reproduce verbatim) ===
   {the run summary or parked note}
   === END FINAL MESSAGE ===
   ```

   Cyrus relays the session's top-level final output to Linear as a comment — and the main-loop model can paraphrase or truncate a forked skill's return before that. The delimited block plus an explicit verbatim-repeat instruction are the two mitigations; the live test below confirms they hold.

Cyrus substitutes `{{issue_identifier}}`, `{{issue_title}}`, `{{issue_description}}`, `{{working_directory}}`, `{{branch_name}}`, and `{{base_branch}}` at build time. Copy-pasteable template:

```
First, write the ticket content to a handoff file the forked skill can read.
`/ccmagic:auto-ticket` runs as a forked skill and only sees its own invocation
arguments — not this prompt — so the ticket content must be handed off via a file
in the working directory, which the fork shares.

Write a file named `.ccmagic-ticket.md` in the working directory
({{working_directory}}) with exactly this content:
~~~
{{issue_title}}

{{issue_description}}
~~~

Then run:

/ccmagic:auto-ticket {{issue_identifier}}

Environment (already prepared by Cyrus — do not re-create the branch or worktree):
- Working directory: {{working_directory}}
- Branch: {{branch_name}}
- Base branch: {{base_branch}}

When the command finishes, its output ends with a block delimited by:
=== FINAL MESSAGE TO RELAY (reproduce verbatim) ===
...
=== END FINAL MESSAGE ===

Reproduce the contents of that block verbatim as your own final message —
do not summarize, paraphrase, or add commentary around it.
```

## What lands where

- **The PR** carries the detailed, near-real-time audit trail: commits, the PR description, review comments, CI status — everything `gh` can see and post, unchanged from a laptop run.
- **Linear** gets exactly one consolidated message per run: the run summary (or the parked note), including any `Requested state:` intent lines and a "Follow-ups to file" list of anything the run would have filed as a new ticket but couldn't (no create API under prompt-relay). There is no comment-by-comment progress in Linear — that's intentional (contract §7).

## Parking

When a run parks (`needs-human`) there is no automatic state move. Under `mcp`, `finish-ticket` can post the parked note and (optionally) set state; under prompt-relay the relayed parked note is the only signal. Either way the note says plainly that the run stopped and what decision it needs — a human (or a Cyrus-side lifecycle rule) acts on it. Don't mistake "state didn't change" for "nothing happened" — check the relayed comment.

## Testing before trusting it

1. **Laptop simulation first, no Cyrus needed.** Run `claude -p` with the Linear MCP left unconfigured, and a crafted prompt that embeds a fake ticket (title + description) plus the `/ccmagic:auto-ticket` invocation, following the template above. This exercises transport detection, fetch-from-handoff-file, the state-change no-ops, and final-message emission — most of the design — without touching a real ticket or container.
2. **Then one throwaway ticket on the live Cyrus instance.** The laptop simulation can't verify the one part it doesn't control: whether Cyrus's relay delivers the final message block to Linear **verbatim**, unparaphrased. Create a disposable Linear issue, label it `FullAuto`, let Cyrus run it end to end, and check the resulting Linear comment character-for-character against what the session actually returned.
