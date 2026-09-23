#!/usr/bin/env bash
# SubagentStop hook: a ccmagic:auto-* step agent may not finish until its last
# message ends with a valid status handshake (skills/auto-ticket/autonomous-contract.md §3):
#
#   status: <value>
#   reason: <one line>
#   follow_ups: [...]
#   requested_state: <state>     (prompt-relay only)
#
# The orchestrator reads that block to decide merge / park. Without it, the run
# parks with "produced no handshake", so the agent is sent back once to add it.
# If it is already continuing because of this hook (stop_hook_active), it is let
# go, and the orchestrator's missing-handshake rule applies.
#
# Plugin agents ignore `hooks:` in their own frontmatter, so this runs from
# hooks/hooks.json for every subagent and filters on agent_type.

set -o pipefail

INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

agent_type=$(jq -r '.agent_type // empty' <<<"$INPUT")
case $agent_type in
  ccmagic:auto-review) allowed="clean fixable-findings needs-human" ;;
  ccmagic:auto-work|ccmagic:auto-feedback|ccmagic:auto-validate|ccmagic:auto-finish|ccmagic:auto-push) allowed="done needs-human" ;;
  *) exit 0 ;;
esac
[ "$(jq -r '.stop_hook_active // false' <<<"$INPUT")" = true ] && exit 0

msg=$(jq -r '.last_assistant_message // empty' <<<"$INPUT")

# Take the last `status:` line and everything after it. After it, only the
# other handshake keys, list continuation lines, code fences, and blank lines
# may appear.
problem=$(printf '%s\n' "$msg" | awk -v allowed="$allowed" '
  { lines[NR] = $0 }
  /^[[:space:]]*status:[[:space:]]*/ { last = NR }
  END {
    if (!last) { print "no `status:` line"; exit }
    s = lines[last]
    sub(/^[[:space:]]*status:[[:space:]]*/, "", s); sub(/[[:space:]]+$/, "", s)
    n = split(allowed, ok, " "); valid = 0
    for (i = 1; i <= n; i++) if (s == ok[i]) valid = 1
    if (!valid) { print "status `" s "` is not one of: " allowed; exit }
    reason = 0; follow = 0
    for (i = last + 1; i <= NR; i++) {
      l = lines[i]
      if (l ~ /^[[:space:]]*reason:/) { reason = 1; continue }
      if (l ~ /^[[:space:]]*follow_ups:/) { follow = 1; continue }
      if (l ~ /^[[:space:]]*requested_state:/) continue
      if (l ~ /^[[:space:]]*(-|```|$)/) continue
      if (l ~ /^[[:space:]]+[^[:space:]]/) continue
      print "text after the handshake (`" substr(l, 1, 60) "`); the handshake must be the last thing"; exit
    }
    if (!reason) { print "no `reason:` line after `status:`"; exit }
    if (!follow) { print "no `follow_ups:` line after `status:`"; exit }
  }')

[ -z "$problem" ] && exit 0

jq -n --arg r "Your final message must end with the ccmagic status handshake, and it doesn't ($problem). End your reply with exactly this block, filled in:

status: ${allowed// / | }
reason: <one line>
follow_ups: [<ticket ids or short descriptions, or empty>]

Add requested_state: only under the prompt-relay transport. Do not redo any work; only restate your outcome in this form." \
  '{decision: "block", reason: $r}'
exit 0
