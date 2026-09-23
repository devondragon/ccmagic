#!/usr/bin/env bash
# PreToolUse hook (Bash): blocks commands that ccmagic's rules forbid, before
# they run. Denials go back to the model with the reason, so it can correct
# course instead of the rule depending on it having read the skill closely.
#
# Rules:
#   Merge gate: `gh pr merge` (or a PUT to .../pulls/N/merge via `gh api`).
#     - In an autonomous run (a ccmagic:auto-* agent, or `autonomous: true` in
#       ccmagic.local.md), the merge is denied unless bin/ccm-merge-gate passes,
#       and always denied when merge_owner is reeve. No override.
#     - Interactively, the gate applies only when `merge_guard: on` is set, and
#       the user can still merge past it: a command prefixed with
#       CCMAGIC_MERGE_OVERRIDE=1 is allowed. Default is off, so installing
#       ccmagic does not change how anyone merges by hand.
#
# Exit 0 with no output allows the command. A deny prints the PreToolUse
# decision JSON and exits 0.

set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bin="$here/../bin"

INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

cmd=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
agent_type=$(jq -r '.agent_type // empty' <<<"$INPUT")
cwd=$(jq -r '.cwd // empty' <<<"$INPUT")
[ -n "$cmd" ] || exit 0
if [ -n "$cwd" ]; then
  cd "$cwd" 2>/dev/null || true
fi

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse",
    permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

# A command segment starts at the beginning of a line or after ; & | (.
seg='(^|[;&|(])[[:space:]]*'
envs='([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'

is_merge=false
merge_pr=""
if printf '%s' "$cmd" | grep -qE "${seg}${envs}gh[[:space:]]+pr[[:space:]]+merge([[:space:]]|$)"; then
  is_merge=true
  # First non-flag argument after `merge` is the PR (number, URL, or branch).
  merge_pr=$(printf '%s' "$cmd" | sed -nE 's/.*gh[[:space:]]+pr[[:space:]]+merge[[:space:]]+(.*)/\1/p' | head -1 |
    awk '{ for (i = 1; i <= NF; i++) { if ($i ~ /^[;&|]/) exit; if ($i !~ /^-/) { print $i; exit } } }')
  case $merge_pr in
    */pull/*) merge_pr=${merge_pr##*/pull/}; merge_pr=${merge_pr%%[^0-9]*} ;;
  esac
elif printf '%s' "$cmd" | grep -qE "gh[[:space:]]+api[[:space:]].*pulls/[0-9]+/merge" &&
     printf '%s' "$cmd" | grep -qiE -- '(-X|--method)[[:space:]]*PUT'; then
  is_merge=true
  merge_pr=$(printf '%s' "$cmd" | sed -nE 's/.*pulls\/([0-9]+)\/merge.*/\1/p' | head -1)
fi

if [ "$is_merge" = true ]; then
  # shellcheck source=bin/ccm-lib.sh
  . "$bin/ccm-lib.sh"
  cfg=$(ccm_config_json 2>/dev/null || echo '{}')
  autonomous=false
  case $agent_type in ccmagic:auto-*) autonomous=true ;; esac
  [ "$(jq -r '.autonomous // "false"' <<<"$cfg")" = true ] && autonomous=true
  merge_owner=$(jq -r '.merge_owner // "self"' <<<"$cfg")
  guard=$(jq -r '.merge_guard // "off"' <<<"$cfg")

  if [ "$autonomous" = true ]; then
    if [ "$merge_owner" = reeve ]; then
      deny "ccmagic: merge_owner is reeve, so this run must not merge. Take the hand-off path instead (move the ticket to merge_handoff_state and report 'handed off to reeve')."
    fi
    gate=$("$bin/ccm-merge-gate" ${merge_pr:+"$merge_pr"} 2>/dev/null)
    rc=$?
    if [ "$rc" -ne 0 ]; then
      blockers=$(jq -r '(.blockers // ["merge gate could not run"]) | join("; ")' <<<"$gate" 2>/dev/null || echo "merge gate could not run")
      deny "ccmagic merge gate failed: $blockers. An autonomous run does not merge past the gate; return needs-human with these blockers as the reason."
    fi
    exit 0
  fi

  if [ "$guard" = on ]; then
    if printf '%s' "$cmd" | grep -qE "(^|[[:space:]])CCMAGIC_MERGE_OVERRIDE=1[[:space:]]"; then
      exit 0
    fi
    gate=$("$bin/ccm-merge-gate" ${merge_pr:+"$merge_pr"} 2>/dev/null)
    rc=$?
    if [ "$rc" -ne 0 ]; then
      blockers=$(jq -r '(.blockers // ["merge gate could not run"]) | join("; ")' <<<"$gate" 2>/dev/null || echo "merge gate could not run")
      deny "ccmagic merge gate failed: $blockers. Show these to the user. Only if the user explicitly chooses to merge anyway, rerun the same command prefixed with CCMAGIC_MERGE_OVERRIDE=1."
    fi
  fi
fi

exit 0
