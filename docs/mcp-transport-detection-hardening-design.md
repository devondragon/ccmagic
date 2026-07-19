# MCP Transport-Detection Hardening — Design

## Context

ccmagic's autonomous ticket lifecycle (`/ccmagic:auto-ticket` and the
`work-ticket → review-ticket → pr-feedback → finish-ticket` skills) supports two
transports for the Linear side of a ticket:

- **`mcp`** — read/write Linear directly via a `mcp__*Linear*__*` MCP server.
- **`prompt-relay`** — for headless harnesses where the ticket is injected into
  the prompt and the run's final message is relayed back as a comment, with no
  Linear MCP available. Defined in `skills/auto-ticket/autonomous-contract.md` §7.

Prompt-relay was built for [Cyrus](https://github.com/cyrusagents/cyrus) on the
assumption that its containers have **no Linear MCP**. Live testing on a
self-hosted Cyrus instance disproved that assumption: Cyrus **does** provide the
official hosted Linear MCP (`https://mcp.linear.app/mcp`, authed with the
workspace OAuth token). Once the container was configured correctly (repo
`allowedTools` include `mcp__linear`; the plugin directory is readable), a full
auto-ticket run drove a ticket to Done and merged its PR **entirely over
`mcp__linear__*`** — reads, state transitions, comments, and the PR attachment.

So `mcp` is the correct primary transport on Cyrus. But the same test exposed a
detection defect that makes transport selection unreliable at session start.

## Problem

Cyrus registers the Linear MCP **non-blocking** (`MCP_CONNECTION_NONBLOCKING`):
it is a **remote** server whose tools are **deferred** (discoverable via
`ToolSearch`, not eagerly loaded). During the brief connection window at session
start, `mcp__linear__*` tools are not yet callable or ToolSearch-discoverable —
the session reports the server as *"still connecting."*

§7 condition (b) tests **instantaneous tool discoverability**
(*"no `mcp__*Linear*__*` tool is present in the session"*). During the connect
window this reads a *still-connecting* server as *absent*, so an early probe
falls to `prompt-relay`.

Observed in run BMC-204 (`agent-a1eb3e2e`, the first auto-ticket fork): it began
with *"transport is MCP (Linear MCP server is connected)"*, then ran ~12
`ToolSearch` queries for `mcp__linear__*`, all failing (*"still connecting … its
tools never became available"*), and concluded per §7(b) → `prompt-relay`. A
later fork, after the server finished connecting, found the tools and completed
the whole lifecycle over `mcp`. Two failure modes, one root cause:

1. **Cold-start false negative** — a *registered-but-connecting* server is
   misread as *absent*.
2. **Within-run inconsistency** — detection is re-run per sub-skill, so one
   cold-start fork can pick `prompt-relay` while its siblings pick `mcp`.

## Goals

- Detect the Linear MCP by **server presence**, not instantaneous tool
  discoverability, so a registered-but-connecting server resolves to `mcp`.
- Resolve transport **once per run** and have every sub-step inherit it.
- Keep `prompt-relay` as the fallback for genuinely MCP-less harnesses and for a
  server that never finishes connecting — never an infinite hang.
- Correct the documentation that asserts Cyrus has no Linear MCP.

## Non-goals

- **Not** removing prompt-relay — the connection race proves it is still a
  needed safety net.
- No changes to the GitHub/`gh` half of the lifecycle.
- No changes to Cyrus itself or to the FullAuto routing patch (both already in
  place on the instance).

## Design

### 1. Server-presence detection (`autonomous-contract.md` §7)

Rewrite condition (b) of the detection rule from tool discoverability to
**server availability**. A Linear MCP server is *available* to the session if
**any** of the following hold:

- a `mcp__*[Ll]inear*__*` tool is directly callable; **or**
- `mcp__*[Ll]inear*__*` tool names appear in the deferred / loadable tool list
  (discoverable via `ToolSearch`); **or**
- the session reports a Linear MCP server present but *"still connecting"* (or
  otherwise registered-but-not-yet-ready).

Revised rule:

> transport = `prompt-relay` when ALL of: (a) the tracker resolves to `linear`;
> (b) **no Linear MCP server is available to the session** (by the definition
> above); (c) ticket content was explicitly provided. Otherwise transport =
> `mcp`.

The `*Linear*` pattern is made **explicitly case-insensitive** (`*[Ll]inear*`)
so Cyrus's lowercase `mcp__linear__*` matches — the existing examples already
list a lowercase server (`mcp__plugin_linear_linear__`), so this only removes
ambiguity.

### 2. Bounded load-with-retry

When the tracker is `linear` and a server is *available but its tools are not yet
callable*, the skill must load the tools before use rather than concluding
absence. Skills have no `sleep` primitive, so "wait" is expressed as a **bounded
`ToolSearch` retry**:

- Attempt `ToolSearch` for `mcp__*linear*__get_issue` (and the other needed
  tools) up to **3 times**. The ToolSearch round-trips themselves provide the
  brief delay the async connect needs.
- If the tools resolve within the retries → `transport: mcp`.
- If a server was registered but its tools never load after the retries → fall
  to `prompt-relay` **gracefully** and note the anomaly in the run output
  (bounded; never an infinite hang). If ticket content was not injected, this
  degraded case is a setup error per the existing §7 `fetch_ticket` rule.

3 is a starting value chosen from the observed connect time (the server
connected well within one run); it is documented as tunable.

### 3. Grounding-block transport is authoritative

Today work/review/finish-ticket and pr-feedback each say transport is *"resolved
regardless of how the tracker was determined … apply the contract §7 detection
rule."* That instruction makes every sub-skill **re-detect**, which is the source
of the within-run inconsistency.

Change it to: **when a sub-skill is invoked with a grounding block that carries a
`transport:` value, it trusts that value and does not re-detect.** §7 detection
runs only when a skill is invoked **standalone** (no grounding block). The
orchestrator (`auto-ticket`) resolves transport once — using the hardened §7 with
the retry from §2 — and writes it into the grounding block (§2 of the contract),
so all sub-steps inherit a single, consistent decision.

### 4. Documentation corrections

- `docs/cyrus-deployment.md` — replace *"That container has no Linear MCP
  server"* with the accurate picture: Cyrus provides a hosted Linear MCP;
  **`mcp` is the primary transport, `prompt-relay` is the fallback** for the
  connect-window and for genuinely MCP-less harnesses. Document the two
  prerequisites discovered in testing: (i) each repo's `allowedTools` must
  include `mcp__linear` (a verbatim `allowedTools` override replaces Cyrus's
  default and drops it); (ii) the plugin directory must be readable by the
  session (Cyrus's home-directory read-deny otherwise blocks skills from reading
  their `${CLAUDE_SKILL_DIR}` support files).
- `docs/cyrus-prompt-relay-transport-design.md` — add a note at the top
  reframing prompt-relay as the fallback rather than the assumed-only path on
  Cyrus.
- `skills/doctor/SKILL.md` — keep the "a missing Linear MCP may be prompt-relay"
  note; add the "still connecting" nuance (a server can be present but not yet
  ready).

## Files changed

| File | Change |
|---|---|
| `skills/auto-ticket/autonomous-contract.md` | §7 detection rewrite (server-presence + case-insensitive pattern); bounded load-with-retry; note that the orchestrator writes resolved `transport:` into the grounding block |
| `skills/work-ticket/SKILL.md` | Step 0: grounding-block transport is authoritative; probe recognizes registered-but-connecting server + retry |
| `skills/review-ticket/SKILL.md` | Same Step-0 change |
| `skills/finish-ticket/SKILL.md` | Same Step-0 change |
| `skills/pr-feedback/SKILL.md` | Trust grounding-block transport |
| `skills/auto-ticket/SKILL.md` | Orchestrator resolves transport once via hardened §7 and records it in the grounding block |
| `skills/doctor/SKILL.md` | "still connecting" nuance |
| `docs/cyrus-deployment.md` | Correct the "no Linear MCP" claim; document the two prerequisites |
| `docs/cyrus-prompt-relay-transport-design.md` | Reframe prompt-relay as fallback |

## Testing & validation

Because the skills are agent instructions, validation is behavioral, run on the
live Cyrus instance plus a laptop:

1. **Cold-start Cyrus run** — delegate a throwaway FullAuto ticket; confirm the
   **first** auto-ticket fork resolves `transport: mcp` (no prompt-relay lean)
   and that no sub-step diverges. This is the direct regression test for the
   BMC-204 defect.
2. **Laptop connector case** — a repo with the claude.ai Linear connector
   (tools immediately available) still resolves `mcp` with no added latency.
3. **Genuinely MCP-less run** — a harness with no Linear server registered still
   falls to `prompt-relay` promptly (bounded retries, no long hang).

## Rollout / compatibility

- Pure skill-text + docs change; no new skills, agents, hook, or config keys.
- Backward compatible: the normal `mcp` path (immediately-available tools) and
  the genuine `prompt-relay` path are unchanged in outcome; only the
  registered-but-connecting window changes from a false `prompt-relay` to a
  correct `mcp`.
- Ships as a normal ccmagic version bump; on Cyrus it loads via the standard
  `git -C ~/.cyrus/user-skills-plugin pull` (no container restart).
