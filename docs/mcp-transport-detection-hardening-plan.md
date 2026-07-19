# MCP Transport-Detection Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make ccmagic resolve `transport: mcp` reliably when a Linear MCP server is registered but still connecting (Cyrus's non-blocking/deferred MCP), and resolve transport once per run so sub-steps never diverge.

**Architecture:** Pure skill-instruction + documentation edits. Redefine the §7 detection rule around *server availability* (with a bounded ToolSearch load-retry), make sub-skills trust the orchestrator's grounding-block `transport:` instead of re-detecting, and correct the docs that claim Cyrus has no Linear MCP.

**Tech Stack:** Markdown skill files (`skills/*/SKILL.md`, `skills/auto-ticket/autonomous-contract.md`), plugin manifests (`.claude-plugin/*.json`), docs. No code, no unit tests — validation is behavioral on a live Cyrus instance.

## Global Constraints

- Design spec: `docs/mcp-transport-detection-hardening-design.md` (verbatim source of truth for behavior).
- Keep `SKILL.md` files under 500 lines (project rule); these edits are net-neutral to small-positive in size.
- Do **not** remove prompt-relay — it is the fallback.
- Do **not** touch the GitHub/`gh` half of the lifecycle, Cyrus itself, or the FullAuto routing patch.
- Conventional commits: `{type}: {imperative summary}` (no ticket ID; ccmagic uses GitHub issues and this has none). Types: `docs`, `fix`, `chore`.
- Branch: `feature/mcp-transport-detection-hardening` (already created; the design doc is already committed there as `271744e`).
- The Linear-MCP availability pattern is **case-insensitive** and must match all of: `mcp__claude_ai_Linear__*`, `mcp__plugin_linear_linear__*`, and Cyrus's lowercase `mcp__linear__*`.

---

### Task 1: Rewrite §7 detection around server availability

**Files:**
- Modify: `skills/auto-ticket/autonomous-contract.md` (the paragraph under `### Detection`, currently line ~171)

**Interfaces:**
- Produces: the canonical transport-detection rule that every consumer skill (Task 2) references as "contract §7". Key terms other tasks rely on verbatim: **"Linear MCP server is available"**, **"load-with-retry"**, **"still connecting"**.

- [ ] **Step 1: Replace the detection paragraph**

Find this exact paragraph (immediately below the `### Detection` heading):

```
transport = `prompt-relay` when ALL of: (a) the tracker resolves to `linear`; (b) no `mcp__*Linear*__*` tool is present in the session; (c) ticket content (title + description) was explicitly provided in the invocation arguments or grounding block. Otherwise transport = `mcp` and behavior is unchanged. The check runs *before* any "none available → stop" branch. Content-presence (c) is a *transport* signal, not a tracker tiebreaker — condition (a) still resolves the tracker via config or the detection cascade, so a headless deployment with no MCPs should pin `tracker: linear` (or a Linear-shaped `ticket_url_base:`) to keep (a) deterministic.
```

Replace it with:

```
transport = `prompt-relay` when ALL of: (a) the tracker resolves to `linear`; (b) **no Linear MCP server is available to the session** (definition below); (c) ticket content (title + description) was explicitly provided in the invocation arguments or grounding block. Otherwise transport = `mcp`. The check runs *before* any "none available → stop" branch. Content-presence (c) is a *transport* signal, not a tracker tiebreaker — condition (a) still resolves the tracker via config or the detection cascade, so a headless deployment with no MCP should pin `tracker: linear` (or a Linear-shaped `ticket_url_base:`) to keep (a) deterministic.

**A Linear MCP server is "available"** if ANY of these hold (the pattern is **case-insensitive** — Cyrus registers its server lowercase as `mcp__linear__*`):

1. a `mcp__*[Ll]inear*__*` tool (e.g. `mcp__linear__get_issue`, `mcp__claude_ai_Linear__get_issue`) is directly callable; or
2. `mcp__*[Ll]inear*__*` tool names appear in the session's deferred / loadable tool list (discoverable via `ToolSearch`); or
3. the session reports a Linear MCP server that is registered but **still connecting** (e.g. a system-reminder naming a `linear` server as connecting).

A registered-but-connecting server (signals 2–3) is **present, not absent** — do not fall to prompt-relay on the strength of a tool not being *immediately* callable.

**Load-with-retry.** When the server is available by signal 2 or 3 but its tools are not yet callable, load them before use: run `ToolSearch` for `mcp__*linear*__get_issue` (plus the other tools the step needs) up to **3 attempts** — the round-trips themselves cover the asynchronous connect. If the tools resolve, `transport = mcp`. If a server was registered but its tools never load after 3 attempts, fall back to `prompt-relay` **only when ticket content was injected** (condition (c)), and note the degraded transport in the run output; if content was not injected, stop with the §7 `fetch_ticket` setup-error (never hang, never guess). The retry bound of 3 is tunable.
```

- [ ] **Step 2: Verify the edit**

Run: `grep -n "Linear MCP server is .available\|Load-with-retry\|still connecting" skills/auto-ticket/autonomous-contract.md`
Expected: three matches (the definition, the retry heading, the "still connecting" signal). And `grep -c "no \`mcp__\*Linear\*__\* tool is present" skills/auto-ticket/autonomous-contract.md` → `0` (old wording gone).

- [ ] **Step 3: Commit**

```bash
git add skills/auto-ticket/autonomous-contract.md
git commit -m "fix: detect Linear MCP by server availability, add load-with-retry"
```

---

### Task 2: Align consumer skills with the hardened §7

Every skill that resolves or consumes transport must (a) trust the orchestrator's grounding-block `transport:` instead of re-detecting, and (b) recognize a registered-but-connecting server in its MCP-probe wording.

**Files:**
- Modify: `skills/work-ticket/SKILL.md` (probe line ~37; shared paragraph ~48)
- Modify: `skills/review-ticket/SKILL.md` (probe line ~30; shared paragraph ~36)
- Modify: `skills/finish-ticket/SKILL.md` (probe line ~40; shared paragraph ~50)
- Modify: `skills/pr-feedback/SKILL.md` (line ~232)
- Modify: `skills/auto-ticket/SKILL.md` (Step 0, line ~58)
- Modify: `skills/doctor/SKILL.md` (note, line ~66)

**Interfaces:**
- Consumes: the §7 rule and terms from Task 1.
- Produces: consistent "trust the grounding-block transport" behavior across all sub-skills.

- [ ] **Step 1: Replace the shared re-detect paragraph in all three ticket skills**

This paragraph is **byte-identical** in `skills/work-ticket/SKILL.md`, `skills/review-ticket/SKILL.md`, and `skills/finish-ticket/SKILL.md`. Find it in each:

```
Transport is resolved regardless of how the tracker was determined: whenever the tracker is `linear` — pinned in config or detected via the cascade — apply the contract §7 detection rule (`skills/auto-ticket/autonomous-contract.md` §7) to set `transport: mcp | prompt-relay`. A pinned `tracker:` skips the cascade above, never transport resolution — so a standalone headless run against a pinned-Linear repo still resolves `prompt-relay` (provided the ticket content was injected — §7 condition (c)) instead of reaching for a nonexistent MCP.
```

Replace it (in each of the three files) with:

```
Transport resolution depends on how this skill was invoked. **When invoked with a grounding block that carries a `transport:` value (orchestrated/autonomous runs — contract §2), trust that value and do not re-detect** — the orchestrator resolved transport once for the whole run, so every sub-step stays consistent. **Only when running standalone (no grounding block)** do you resolve transport yourself: whenever the tracker is `linear` — pinned in config or detected via the cascade — apply the contract §7 detection rule (`skills/auto-ticket/autonomous-contract.md` §7, including its server-availability rule and load-with-retry) to set `transport: mcp | prompt-relay`. A pinned `tracker:` skips the cascade above, never standalone transport resolution.
```

- [ ] **Step 2: Update the Linear MCP probe wording in the three ticket skills**

In `skills/work-ticket/SKILL.md`, find:

```
   - Linear MCP: any tool matching `mcp__*Linear*__get_issue` (e.g. `mcp__claude_ai_Linear__get_issue`, `mcp__plugin_linear_linear__get_issue`).
```

Replace with:

```
   - Linear MCP: a Linear MCP **server** available to the session — case-insensitive `mcp__*[Ll]inear*__get_issue` (e.g. `mcp__claude_ai_Linear__get_issue`, `mcp__plugin_linear_linear__get_issue`, or Cyrus's lowercase `mcp__linear__get_issue`), **including a server that is registered but still connecting** (see contract §7 for the full availability rule + load-with-retry).
```

In `skills/review-ticket/SKILL.md`, find:

```
   - **MCP probe:** Linear MCP (`mcp__*Linear*__get_issue`), Atlassian/JIRA MCP (`mcp__*atlassian*__*` or `mcp__*Atlassian*__*`).
```

Replace with:

```
   - **MCP probe:** Linear MCP — a server available to the session (case-insensitive `mcp__*[Ll]inear*__get_issue`, incl. Cyrus's `mcp__linear__` and a still-connecting server; see contract §7); Atlassian/JIRA MCP (`mcp__*atlassian*__*` or `mcp__*Atlassian*__*`).
```

In `skills/finish-ticket/SKILL.md`, find:

```
   - Linear MCP: any tool matching `mcp__*Linear*__get_issue`.
```

Replace with:

```
   - Linear MCP: a server available to the session — case-insensitive `mcp__*[Ll]inear*__get_issue` (incl. Cyrus's `mcp__linear__` and a still-connecting server; see contract §7).
```

- [ ] **Step 3: Trust the grounding-block transport in pr-feedback**

In `skills/pr-feedback/SKILL.md`, find:

```
**Tracker for follow-ups.** Resolve the tracker with the same cascade as `/ccmagic:work-ticket` (or reuse `tracker:` / `ticket:` if the grounding block carries them).
```

Replace with:

```
**Tracker for follow-ups.** Resolve the tracker with the same cascade as `/ccmagic:work-ticket` (or reuse `tracker:` / `ticket:` / `transport:` if the grounding block carries them — trust the grounding block's `transport:` rather than re-detecting).
```

- [ ] **Step 4: Make auto-ticket resolve transport once via the hardened rule**

In `skills/auto-ticket/SKILL.md`, find:

```
**Then resolve the transport:** default `transport: mcp`, then apply the contract §7 detection rule *before* the none-available stop below — a headless Linear run resolves `tracker: linear`, `transport: prompt-relay` instead of stopping.
```

Replace with:

```
**Then resolve the transport once for the whole run:** default `transport: mcp`, then apply the contract §7 detection rule (server-availability + load-with-retry) *before* the none-available stop below — a Linear run with an MCP server available (even one still connecting) resolves `transport: mcp`; a headless Linear run with no MCP server at all resolves `transport: prompt-relay` instead of stopping. This single resolved value goes into the grounding block (Step 5); every sub-skill inherits it and does not re-detect.
```

- [ ] **Step 5: Add the still-connecting nuance to doctor**

In `skills/doctor/SKILL.md`, find:

```
> **Linear MCP:** Verify in Claude Code MCP settings that a Linear server is connected. Tool names look like `mcp__claude_ai_Linear__*` or `mcp__plugin_linear_linear__*`.
```

Replace with:

```
> **Linear MCP:** Verify in Claude Code MCP settings that a Linear server is connected. Tool names look like `mcp__claude_ai_Linear__*`, `mcp__plugin_linear_linear__*`, or (self-hosted Cyrus) `mcp__linear__*`. A server can be *registered but still connecting* at session start — that is a present MCP (auto-ticket loads its tools with a bounded retry), not a missing one.
```

- [ ] **Step 6: Verify the edits**

Run: `grep -rn "trust that value and do not re-detect" skills/work-ticket skills/review-ticket skills/finish-ticket`
Expected: one match in each of the three files.
Run: `grep -rc "Transport is resolved regardless of how the tracker" skills/`
Expected: `0` in every file (old paragraph gone everywhere).
Run: `grep -rn "still connecting" skills/work-ticket skills/review-ticket skills/finish-ticket skills/doctor skills/auto-ticket`
Expected: at least one match per file.

- [ ] **Step 7: Confirm no SKILL.md exceeded 500 lines**

Run: `wc -l skills/work-ticket/SKILL.md skills/review-ticket/SKILL.md skills/finish-ticket/SKILL.md skills/pr-feedback/SKILL.md skills/auto-ticket/SKILL.md skills/doctor/SKILL.md`
Expected: every count < 500.

- [ ] **Step 8: Commit**

```bash
git add skills/work-ticket/SKILL.md skills/review-ticket/SKILL.md skills/finish-ticket/SKILL.md skills/pr-feedback/SKILL.md skills/auto-ticket/SKILL.md skills/doctor/SKILL.md
git commit -m "fix: trust grounding-block transport; recognize connecting Linear MCP"
```

---

### Task 3: Correct the Cyrus docs

**Files:**
- Modify: `docs/cyrus-deployment.md` (intro line 3; prerequisites 5–9)
- Modify: `docs/cyrus-prompt-relay-transport-design.md` (top note)

- [ ] **Step 1: Rewrite the "no Linear MCP" claim in the deployment doc intro**

In `docs/cyrus-deployment.md`, find:

```
That container has **no Linear MCP server** — Linear is reached only through the prompt Cyrus builds and the output Cyrus relays back as a comment. ccmagic's **prompt-relay transport** (`skills/auto-ticket/autonomous-contract.md` §7) is the generic mechanism that carries the Linear side of the ticket lifecycle over that constraint; Cyrus is simply the motivating, concrete deployment.
```

Replace with:

```
That container **does** provide the official hosted **Linear MCP** (`https://mcp.linear.app/mcp`, authed with the workspace OAuth token), so the **`mcp` transport is primary** — the ticket lifecycle reads and writes Linear directly via `mcp__linear__*` (verified end-to-end 2026-07-19: a FullAuto ticket ran implement → review → merge → Done entirely over MCP). ccmagic's **prompt-relay transport** (`skills/auto-ticket/autonomous-contract.md` §7) remains as the **fallback**: it covers the brief window at session start where Cyrus's non-blocking MCP is still connecting, and any other headless harness with no Linear MCP at all.

**Two prerequisites make `mcp` work in-container** (both were required in testing): (i) each repo's `allowedTools` must include `mcp__linear` — a verbatim `allowedTools` override in Cyrus config *replaces* the platform default and silently drops it; (ii) the plugin directory (`~/.cyrus/user-skills-plugin`) must be readable by the session — Cyrus's home-directory read-deny otherwise blocks skills from reading their `${CLAUDE_SKILL_DIR}` support files (e.g. `autonomous-contract.md`), which strands auto-ticket.
```

- [ ] **Step 2: Note that direct state moves are the mcp path in prerequisite 1**

In `docs/cyrus-deployment.md`, find:

```
1. **Linear's GitHub integration, with auto-close automation enabled on the team.** This is what moves the issue to Done when the linked PR merges. The agent never calls a Linear state-transition API under prompt-relay — it only emits state *intents* (`Requested state: Done`) in its final message. Without this automation enabled, a merged ticket stays stuck in whatever state Cyrus set on assignment (typically In Progress).
```

Replace with:

```
1. **Linear's GitHub integration with auto-close automation — required only under prompt-relay.** Under the `mcp` transport (the primary path) `finish-ticket` moves the issue to Done directly via `mcp__linear__save_issue`, so no automation is needed. Under **prompt-relay** the agent never calls a state-transition API — it only emits state *intents* (`Requested state: Done`) — so the team's GitHub auto-close automation is what moves a merged ticket to Done; without it, a prompt-relay ticket stays in whatever state Cyrus set on assignment (typically In Progress).
```

- [ ] **Step 3: Add a top note to the transport design doc**

In `docs/cyrus-prompt-relay-transport-design.md`, add immediately after the first heading line (top of file) a blockquote:

```
> **Update 2026-07-19:** The founding assumption below — that Cyrus containers have no Linear MCP — proved wrong. Cyrus *does* register the official hosted Linear MCP; the `mcp` transport is primary and was verified end-to-end. Prompt-relay is the **fallback** for the non-blocking-connect window and for genuinely MCP-less harnesses. See `docs/cyrus-deployment.md` and `docs/mcp-transport-detection-hardening-design.md`.
```

- [ ] **Step 4: Verify**

Run: `grep -n "no Linear MCP server" docs/cyrus-deployment.md`
Expected: `0` matches.
Run: `grep -n "mcp. transport is primary\|Update 2026-07-19" docs/cyrus-deployment.md docs/cyrus-prompt-relay-transport-design.md`
Expected: the intro rewrite + the design-doc note both present.

- [ ] **Step 5: Commit**

```bash
git add docs/cyrus-deployment.md docs/cyrus-prompt-relay-transport-design.md
git commit -m "docs: correct Cyrus 'no Linear MCP' claim; mcp primary, relay fallback"
```

---

### Task 4: Version bump

**Files:**
- Modify: `.claude-plugin/plugin.json` (`"version"`)
- Modify: `.claude-plugin/marketplace.json` (`"version"`)

- [ ] **Step 1: Bump 3.4.0 → 3.5.0 in both manifests**

In `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, change `"version": "3.4.0"` to `"version": "3.5.0"`.

- [ ] **Step 2: Verify**

Run: `grep -h '"version"' .claude-plugin/plugin.json .claude-plugin/marketplace.json`
Expected: both show `3.5.0`.

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore: bump version to 3.5.0"
```

---

### Task 5: Behavioral validation on the live Cyrus instance

No unit tests exist for markdown skills; this task validates the three cases from the spec. Requires `ssh server.tr0n.io` access to the Cyrus host.

**Files:** none (validation only).

- [ ] **Step 1: Deploy the branch into the container's plugin clone**

The container loads skills from `~/.cyrus/user-skills-plugin` (tracks `origin/main`). To test before merge, check out this branch there:

```bash
ssh server.tr0n.io "docker exec cyrus git -C /home/cyrus/.cyrus/user-skills-plugin fetch origin && docker exec cyrus git -C /home/cyrus/.cyrus/user-skills-plugin checkout feature/mcp-transport-detection-hardening"
```
Expected: branch checked out. (No container restart needed — skills load per session.)

- [ ] **Step 2: Cold-start Cyrus run (the regression test)**

Create a throwaway Linear issue labeled `NodeTestRepo` + `FullAuto` (trivial doc task) and delegate it to the Cyrus agent. After it completes, parse the forks:

```bash
ssh server.tr0n.io "docker exec cyrus sh -lc 'grep -rl \"transport\" /home/cyrus/.claude/projects/-home-cyrus--cyrus-worktrees-<ISSUE>/ '"
```
Expected: **every** fork that resolves transport picks `mcp`; **no** fork leans `prompt-relay` with a "still connecting / not available" rationale. The ticket reaches Done with state moves via `mcp__linear__*` (confirm on the Linear side).

- [ ] **Step 3: MCP-less sanity (no regression to the fallback)**

Confirm on a laptop/checkout with **no** Linear MCP configured (and ticket content injected) that a standalone `work-ticket` still resolves `transport: prompt-relay` promptly — the bounded retry must not hang. This can be a reasoning check against the edited §7 wording if a true MCP-less harness isn't handy.

- [ ] **Step 4: Restore the container to main after validation**

```bash
ssh server.tr0n.io "docker exec cyrus git -C /home/cyrus/.cyrus/user-skills-plugin checkout main && docker exec cyrus git -C /home/cyrus/.cyrus/user-skills-plugin pull"
```
(Run after the branch merges so the container tracks `main` at the merged commit.)

- [ ] **Step 5: Open the PR**

Push the branch and open a PR titled `fix: harden MCP transport detection for deferred/async Linear MCP`, linking the design + plan docs. (Push/PR only on explicit user go-ahead per repo policy.)

---

## Self-Review

**Spec coverage:** §1 server-presence detection → Task 1. §2 load-with-retry → Task 1 (Step 1, "Load-with-retry"). §3 grounding-block authoritative → Task 2 (Steps 1, 3, 4). §4 doc corrections → Task 3. Case-insensitive pattern → Tasks 1–2. Validation plan (3 cases) → Task 5. Version bump (rollout) → Task 4. All spec sections mapped.

**Placeholder scan:** every edit shows exact old→new text; no TBD/TODO; `<ISSUE>` in Task 5 Step 2 is a runtime issue id the operator fills in, not an unspecified design value.

**Consistency:** the "Linear MCP server is available", "load-with-retry", and "still connecting" terms defined in Task 1 are the exact strings referenced by Tasks 2–3 and grepped in the verify steps. The shared paragraph old-text in Task 2 Step 1 matches the confirmed byte-identical source in all three files.
