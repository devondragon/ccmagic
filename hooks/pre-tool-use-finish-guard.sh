#!/usr/bin/env bash
# PreToolUse hook (Agent, Task): the /auto-ticket orchestrator may not start
# the finish step of a run whose step history does not allow it (RV-86).
#
# In Reeve's RS-175 run the validate step returned needs-human with a
# `failed:` reason, and the orchestrator judged the failure environmental and
# went straight to finish-ticket, which handed the PR off. Step 4b of the
# skill sends a `failed:` validate to fix passes and parks after them; a run
# that merges itself (merge_owner: self) would have merged a red branch. So
# the rule is checked here, in code, on the spawn the orchestrator cannot
# finish without, instead of relying on it reading Step 4b closely.
#
# When the tool call spawns `ccmagic:auto-finish`, its prompt (the grounding
# block, whose `steps:` section the orchestrator fills in) goes to
# bin/ccm-finish-guard, and a failure denies the spawn with the guard's rule
# and detail, telling the orchestrator to route-and-stop. A grounding block
# without a readable `steps:` section is denied too. Every other tool call
# and subagent type is allowed (exit 0, no output), and so is everything when
# jq is missing, as in the other hooks.
#
# The auto-finish agent runs the same script as its first action, which
# covers a harness that does not run plugin hooks.

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

[ "$(jq -r '.tool_input.subagent_type // empty' <<<"$INPUT" 2>/dev/null)" = ccmagic:auto-finish ] || exit 0

out=$(jq -r '.tool_input.prompt // ""' <<<"$INPUT" | "$here/../bin/ccm-finish-guard" 2>/dev/null) && exit 0

rule=$(jq -r '.rule // "unreadable"' <<<"$out" 2>/dev/null || echo unreadable)
stage=$(jq -r '.stage // "finish-ticket"' <<<"$out" 2>/dev/null || echo finish-ticket)
detail=$(jq -r '.detail // "ccm-finish-guard did not run"' <<<"$out" 2>/dev/null || echo "ccm-finish-guard did not run")

if [ "$rule" = steps-unreadable ] || [ "$rule" = unreadable ]; then
  next="End the auto-finish grounding block with a steps: section holding the run's steps so far as a JSON array in a ~~~ fence (skills/auto-ticket/SKILL.md Step 5) and start the finish step again. If you cannot, route-and-stop (contract §4) with stage finish-ticket and this reason."
else
  next="Do not start the finish step again and do not move the ticket yourself. Route-and-stop now (contract §4) with stage $stage and reason: finish guard ($rule): $detail."
fi

jq -n --arg r "ccmagic finish guard ($rule): $detail. The run may not reach finish-ticket, so nothing is merged or handed off. $next" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
exit 0
