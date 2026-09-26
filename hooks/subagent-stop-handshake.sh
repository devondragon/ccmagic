#!/usr/bin/env bash
# SubagentStop hook: a ccmagic:auto-* step agent may not finish until its last
# message ends with a valid status handshake (skills/auto-ticket/autonomous-contract.md §3):
#
#   status: <value>
#   reason: <one line>
#   follow_ups: [...]
#   requested_state: <state>     (optional: a tracker state change the step needs)
#
# The orchestrator reads that block to decide merge / park. Without it, the run
# parks with "produced no handshake", so the agent is sent back once to add it.
# If it is already continuing because of this hook (stop_hook_active), it is let
# go, and the orchestrator's missing-handshake rule applies.
#
# Text after the handshake is never tolerated, including a literal
# </SubagentHandback> tag: that tag means the agent wrote a tool call as text
# instead of making it, so its caller may not receive the report at all. The
# send-back reason tells it how to hand back with the SubagentHandback tool.
#
# Plugin agents ignore `hooks:` in their own frontmatter, so this runs from
# hooks/hooks.json for every subagent and filters on agent_type. The check
# itself is ccm_handshake_problem in hooks/lib-handshake.sh, which
# bin/ccm-post-review also uses.

set -o pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=hooks/lib-handshake.sh
. "$here/lib-handshake.sh"

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

problem=$(printf '%s\n' "$msg" | ccm_handshake_problem "$allowed")

[ -z "$problem" ] && exit 0

jq -n --arg r "Your final message must end with the ccmagic status handshake, and it doesn't ($problem). If you stopped only to wait for a helper you started, keep waiting and finish your work first. Otherwise end your reply with exactly this block, filled in:

status: ${allowed// / | }
reason: <one line>
follow_ups: [<ticket ids or short descriptions, or empty>]

Add a requested_state: line after follow_ups: when your step needs a tracker state change. If you deliver your report with the SubagentHandback tool, its message must be your full report ending with this block, and your final text must end with the block too. Never write tool-call tags such as <SubagentHandback> as text. Do not redo any work. Restate your full final report, including any sections that came before the handshake (such as applied_findings:, commit_notes:, or failures:), and end it with this block." \
  '{decision: "block", reason: $r}'
exit 0
