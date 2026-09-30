#!/usr/bin/env bash
# SubagentStop hook: the forked /auto-ticket orchestrator may not end its turn
# after doing a step agent's work itself (RV-80).
#
# auto-ticket runs as a forked skill, so it stops as a `general-purpose`
# subagent whose transcript opens with the skill text. The skill never edits
# code: every change is made by a step agent (SKILL.md, "Step execution
# mode"). In one field run the orchestrator skipped the cycle, edited the
# file, committed, pushed, and opened the PR itself, then ended its turn with
# no run summary, so the run left no record and its caller parked it.
#
# The hook sends the orchestrator back once, from Step 0, when all of these
# hold:
#   - the transcript's first user message is the auto-ticket skill text;
#   - the orchestrator itself made an Edit, Write, MultiEdit, or NotebookEdit
#     call, or ran git commit, git push, gh pr create, or gh pr merge;
#   - its last message has neither the prompt-relay final-message block
#     (contract §7) nor a run summary heading (Step 6, contract §4).
# A run that ends another legitimate way (a setup error before any step, or a
# final status under the mcp transport) makes none of those calls, so it is
# never blocked. Every other subagent is let go at once, and any input the
# hook cannot read is let go too (exit 0 with no output).

INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

agent_type=$(jq -r '.agent_type // empty' <<<"$INPUT" 2>/dev/null) || exit 0
[ "$agent_type" = general-purpose ] || exit 0
[ "$(jq -r '.stop_hook_active // false' <<<"$INPUT" 2>/dev/null)" = false ] || exit 0
transcript=$(jq -r '.agent_transcript_path // empty' <<<"$INPUT" 2>/dev/null) || exit 0

[ -n "$transcript" ] && [ -r "$transcript" ] || exit 0

# One pass over the transcript: is it the orchestrator, and what did it do
# itself. Lines that are not JSON are skipped.
verdict=$(jq -n -R -r '
  [inputs | fromjson? | objects] as $e
  | ($e | map(select(.type == "user")) | first | .message.content // "") as $c
  | (if ($c | type) == "array" then ($c | map(.text? // "") | join("\n")) else ($c | tostring) end) as $first
  | if ($first | test("^Base directory for this skill: [^\n]*/skills/auto-ticket\n") and test("\n# /auto-ticket [^\n]*Autonomous Ticket Driver"))
    then
      [ $e[] | select(.type == "assistant") | .message.content? | arrays | .[]
        | select(.type? == "tool_use")
        | if (.name | IN("Edit", "Write", "MultiEdit", "NotebookEdit")) then .name
          elif .name == "Bash" and ((.input.command? // "") | tostring
               | test("(^|[;&|(\\s])(git\\s+(-C\\s+\\S+\\s+)?(commit|push)|gh\\s+pr\\s+(create|merge))(\\s|$)"))
          then "Bash: " + (.input.command | tostring | split("\n")[0] | .[0:80])
          else empty end ]
      | if length == 0 then "clean" else "acted\t" + (unique | join("; ")) end
    else "other" end' <"$transcript" 2>/dev/null) || exit 0

case $verdict in
  acted*) ;;
  *) exit 0 ;;
esac
acts=${verdict#acted$'\t'}

msg=$(jq -r '.last_assistant_message // empty' <<<"$INPUT" 2>/dev/null) || exit 0
case $msg in
  *"=== FINAL MESSAGE TO RELAY"* | *"Autonomous run summary"*) exit 0 ;;
esac

jq -n --arg acts "$acts" --arg r "You are the /auto-ticket orchestrator, and you did step work yourself ($acts). This skill never edits code, commits, pushes, or opens a PR; the step agents do. Do not redo, revert, or repeat any change already made. Continue from Step 0: read autonomous-contract.md, run ccm-context, then run Steps 1 to 6 through run_step. If the work step finds the change already made and the PR open, that is its done. End the run the way Step 6 says: the run summary, and under the prompt-relay transport the === FINAL MESSAGE TO RELAY (reproduce verbatim) === block (contract §7)." \
  '{decision: "block", reason: $r}' 2>/dev/null
exit 0
