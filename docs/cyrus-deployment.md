# Deploying auto-ticket inside Cyrus

How to run `/ccmagic:auto-ticket` unattended inside [Cyrus](https://github.com/cyrusagents/cyrus) — a Dockerized, Linear-triggered Claude Code worker. Cyrus assigns an issue, spins up a container with a fresh worktree, and runs a Claude Code session against it. That container has **no Linear MCP server** — Linear is reached only through the prompt Cyrus builds and the output Cyrus relays back as a comment. ccmagic's **prompt-relay transport** (`skills/auto-ticket/autonomous-contract.md` §7) is the generic mechanism that carries the Linear side of the ticket lifecycle over that constraint; Cyrus is simply the motivating, concrete deployment.

## Prerequisites

1. **Linear's GitHub integration, with auto-close automation enabled on the team.** This is what moves the issue to Done when the linked PR merges. The agent never calls a Linear state-transition API under prompt-relay — it only emits state *intents* (`Requested state: Done`) in its final message. Without this automation enabled, a merged ticket stays stuck in whatever state Cyrus set on assignment (typically In Progress).
2. **`gh` authenticated in the container.** Verified on a live Cyrus instance (2026-07-18): `gh` is present and logged in via the `GH_TOKEN` environment variable. The entire PR/git/CI half of the cycle — branch, push, PR, review comments, merge — runs through `gh` exactly as it does on a laptop; only the Linear side changes transport.
3. **The repo checkout includes ccmagic** (plugin installed) and, if the project uses one, its `.claude/ccmagic.local.md`. No prompt-relay-specific config keys exist — transport detection is automatic (content-presence, see below), so the same config file works unmodified on a laptop and inside Cyrus.

## The Cyrus prompt template (load-bearing)

Cyrus builds the prompt for each container run from a template in the Cyrus repo. For that prompt to work with ccmagic's prompt-relay transport, it must do two things:

1. **Invoke `/ccmagic:auto-ticket {TICKET-ID}` with the issue title and description included in the same message.** `auto-ticket` is `context: fork` — it only ever sees its own arguments, not anything else that was in the top-level prompt. Content that isn't passed into the invocation never reaches the skill, so "the issue is already in the prompt somewhere" is not sufficient — it must be in the invocation text itself.
2. **Instruct the session to reproduce the skill's returned final-message block verbatim as its own final message.** `auto-ticket` ends its output with a delimited block:

   ```
   === FINAL MESSAGE TO RELAY (reproduce verbatim) ===
   {the run summary or parked note}
   === END FINAL MESSAGE ===
   ```

   Cyrus relays the session's top-level final output to Linear as a comment — and the main-loop model can paraphrase or truncate a forked skill's return before that. The delimited block plus an explicit verbatim-repeat instruction in the prompt are the two mitigations against that; the live test below is what confirms they work.

Copy-pasteable template:

```
You are working Linear issue {TICKET-ID}: "{issue title}"

{issue description}

Run:
/ccmagic:auto-ticket {TICKET-ID}

The command above will not see this issue's title or description unless you
include them directly in the arguments you pass to it — the description above
is context for you, not for the tool call.

When the command finishes, its output will end with a block delimited by:
=== FINAL MESSAGE TO RELAY (reproduce verbatim) ===
...
=== END FINAL MESSAGE ===

Reproduce the contents of that block verbatim as your own final message —
do not summarize, paraphrase, or add commentary around it.
```

## What lands where

- **The PR** carries the detailed, near-real-time audit trail: commits, the PR description, review comments, CI status — everything `gh` can see and post, unchanged from a laptop run.
- **Linear** gets exactly one consolidated message per run: the Step 6 run summary (or the parked note), including any `Requested state:` intent lines and a "Follow-ups to file" list of anything the run would have filed as a new ticket but couldn't (no create API under prompt-relay). There is no comment-by-comment progress in Linear — that's intentional (contract §7).

## Parking under prompt-relay

When a run parks (`needs-human`), there is no Linear API to move the ticket's state — nothing does that automatically. The parked note relayed to Linear is the signal: it says plainly that the run stopped and needs a decision, and it is the human (or a Cyrus-side lifecycle rule) that has to act on it and move the issue. Don't mistake "state didn't change" for "nothing happened" — check the relayed comment.

## Testing before trusting it

1. **Laptop simulation first, no Cyrus needed.** Run `claude -p` with the Linear MCP left unconfigured, and a crafted prompt that embeds a fake ticket (title + description) plus the `/ccmagic:auto-ticket` invocation, following the template above. This exercises transport detection, fetch-from-args, the state-change no-ops, and final-message emission — most of the design — without touching a real ticket or container.
2. **Then one throwaway ticket on the live Cyrus instance.** The laptop simulation can't verify the one part it doesn't control: whether Cyrus's relay delivers the final message block to Linear **verbatim**, unparaphrased (design doc §6, item R1). Create a disposable Linear issue, let Cyrus run it end to end, and check the resulting Linear comment character-for-character against what the session actually returned.
