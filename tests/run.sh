#!/usr/bin/env bash
# Tests for bin/ccm-* and the hook scripts. Plain bash, no framework.
#
#   tests/run.sh            run everything
#   tests/run.sh merge      run tests whose name contains "merge"
#
# Each test gets a fresh git repo and a fixture directory for the gh stub
# (tests/stubs/gh). Fixtures are recorded shapes of real gh output.

set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BIN=$ROOT/bin
HOOKS=$ROOT/hooks
FILTER=${1:-}
PASS=0 FAIL=0 FAILED=()

# ---- helpers ---------------------------------------------------------------

setup() {
  T=$(mktemp -d)
  export GH_FIXTURES=$T/fx
  mkdir -p "$GH_FIXTURES" "$T/repo"
  export PATH="$ROOT/tests/stubs:$PATH"
  export CCM_USER_CONFIG=$T/no-user-config.md
  export CCM_PROJECT_CONFIG=$T/repo/.claude/ccmagic.local.md
  export CCM_MERGEABLE_RETRY_SECONDS=0
  cd "$T/repo" || exit 1
  git init -q -b main
  git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  fx repo-view '{"nameWithOwner":"acme/app","defaultBranchRef":{"name":"main"}}'
}

teardown() {
  cd "$ROOT" || exit 1
  rm -rf "$T"
}

# fx NAME JSON [RC] [STDERR]: write a gh stub fixture.
fx() {
  printf '%s' "$2" >"$GH_FIXTURES/$1.json"
  if [ -n "${3:-}" ]; then echo "$3" >"$GH_FIXTURES/$1.rc"; fi
  if [ -n "${4:-}" ]; then echo "$4" >"$GH_FIXTURES/$1.err"; fi
}

# fx_err NAME STDERR RC: a gh call that fails with no stdout.
fx_err() {
  rm -f "$GH_FIXTURES/$1.json"
  echo "$2" >"$GH_FIXTURES/$1.err"
  echo "$3" >"$GH_FIXTURES/$1.rc"
}

config() {
  mkdir -p .claude
  printf -- '---\n%s\n---\n' "$1" >.claude/ccmagic.local.md
}

workflows() {
  mkdir -p .github/workflows
  echo 'on: pull_request' >.github/workflows/ci.yml
}

pr_open() {
  local mergeable=${1:-MERGEABLE} reviews=${2:-[]}
  fx pr-view "{\"number\":7,\"url\":\"https://github.com/acme/app/pull/7\",\"state\":\"OPEN\",\"mergeable\":\"$mergeable\",\"baseRefName\":\"main\",\"headRefName\":\"feature/ENG-1-x\",\"headRefOid\":\"abc123\",\"reviews\":$reviews}"
}

# run CMD...: capture stdout in OUT and exit code in RC.
run() {
  OUT=$("$@" 2>"$T/stderr")
  RC=$?
}

hook() {
  local input
  input=$(jq -n --arg c "$1" --arg a "${2:-}" --arg cwd "$PWD" \
    '{tool_name: "Bash", tool_input: {command: $c}, cwd: $cwd} + (if $a == "" then {} else {agent_type: $a} end)')
  OUT=$(printf '%s' "$input" | bash "$HOOKS/pre-tool-use-guard.sh" 2>"$T/stderr")
  RC=$?
}

check() {
  if [ "$1" != "$2" ]; then
    echo "    expected: $2"
    echo "    actual:   $1"
    [ -s "$T/stderr" ] && sed 's/^/    stderr: /' "$T/stderr"
    return 1
  fi
}

jqval() { jq -r "$1" <<<"$OUT"; }
denied() { [ "$(jq -r '.hookSpecificOutput.permissionDecision // "allow"' <<<"${OUT:-{\}}")" = deny ] && echo deny || echo allow; }

t() {
  local name=$1
  shift
  if [ -n "$FILTER" ] && [[ $name != *"$FILTER"* ]]; then return; fi
  setup
  if ( set -e; "$@" ); then
    PASS=$((PASS + 1))
    echo "ok   $name"
  else
    FAIL=$((FAIL + 1))
    FAILED+=("$name")
    echo "FAIL $name"
  fi
  teardown
}

# ---- ccm-context -----------------------------------------------------------

context_ticket_from_feature_branch() {
  git checkout -q -b feature/ENG-123-add-search
  fx_err pr-view 'no pull requests found' 1
  run "$BIN/ccm-context"
  check "$(jqval .ticket_id),$(jqval .ticket_kind),$(jqval .ticket_source)" "ENG-123,key,branch"
  check "$(jqval .tracker_hint),$(jqval .base_branch),$(jqval .checkout)" "linear-or-jira,main,primary"
}

context_ticket_from_github_branch() {
  git checkout -q -b bugfix/42-fix-cart
  run "$BIN/ccm-context" --offline
  check "$(jqval .ticket_id),$(jqval .ticket_kind),$(jqval .tracker_hint)" "42,integer,github"
}

context_argument_wins_and_url_base_picks_tracker() {
  git checkout -q -b feature/ENG-1-x
  config 'ticket_url_base: https://acme.atlassian.net/browse'
  run "$BIN/ccm-context" --offline PROJ-9
  check "$(jqval .ticket_id),$(jqval .ticket_source),$(jqval .tracker_hint)" "PROJ-9,arg,jira"
}

context_config_precedence() {
  printf -- '---\nmerge_owner: reeve\nneeds_human_label: user-label\n---\n' >"$CCM_USER_CONFIG"
  config $'needs_human_label: "project-label"   # comment\nci_timeout_minutes: 12'
  run "$BIN/ccm-context" --offline
  check "$(jqval .config.merge_owner),$(jqval .config.needs_human_label),$(jqval .config.ci_timeout_minutes),$(jqval .config.max_feedback_passes)" \
    "reeve,project-label,12,3"
}

context_no_ticket_on_main() {
  run "$BIN/ccm-context" --offline
  check "$(jqval .ticket_id),$(jqval .branch)" "null,main"
}

# ---- ccm-ci-status ---------------------------------------------------------

ci_green() {
  pr_open
  fx pr-checks '[{"name":"test","state":"SUCCESS","bucket":"pass"},{"name":"lint","state":"SKIPPED","bucket":"skipping"}]'
  run "$BIN/ccm-ci-status" 7
  check "$(jqval .status),$RC,$(jqval .source)" "green,0,checks"
}

ci_pending() {
  pr_open
  fx pr-checks '[{"name":"test","state":"IN_PROGRESS","bucket":"pending"},{"name":"lint","state":"SUCCESS","bucket":"pass"}]' 8
  run "$BIN/ccm-ci-status" 7
  check "$(jqval .status),$RC" "pending,2"
}

ci_failed_wins_over_pending() {
  pr_open
  fx pr-checks '[{"name":"test","state":"FAILURE","bucket":"fail"},{"name":"e2e","state":"IN_PROGRESS","bucket":"pending"}]' 1
  run "$BIN/ccm-ci-status" 7
  check "$(jqval .status),$RC,$(jqval .reason)" "failed,1,failing: test"
}

ci_403_falls_back_to_actions_green() {
  pr_open
  fx_err pr-checks 'GraphQL: Resource not accessible by personal access token (HTTP 403)' 1
  fx run-list '[{"databaseId":1,"workflowName":"CI","status":"completed","conclusion":"success"},{"databaseId":2,"workflowName":"Docs","status":"completed","conclusion":"skipped"}]'
  fx status '{"state":"pending","total_count":0,"statuses":[]}'
  run "$BIN/ccm-ci-status" 7
  check "$(jqval .status),$RC,$(jqval .source)" "green,0,actions-fallback"
}

ci_403_fallback_sees_running_workflow() {
  pr_open
  fx_err pr-checks 'HTTP 403' 1
  fx run-list '[{"databaseId":1,"workflowName":"CI","status":"in_progress","conclusion":null}]'
  fx status '{"state":"pending","total_count":0,"statuses":[]}'
  run "$BIN/ccm-ci-status" 7
  check "$(jqval .status),$RC" "pending,2"
}

ci_403_fallback_failed_status() {
  pr_open
  fx_err pr-checks 'HTTP 403' 1
  fx run-list '[]'
  fx status '{"state":"failure","total_count":1,"statuses":[{"context":"ext/ci","state":"failure"}]}'
  run "$BIN/ccm-ci-status" 7
  check "$(jqval .status),$(jqval .reason)" "failed,failing: ext/ci"
}

ci_unreadable_when_everything_fails() {
  pr_open
  fx_err pr-checks 'HTTP 403' 1
  fx_err run-list 'HTTP 403' 1
  fx_err status 'HTTP 403' 1
  run "$BIN/ccm-ci-status" 7
  check "$(jqval .status),$RC" "unreadable,3"
}

ci_no_ci_when_no_workflows_and_unprotected() {
  pr_open
  fx_err pr-checks 'no checks reported on the '"'"'feature/ENG-1-x'"'"' branch' 1
  fx run-list '[]'
  fx status '{"state":"pending","total_count":0,"statuses":[]}'
  fx_err protection 'gh: Branch not protected (HTTP 404)' 1
  run "$BIN/ccm-ci-status" 7
  check "$(jqval .status),$RC" "no-ci,0"
}

ci_not_registered_when_workflows_exist() {
  workflows
  pr_open
  fx pr-checks '[]'
  fx run-list '[]'
  fx status '{"state":"pending","total_count":0,"statuses":[]}'
  fx_err protection 'HTTP 404' 1
  run "$BIN/ccm-ci-status" 7
  check "$(jqval .status),$RC" "not-registered,2"
}

ci_not_registered_when_required_checks_exist() {
  pr_open
  fx pr-checks '[]'
  fx run-list '[]'
  fx status '{"state":"pending","total_count":0,"statuses":[]}'
  fx protection '{"contexts":["ci/test"],"checks":[{"context":"ci/test"}]}'
  run "$BIN/ccm-ci-status" 7
  check "$(jqval .status)" "not-registered"
}

ci_watch_times_out_on_shared_deadline() {
  pr_open
  fx pr-checks '[{"name":"test","state":"IN_PROGRESS","bucket":"pending"}]' 8
  run "$BIN/ccm-ci-status" 7 --watch --wait-key run1-pass1 --timeout-minutes 0 --interval 0
  check "$(jqval .status),$RC" "timeout,5"
  # The deadline file is cleared once the wait ends.
  check "$(find "$(git rev-parse --git-dir)/ccmagic" -type f | wc -l | tr -d ' ')" "0"
}

ci_watch_returns_call_again_before_deadline() {
  pr_open
  fx pr-checks '[{"name":"test","state":"IN_PROGRESS","bucket":"pending"}]' 8
  run "$BIN/ccm-ci-status" 7 --watch --wait-key run1-pass1 --timeout-minutes 30 --interval 1 --max-call-seconds 0
  check "$(jqval .status),$(jqval .call_again),$RC" "pending,true,2"
  check "$(cat "$(git rev-parse --git-dir)/ccmagic/ci-wait-run1-pass1" | wc -c | tr -d ' ')" "11"
}

ci_watch_returns_when_settled() {
  pr_open
  fx pr-checks '[{"name":"test","state":"SUCCESS","bucket":"pass"}]'
  run "$BIN/ccm-ci-status" 7 --watch --wait-key k --interval 0
  check "$(jqval .status),$RC" "green,0"
}

# ---- ccm-merge-gate --------------------------------------------------------

merge_gate_passes() {
  pr_open MERGEABLE '[{"author":{"login":"rev"},"state":"APPROVED","submittedAt":"2026-09-01T00:00:00Z"}]'
  fx pr-checks '[{"name":"test","state":"SUCCESS","bucket":"pass"}]'
  run "$BIN/ccm-merge-gate" 7
  check "$(jqval .pass),$RC,$(jqval '.warnings | length')" "true,0,0"
}

merge_gate_warns_without_approval() {
  pr_open
  fx pr-checks '[{"name":"test","state":"SUCCESS","bucket":"pass"}]'
  run "$BIN/ccm-merge-gate" 7
  check "$(jqval .pass),$(jqval '.warnings[0]')" "true,no approving review"
}

merge_gate_blocks_conflicts() {
  pr_open CONFLICTING
  fx pr-checks '[{"name":"test","state":"SUCCESS","bucket":"pass"}]'
  run "$BIN/ccm-merge-gate" 7
  check "$(jqval .pass),$RC,$(jqval '.blockers[0]')" "false,1,merge conflicts with main"
}

merge_gate_blocks_unknown_mergeability() {
  pr_open UNKNOWN
  fx pr-checks '[{"name":"test","state":"SUCCESS","bucket":"pass"}]'
  run "$BIN/ccm-merge-gate" 7
  check "$(jqval .pass),$(jqval '.blockers | length')" "false,1"
}

merge_gate_blocks_red_ci() {
  pr_open
  fx pr-checks '[{"name":"test","state":"FAILURE","bucket":"fail"}]' 1
  run "$BIN/ccm-merge-gate" 7
  check "$(jqval .pass),$(jqval '.blockers[0]')" "false,CI failed: failing: test"
}

merge_gate_blocks_changes_requested() {
  pr_open MERGEABLE '[{"author":{"login":"a"},"state":"APPROVED","submittedAt":"2026-09-01T00:00:00Z"},{"author":{"login":"b"},"state":"CHANGES_REQUESTED","submittedAt":"2026-09-02T00:00:00Z"},{"author":{"login":"b"},"state":"COMMENTED","submittedAt":"2026-09-03T00:00:00Z"}]'
  fx pr-checks '[{"name":"test","state":"SUCCESS","bucket":"pass"}]'
  run "$BIN/ccm-merge-gate" 7
  check "$(jqval .pass),$(jqval '.blockers[0]')" "false,changes requested by b"
}

merge_gate_later_approval_clears_changes_requested() {
  pr_open MERGEABLE '[{"author":{"login":"b"},"state":"CHANGES_REQUESTED","submittedAt":"2026-09-02T00:00:00Z"},{"author":{"login":"b"},"state":"APPROVED","submittedAt":"2026-09-04T00:00:00Z"}]'
  fx pr-checks '[{"name":"test","state":"SUCCESS","bucket":"pass"}]'
  run "$BIN/ccm-merge-gate" 7
  check "$(jqval .pass)" "true"
}

merge_gate_unreadable_pr() {
  fx_err pr-view 'no pull requests found' 1
  run "$BIN/ccm-merge-gate" 7
  check "$(jqval .pass),$RC" "false,3"
}

# ---- pre-tool-use-guard: merge gate ----------------------------------------

guard_ignores_other_commands() {
  hook 'git status && gh pr view 7'
  check "$(denied),$RC" "allow,0"
  check "$(cat "$GH_FIXTURES/calls.log" 2>/dev/null | wc -l | tr -d ' ')" "0"
}

guard_ignores_merge_text_in_strings() {
  hook 'echo "run gh pr merge later"' ccmagic:auto-finish
  check "$(denied)" "allow"
}

guard_interactive_default_is_off() {
  pr_open CONFLICTING
  hook 'gh pr merge 7 --squash --delete-branch'
  check "$(denied)" "allow"
}

guard_autonomous_agent_blocked_by_gate() {
  pr_open CONFLICTING
  fx pr-checks '[{"name":"test","state":"SUCCESS","bucket":"pass"}]'
  hook 'gh pr merge 7 --squash --delete-branch' ccmagic:auto-finish
  check "$(denied)" "deny"
  [[ $(jq -r .hookSpecificOutput.permissionDecisionReason <<<"$OUT") == *"merge conflicts with main"* ]]
}

guard_autonomous_agent_allowed_when_gate_passes() {
  pr_open
  fx pr-checks '[{"name":"test","state":"SUCCESS","bucket":"pass"}]'
  hook 'cd /tmp/wt && gh pr merge 7 --squash' ccmagic:auto-finish
  check "$(denied)" "allow"
}

guard_autonomous_override_is_ignored() {
  pr_open CONFLICTING
  fx pr-checks '[{"name":"test","state":"SUCCESS","bucket":"pass"}]'
  hook 'CCMAGIC_MERGE_OVERRIDE=1 gh pr merge 7 --squash' ccmagic:auto-finish
  check "$(denied)" "deny"
}

guard_autonomous_config_counts_as_autonomous() {
  config 'autonomous: true'
  pr_open CONFLICTING
  fx pr-checks '[{"name":"test","state":"SUCCESS","bucket":"pass"}]'
  hook 'gh pr merge --squash'
  check "$(denied)" "deny"
}

guard_reeve_never_merges_autonomously() {
  config 'merge_owner: reeve'
  pr_open
  fx pr-checks '[{"name":"test","state":"SUCCESS","bucket":"pass"}]'
  hook 'gh pr merge 7 --squash' ccmagic:auto-finish
  check "$(denied)" "deny"
  [[ $(jq -r .hookSpecificOutput.permissionDecisionReason <<<"$OUT") == *reeve* ]]
}

guard_interactive_merge_guard_on() {
  config 'merge_guard: on'
  pr_open
  fx pr-checks '[{"name":"test","state":"FAILURE","bucket":"fail"}]' 1
  hook 'gh pr merge https://github.com/acme/app/pull/7 --squash'
  check "$(denied)" "deny"
  grep -q 'pr checks 7' "$GH_FIXTURES/calls.log"
}

guard_interactive_override_allowed() {
  config 'merge_guard: on'
  pr_open CONFLICTING
  hook 'CCMAGIC_MERGE_OVERRIDE=1 gh pr merge 7 --squash'
  check "$(denied)" "allow"
}

guard_api_merge_is_gated() {
  pr_open CONFLICTING
  fx pr-checks '[{"name":"test","state":"SUCCESS","bucket":"pass"}]'
  hook 'gh api -X PUT repos/acme/app/pulls/7/merge -f merge_method=squash' ccmagic:auto-finish
  check "$(denied)" "deny"
}

# ---- run -------------------------------------------------------------------

for fn in $(declare -F | awk '{print $3}' | grep -E '^(context|ci|merge_gate|guard)_'); do
  t "$fn" "$fn"
done

echo
echo "$PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  printf '  %s\n' "${FAILED[@]}"
  exit 1
fi
