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
  OUT=$("$@" 2>"$T/stderr") && RC=0 || RC=$?
}

hook() {
  local input
  input=$(jq -n --arg c "$1" --arg a "${2:-}" --arg cwd "$PWD" \
    '{tool_name: "Bash", tool_input: {command: $c}, cwd: $cwd} + (if $a == "" then {} else {agent_type: $a} end)')
  OUT=$(printf '%s' "$input" | "${HOOK_BASH:-bash}" "$HOOKS/pre-tool-use-guard.sh" 2>"$T/stderr") && RC=0 || RC=$?
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
  # Not `if ( ... )`: bash ignores set -e inside a condition, which would let
  # a failed check pass unless it was the test's last command.
  local rc
  ( set -e; "$@" )
  rc=$?
  if [ "$rc" -eq 0 ]; then
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

context_github_integer_argument() {
  git checkout -q -b feature/ENG-9-x
  run "$BIN/ccm-context" --offline '#42'
  check "$(jqval .ticket_id),$(jqval .ticket_source),$(jqval .ticket_kind),$(jqval .tracker_hint)" \
    "42,arg,integer,github"
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

ci_hidden_checks_and_unreadable_protection_fail_closed() {
  pr_open
  fx_err pr-checks 'Resource not accessible by personal access token (HTTP 403)' 1
  fx run-list '[]'
  fx status '{"state":"pending","total_count":0,"statuses":[]}'
  fx_err protection 'Resource not accessible by personal access token (HTTP 403)' 1
  run "$BIN/ccm-ci-status" 7
  check "$(jqval .status),$RC" "unreadable,3"
}

ci_hidden_checks_but_unprotected_branch_is_no_ci() {
  pr_open
  fx_err pr-checks 'HTTP 403' 1
  fx run-list '[]'
  fx status '{"state":"pending","total_count":0,"statuses":[]}'
  fx_err protection 'gh: Branch not protected (HTTP 404)' 1
  run "$BIN/ccm-ci-status" 7
  check "$(jqval .status)" "no-ci"
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
  check "$(wc -c <"$(git rev-parse --git-dir)/ccmagic/ci-wait-run1-pass1" | tr -d ' ')" "11"
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
  check "$(test -f "$GH_FIXTURES/calls.log" && echo called || echo none)" "none"
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

# ---- pre-tool-use-guard: force push ----------------------------------------

guard_force_push_to_main_denied_interactively() {
  hook 'git push --force origin main'
  check "$(denied)" "deny"
}

guard_force_push_plus_refspec_denied() {
  hook 'git push origin +HEAD:refs/heads/main'
  check "$(denied)" "deny"
}

guard_force_push_own_branch_allowed_interactively() {
  git checkout -q -b feature/ENG-1-x
  hook 'git push --force-with-lease'
  check "$(denied)" "allow"
}

guard_force_push_denied_autonomously() {
  git checkout -q -b feature/ENG-1-x
  hook 'git push -fu origin feature/ENG-1-x' ccmagic:auto-push
  check "$(denied)" "deny"
}

guard_normal_push_allowed_autonomously() {
  git checkout -q -b feature/ENG-1-x
  hook 'git pull --rebase && git push -u origin feature/ENG-1-x' ccmagic:auto-push
  check "$(denied)" "allow"
}

# ---- pre-tool-use-guard: sensitive files -----------------------------------

guard_add_env_denied() {
  echo SECRET=1 >.env
  hook 'git add .env src/app.ts'
  check "$(denied)" "deny"
  [[ $(jq -r .hookSpecificOutput.permissionDecisionReason <<<"$OUT") == *".env"* ]]
}

guard_add_all_picks_up_untracked_key() {
  echo k >server.pem
  echo x >app.ts
  hook 'git add -A && git commit -m "feat: add server"'
  check "$(denied)" "deny"
}

guard_add_all_respects_gitignore() {
  echo '.env' >.gitignore
  echo SECRET=1 >.env
  echo x >app.ts
  hook 'git add . && git commit -m "feat: x"'
  check "$(denied)" "allow"
}

guard_add_after_dashdash_checked() {
  echo SECRET=1 >-weird.env
  echo SECRET=1 >.env
  hook 'git add -- .env'
  check "$(denied)" "deny"
  hook 'git add -- -weird.env'
  check "$(denied)" "allow"
  mv -- -weird.env x.pem
  hook 'git add -- x.pem'
  check "$(denied)" "deny"
}

guard_env_example_allowed() {
  echo A= >.env.example
  hook 'git add .env.example'
  check "$(denied)" "allow"
}

guard_staged_secret_blocks_commit() {
  echo k >id_rsa
  git add id_rsa
  hook 'git commit -m "chore: keys"'
  check "$(denied)" "deny"
}

guard_sensitive_override_interactive() {
  echo k >.env
  hook 'CCMAGIC_ALLOW_SENSITIVE=1 git add .env'
  check "$(denied)" "allow"
}

guard_sensitive_override_ignored_autonomously() {
  echo k >.env
  hook 'CCMAGIC_ALLOW_SENSITIVE=1 git add .env' ccmagic:auto-push
  check "$(denied)" "deny"
}

guard_commit_preferences_always_include() {
  mkdir -p context
  printf '# Commit Preferences\n\n## Always Include\n- config/dev.key\n\n## Always Exclude\n- .env\n' >context/commit-preferences.md
  mkdir -p config
  echo k >config/dev.key
  hook 'git add config/dev.key' ccmagic:auto-push
  check "$(denied)" "allow"
}

guard_commit_all_flag_sees_modified_tracked() {
  echo a >creds.secret
  git add creds.secret
  CCMAGIC_ALLOW_SENSITIVE=1 git -c user.email=t@t -c user.name=t commit -q -m "chore: seed"
  echo b >creds.secret
  hook 'git commit -am "fix: update"'
  check "$(denied)" "deny"
}

# ---- pre-tool-use-guard: commit format -------------------------------------

guard_bad_subject_denied_autonomously() {
  hook 'git commit -m "Added the thing"' ccmagic:auto-push
  check "$(denied)" "deny"
  [[ $(jq -r .hookSpecificOutput.permissionDecisionReason <<<"$OUT") == *"Added the thing"* ]]
}

guard_bad_subject_allowed_interactively() {
  hook 'git commit -m "Added the thing"'
  check "$(denied)" "allow"
}

guard_good_heredoc_subject_allowed_autonomously() {
  hook "$(printf 'git commit -F - <<%sEOF%s\nfeat(api): ENG-12 add endpoint\n\nBody.\nEOF' "'" "'")" ccmagic:auto-push
  check "$(denied)" "allow"
}

guard_merge_subject_exempt() {
  hook 'git commit -m "Merge branch main into feature/x"' ccmagic:auto-feedback
  check "$(denied)" "allow"
}

# ---- post-tool-use-commit ----------------------------------------------------

run_post_hook() {
  OUT=$(jq -n --arg c "$1" '{tool_input: {command: $c}}' | "${HOOK_BASH:-bash}" "$HOOKS/post-tool-use-commit.sh" 2>"$T/stderr") && RC=0 || RC=$?
}

post_warns_on_bad_subject_in_chain() {
  run_post_hook 'git add -A && git commit -m "updated stuff"'
  check "$RC" "0"
  [[ $OUT == *"WARNING"*"updated stuff"* ]]
}

post_warns_with_env_prefix() {
  run_post_hook 'GIT_AUTHOR_DATE=now git commit -m "stuff"'
  [[ $OUT == *"WARNING"* ]]
}

post_quiet_on_good_subject() {
  run_post_hook "git commit -m 'fix(cart): #42 round totals'"
  check "$OUT,$RC" ",0"
}

# ---- subagent-stop-handshake -------------------------------------------------

run_stop_hook() {
  OUT=$(jq -n --arg m "$1" --arg a "$2" --argjson active "${3:-false}" \
    '{hook_event_name: "SubagentStop", agent_type: $a, last_assistant_message: $m, stop_hook_active: $active}' |
    ${HOOK_BASH:-bash} "$HOOKS/subagent-stop-handshake.sh" 2>"$T/stderr") && RC=0 || RC=$?
}
blocked() { [ "$(jq -r '.decision // "allow"' <<<"${OUT:-{\}}")" = block ] && echo block || echo allow; }

stop_valid_handshake_passes() {
  run_stop_hook $'Pushed 2 commits.\n\n```\nstatus: done\nreason: pushed 2 commits\nfollow_ups: []\n```' ccmagic:auto-push
  check "$(blocked)" "allow"
}

stop_review_verdict_values() {
  run_stop_hook $'# Ticket-Grounded Review: ENG-1\n...\nstatus: fixable-findings\nreason: 1 CRITICAL\nfollow_ups:\n  - ENG-9\n' ccmagic:auto-review
  check "$(blocked)" "allow"
}

stop_missing_handshake_blocked() {
  run_stop_hook 'All done, the PR is merged.' ccmagic:auto-finish
  check "$(blocked)" "block"
  [[ $(jq -r .reason <<<"$OUT") == *"status: done | needs-human"* ]]
}

stop_wrong_status_for_agent_blocked() {
  run_stop_hook $'status: clean\nreason: ok\nfollow_ups: []' ccmagic:auto-push
  check "$(blocked)" "block"
}

stop_trailing_text_blocked() {
  run_stop_hook $'status: done\nreason: ok\nfollow_ups: []\n\nLet me know if you need anything else.' ccmagic:auto-work
  check "$(blocked)" "block"
}

stop_indented_prose_after_handshake_blocked() {
  run_stop_hook $'status: done\nreason: ok\nfollow_ups: []\n  Anything else I can help with?' ccmagic:auto-work
  check "$(blocked)" "block"
}

stop_missing_follow_ups_blocked() {
  run_stop_hook $'status: needs-human\nreason: tie between reviewers' ccmagic:auto-feedback
  check "$(blocked)" "block"
}

stop_second_attempt_released() {
  run_stop_hook 'still no handshake' ccmagic:auto-finish true
  check "$(blocked)" "allow"
}

stop_other_agents_ignored() {
  run_stop_hook 'no handshake here' Explore
  check "$(blocked)" "allow"
}

# ---- ccm-post-review -----------------------------------------------------------

# run_post_review REPORT [ARGS...]: feed REPORT on stdin to ccm-post-review.
run_post_review() {
  local report=$1
  shift
  OUT=$(printf '%s' "$report" | "$BIN/ccm-post-review" "$@" 2>"$T/stderr") && RC=0 || RC=$?
}
comments_posted() { awk '/^pr comment/ { n++ } END { print n + 0 }' "$GH_FIXTURES/calls.log" 2>/dev/null || echo 0; }
problems() { jq -r '.problems | join("; ")' <<<"$OUT"; }

REVIEW_BODY=$'# Ticket-Grounded Review: ENG-1\n\n## Ticket\n- **ENG-1**: "Add search"\n\n---\n\nNo findings.\n\n'

postreview_valid_report_posts() {
  fx pr-comment 'https://github.com/acme/app/pull/7#issuecomment-99'
  local report=$REVIEW_BODY$'```\nstatus: clean\nreason: no findings\nfollow_ups: []\n```\n'
  run_post_review "$report" 7
  check "$RC,$(jqval .posted),$(jqval .url)" "0,true,https://github.com/acme/app/pull/7#issuecomment-99"
  check "$(jqval .ticket_id),$(jqval .status)" "ENG-1,clean"
  check "$(grep '^pr comment' "$GH_FIXTURES/calls.log")" "pr comment 7 --body-file -"
  check "$(cat "$GH_FIXTURES/pr-comment.stdin")" "$(printf '%s' "$report")"
}

postreview_current_branch_and_list_follow_ups() {
  fx pr-comment 'https://github.com/acme/app/pull/7#issuecomment-100'
  run_post_review $'# Ticket-Grounded Review: #42\n\nfindings\n\n```text\nstatus: fixable-findings\nreason: 1 CRITICAL\nfollow_ups:\n  - ENG-9\n```\n\n\n'
  check "$RC,$(jqval .ticket_id),$(jqval .status)" "0,#42,fixable-findings"
  check "$(grep '^pr comment' "$GH_FIXTURES/calls.log")" "pr comment --body-file -"
}

postreview_wrong_first_line_refused() {
  run_post_review $'Here is the review.\n'"$REVIEW_BODY"$'```\nstatus: clean\nreason: ok\nfollow_ups: []\n```\n' 7
  check "$RC,$(jqval .posted),$(comments_posted)" "1,false,0"
  [[ $(problems) == *"first line must be"* ]]
}

postreview_bad_ticket_id_refused() {
  run_post_review $'# Ticket-Grounded Review: {TICKET-ID}\n\n```\nstatus: clean\nreason: ok\nfollow_ups: []\n```\n' 7
  check "$RC,$(comments_posted)" "1,0"
  [[ $(problems) == *"not a ticket key"* ]]
}

postreview_unfenced_handshake_refused() {
  # The drift #40 fixed: the handshake as bare text after a horizontal rule.
  run_post_review "$REVIEW_BODY"$'---\n\nstatus: clean\nreason: ok\nfollow_ups: []\n' 7
  check "$RC,$(comments_posted)" "1,0"
  [[ $(problems) == *"inside a code fence"* ]]
}

postreview_bad_status_refused() {
  run_post_review "$REVIEW_BODY"$'```\nstatus: clean | fixable-findings | needs-human\nreason: ok\nfollow_ups: []\n```\n' 7
  check "$RC,$(comments_posted)" "1,0"
  [[ $(problems) == *"is not one of: clean fixable-findings needs-human"* ]]
  run_post_review "$REVIEW_BODY"$'```\nstatus: done\nreason: ok\nfollow_ups: []\n```\n' 7
  check "$RC,$(comments_posted)" "1,0"
}

postreview_missing_reason_refused() {
  run_post_review "$REVIEW_BODY"$'```\nstatus: clean\nfollow_ups: []\n```\n' 7
  check "$RC,$(comments_posted)" "1,0"
  [[ $(problems) == *"no \`reason:\` line"* ]]
}

postreview_missing_follow_ups_refused() {
  run_post_review "$REVIEW_BODY"$'```\nstatus: needs-human\nreason: tie between reviewers\n```\n' 7
  check "$RC,$(comments_posted)" "1,0"
  [[ $(problems) == *"no \`follow_ups:\` line"* ]]
}

postreview_keys_out_of_order_refused() {
  run_post_review "$REVIEW_BODY"$'```\nstatus: clean\nfollow_ups: []\nreason: ok\n```\n' 7
  check "$RC,$(comments_posted)" "1,0"
  [[ $(problems) == *"in the order"* ]]
}

postreview_text_after_fence_refused() {
  run_post_review "$REVIEW_BODY"$'```\nstatus: clean\nreason: ok\nfollow_ups: []\n```\n\nLet me know if you need anything else.\n' 7
  check "$RC,$(comments_posted)" "1,0"
  [[ $(problems) == *"nothing after the closing fence"* ]]
}

postreview_text_after_handshake_inside_fence_refused() {
  run_post_review "$REVIEW_BODY"$'```\nstatus: clean\nreason: ok\nfollow_ups: []\nall good\n```\n' 7
  check "$RC,$(comments_posted)" "1,0"
  [[ $(problems) == *"text after the handshake"* ]]
}

postreview_reports_every_problem() {
  run_post_review $'Review:\nstatus: clean\n' 7
  check "$RC,$(jq '.problems | length' <<<"$OUT")" "1,2"
}

postreview_gh_failure() {
  fx_err pr-comment 'no pull requests found for branch "feature/x"' 1
  run_post_review "$REVIEW_BODY"$'```\nstatus: clean\nreason: ok\nfollow_ups: []\n```\n'
  check "$RC,$(jqval .posted),$(comments_posted)" "3,false,1"
  [[ $(jqval .error) == *"no pull requests found"* ]]
}

postreview_usage_error() {
  run_post_review "$REVIEW_BODY" 7 8
  check "$RC" "4"
}

# ---- ccm-pr-threads ------------------------------------------------------------

seed_threads() {
  fx graphql '{"data":{"repository":{"pullRequest":{"number":7,"author":{"login":"me"},
    "reviewThreads":{"pageInfo":{"hasNextPage":false},"nodes":[
      {"id":"T1","isResolved":false,"isOutdated":false,"path":"a.ts","line":3,"comments":{"pageInfo":{"hasNextPage":false},"nodes":[
        {"databaseId":100,"author":{"login":"bot"},"body":"fix this","createdAt":"2026-09-01T00:00:00Z","url":"u1"}]}},
      {"id":"T2","isResolved":false,"isOutdated":false,"path":"b.ts","line":9,"comments":{"pageInfo":{"hasNextPage":false},"nodes":[
        {"databaseId":101,"author":{"login":"bot"},"body":"why?","createdAt":"2026-09-01T00:00:00Z","url":"u2"},
        {"databaseId":102,"author":{"login":"me"},"body":"because","createdAt":"2026-09-02T00:00:00Z","url":"u3"}]}},
      {"id":"T3","isResolved":true,"isOutdated":false,"path":"c.ts","line":1,"comments":{"pageInfo":{"hasNextPage":false},"nodes":[
        {"databaseId":150,"author":{"login":"alice"},"body":"nit","createdAt":"2026-09-03T00:00:00Z","url":"u4"}]}},
      {"id":"T4","isResolved":false,"isOutdated":false,"path":"d.ts","line":2,"comments":{"pageInfo":{"hasNextPage":false},"nodes":[
        {"databaseId":160,"author":null,"body":"from a deleted user","createdAt":"2026-09-04T00:00:00Z","url":"u5"}]}}]},
    "reviews":{"pageInfo":{"hasNextPage":false},"nodes":[{"databaseId":9,"author":{"login":"alice"},"state":"COMMENTED","submittedAt":"2026-09-03T00:00:00Z","body":""}]},
    "comments":{"pageInfo":{"hasNextPage":false},"nodes":[]}}}}}'
}

threads_open_counts_unhandled_threads() {
  seed_threads
  run "$BIN/ccm-pr-threads" 7
  # T2 ends with an author reply but no disposition marker, so it stays open.
  check "$(jqval .open_thread_count),$(jqval '[.threads[] | select(.open) | .id] | join(",")')" "3,T1,T2,T4"
  check "$(jqval .max_review_comment_id),$(jqval .new_comment_count),$(jqval .truncated)" "160,4,false"
}

threads_since_id_marks_new() {
  seed_threads
  run "$BIN/ccm-pr-threads" 7 --since-id 120
  check "$(jqval .new_comment_count),$(jqval '[.threads[] | select(.has_new) | .id] | join(",")')" "2,T3,T4"
}

threads_since_id_must_be_numeric() {
  seed_threads
  run "$BIN/ccm-pr-threads" 7 --since-id abc
  check "$RC" "4"
}

# Repo with base -> fix(a.ts) -> other(b.ts), pushed to a bare remote, and a
# PR whose threads end with author replies carrying the given markers.
# Usage: seed_marked_threads MARKER_T1 MARKER_T2
seed_marked_threads() {
  local g=(git -c user.email=t@t -c user.name=t)
  echo 1 >a.ts; echo 1 >b.ts; git add a.ts b.ts; "${g[@]}" commit -qm "feat: base"
  BASE=$(git rev-parse HEAD)
  echo 2 >a.ts; "${g[@]}" commit -qam "fix: a"
  FIX=$(git rev-parse HEAD)
  echo 2 >b.ts; "${g[@]}" commit -qam "fix: b"
  OTHER=$(git rev-parse HEAD)
  git init -q --bare "$T/remote.git"
  git remote add origin "$T/remote.git"
  git push -q -u origin main
  local m1=$1 m2=$2
  fx graphql "$(jq -n --arg base "$BASE" --arg head "$OTHER" --arg m1 "$m1" --arg m2 "$m2" '
    def c(id; who; body): {databaseId: id, author: {login: who}, body: body, createdAt: "2026-09-01T00:00:00Z", url: "u", originalCommit: {oid: $base}};
    def th(id; path; comments): {id: id, isResolved: false, isOutdated: false, path: path, line: 1,
      comments: {pageInfo: {hasNextPage: false}, nodes: comments}};
    {data: {repository: {pullRequest: {number: 7, headRefOid: $head, author: {login: "me"},
      reviewThreads: {pageInfo: {hasNextPage: false}, nodes: [
        th("T1"; "a.ts"; [c(100; "bot"; "bug here"), c(101; "me"; "Done.\n\n" + $m1)]),
        th("T2"; "a.ts"; [c(200; "bot"; "and here"), c(201; "me"; "Reply.\n\n" + $m2)])]},
      reviews: {pageInfo: {hasNextPage: false}, nodes: []},
      comments: {pageInfo: {hasNextPage: false}, nodes: []}}}}}')"
}

threads_unmarked_author_reply_stays_open() {
  seed_marked_threads "will fix" "<!-- ccmagic:disposition=answered -->"
  run "$BIN/ccm-pr-threads" 7
  check "$(jqval '[.threads[] | .open] | join(",")'),$(jqval .open_thread_count)" "true,false,1"
  check "$(jqval '.threads[1].disposition')" "answered"
}

threads_verified_fix_is_handled() {
  seed_marked_threads "PLACEHOLDER" "<!-- ccmagic:disposition=deferred ticket=ENG-4 -->"
  fx graphql "$(sed "s/PLACEHOLDER/<!-- ccmagic:disposition=fixed commit=$FIX -->/" "$GH_FIXTURES/graphql.json")"
  run "$BIN/ccm-pr-threads" 7
  check "$(jqval '.threads[0].fix_verified'),$(jqval '.threads[0].open'),$(jqval .open_thread_count)" "true,false,0"
}

threads_fix_touching_other_file_stays_open() {
  seed_marked_threads "PLACEHOLDER" "<!-- ccmagic:disposition=declined -->"
  fx graphql "$(sed "s/PLACEHOLDER/<!-- ccmagic:disposition=fixed commit=$OTHER -->/" "$GH_FIXTURES/graphql.json")"
  run "$BIN/ccm-pr-threads" 7
  check "$(jqval '.threads[0].fix_verified'),$(jqval '.threads[0].open')" "false,true"
}

threads_fix_older_than_comment_stays_open() {
  seed_marked_threads "PLACEHOLDER" "<!-- ccmagic:disposition=declined -->"
  fx graphql "$(sed "s/PLACEHOLDER/<!-- ccmagic:disposition=fixed commit=$BASE -->/" "$GH_FIXTURES/graphql.json")"
  run "$BIN/ccm-pr-threads" 7
  check "$(jqval '.threads[0].open')" "true"
}

threads_unknown_fix_commit_stays_open() {
  seed_marked_threads "<!-- ccmagic:disposition=fixed commit=deadbeefdeadbeef -->" "<!-- ccmagic:disposition=declined -->"
  run "$BIN/ccm-pr-threads" 7
  check "$(jqval '.threads[0].fix_verified'),$(jqval '.threads[0].open')" "false,true"
}

threads_reviewer_reply_after_marker_reopens() {
  seed_marked_threads "<!-- ccmagic:disposition=declined -->" "<!-- ccmagic:disposition=declined -->"
  fx graphql "$(jq '.data.repository.pullRequest.reviewThreads.nodes[0].comments.nodes += [{databaseId: 102, author: {login: "bot"}, body: "I disagree", createdAt: "2026-09-02T00:00:00Z", url: "u", originalCommit: null}]' "$GH_FIXTURES/graphql.json")"
  run "$BIN/ccm-pr-threads" 7
  check "$(jqval '.threads[0].open'),$(jqval '.threads[0].disposition')" "true,null"
}

reply_fixed_posts_marker_and_resolves() {
  seed_marked_threads "x" "y"
  fx reply '{"id":555}'
  fx graphql-resolve '{"data":{"resolveReviewThread":{"thread":{"isResolved":true}}}}'
  run "$BIN/ccm-pr-reply" 7 101 --disposition fixed --commit "$FIX" --body "Fixed in this commit."
  check "$(jqval .reply_id),$(jqval .thread_id),$(jqval .resolved),$RC" "555,T1,true,0"
  grep -q "comments/100/replies" "$GH_FIXTURES/calls.log"
  grep -q "ccmagic:disposition=fixed commit=$FIX" "$GH_FIXTURES/calls.log"
}

reply_fixed_refuses_unpushed_commit() {
  seed_marked_threads "x" "y"
  echo 3 >a.ts; git -c user.email=t@t -c user.name=t commit -qam "fix: local only"
  run "$BIN/ccm-pr-reply" 7 100 --disposition fixed --commit "$(git rev-parse HEAD)" --body "Fixed."
  check "$RC" "1"
  [[ $(jqval .error) == *"not pushed"* ]]
}

reply_deferred_needs_ticket() {
  seed_marked_threads "x" "y"
  run "$BIN/ccm-pr-reply" 7 100 --disposition deferred --body "Later."
  check "$RC" "4"
}

reply_declined_does_not_resolve() {
  seed_marked_threads "x" "y"
  fx reply '{"id":556}'
  run "$BIN/ccm-pr-reply" 7 200 --disposition declined --body "Convention says otherwise."
  check "$(jqval .resolved),$RC" "false,0"
  ! grep -q resolveReviewThread "$GH_FIXTURES/calls.log"
}

threads_graphql_error() {
  fx_err graphql 'HTTP 502' 1
  run "$BIN/ccm-pr-threads" 7
  check "$RC" "3"
}

# ---- ccm-validate ----------------------------------------------------------

# seed_pkg SCRIPTS_JSON: a package.json with these scripts, plus npm, pnpm,
# and yarn stubs on PATH that log the call to $T/pm.log and run the script, so
# the tests don't depend on Node being installed.
seed_pkg() {
  printf '{"name":"x","scripts":%s}\n' "$1" >package.json
  mkdir -p "$T/bin"
  local pm
  for pm in npm pnpm yarn; do
    # shellcheck disable=SC2016 # the stub expands these, not this shell
    printf '#!/bin/sh\necho "%s $*" >>"%s/pm.log"\nexec sh -c "$(jq -r --arg s "$2" %s package.json)"\n' \
      "$pm" "$T" "'.scripts[\$s]'" >"$T/bin/$pm"
    chmod +x "$T/bin/$pm"
  done
  export PATH="$T/bin:$PATH"
}

# check_status NAME: print the status of one check from OUT.
check_status() { jq -r --arg n "$1" '.checks[] | select(.name == $n) | .status' <<<"$OUT"; }

validate_pass_and_fail_by_exit_code() {
  seed_pkg '{"lint":"true","test":"false"}'
  run "$BIN/ccm-validate"
  check "$(jqval .status),$RC,$(check_status lint),$(check_status test),$(check_status build)" \
    "fail,1,passed,failed,skipped"
  check "$(jq -r '.checks[] | select(.name == "test") | .command' <<<"$OUT")" "npm run test"
}

validate_failed_lint_is_not_masked_by_later_pass() {
  seed_pkg '{"lint":"echo lint broke; exit 3","test":"true","build":"true"}'
  run "$BIN/ccm-validate"
  check "$(jqval .status),$RC,$(check_status lint),$(check_status build)" "fail,1,failed,passed"
  check "$(jq -r '.checks[] | select(.name == "lint") | .exit_code' <<<"$OUT")" "3"
  [[ $(jq -r '.checks[] | select(.name == "lint") | .tail' <<<"$OUT") == *"lint broke"* ]]
  grep -q "lint broke" "$(jq -r '.checks[] | select(.name == "lint") | .log' <<<"$OUT")"
}

validate_all_pass() {
  seed_pkg '{"lint":"true","test":"true"}'
  run "$BIN/ccm-validate"
  check "$(jqval .status),$RC,$(jq '[.checks[] | select(.status == "passed")] | length' <<<"$OUT")" "pass,0,2"
}

validate_config_beats_detection() {
  seed_pkg '{"lint":"false"}'
  config 'validate_lint: echo from-config'
  run "$BIN/ccm-validate" --only lint
  check "$(jqval .status),$(jqval '.checks[0].command'),$(jqval '.checks[0].source')" \
    "pass,echo from-config,config"
}

validate_none_disables_check() {
  seed_pkg '{"lint":"true","test":"false"}'
  config 'validate_test: none'
  run "$BIN/ccm-validate"
  check "$(jqval .status),$(check_status test)" "pass,skipped"
  check "$(jq -r '.checks[] | select(.name == "test") | .reason' <<<"$OUT")" "disabled in config"
}

validate_pnpm_lockfile_selects_pnpm() {
  seed_pkg '{"lint":"true"}'
  touch pnpm-lock.yaml
  run "$BIN/ccm-validate" --only lint
  check "$(jqval .status),$(jqval '.checks[0].command')" "pass,pnpm run lint"
  check "$(command cat "$T/pm.log")" "pnpm run lint"
}

validate_nothing_to_run() {
  run "$BIN/ccm-validate"
  check "$(jqval .status),$RC,$(jq -r '[.checks[].reason] | unique | join(",")' <<<"$OUT")" \
    "nothing-to-run,2,not configured"
}

validate_timeout_fails_check() {
  if ! command -v timeout >/dev/null && ! command -v gtimeout >/dev/null; then
    echo "  (skipped: no timeout binary)"; return 0
  fi
  config 'validate_test: sleep 5
validate_timeout_seconds: 1'
  run "$BIN/ccm-validate" --only test
  check "$(jqval .status),$RC,$(jqval '.checks[0].status')" "fail,1,failed"
  [[ $(jqval '.checks[0].reason') == "timed out"* ]]
}

validate_only_runs_subset() {
  seed_pkg '{"lint":"false","test":"true"}'
  run "$BIN/ccm-validate" --only test
  check "$(jqval .status),$RC,$(jq -r '[.checks[].name] | join(",")' <<<"$OUT")" "pass,0,test"
  run "$BIN/ccm-validate" --only lint,bogus
  check "$RC" "4"
}

validate_list_does_not_run() {
  seed_pkg '{"lint":"touch ran","test":"true"}'
  run "$BIN/ccm-validate" --list
  check "$(jqval .status),$RC,$(check_status lint),$(check_status format)" "listed,0,planned,skipped"
  [ ! -e ran ]
  rm package.json
  run "$BIN/ccm-validate" --list
  check "$(jqval .status),$RC" "nothing-to-run,2"
}

validate_detects_makefile_and_go() {
  printf 'lint:\n\ttrue\n' >Makefile
  echo 'module x' >go.mod
  run "$BIN/ccm-validate" --list
  # shellcheck disable=SC2016 # the literal command text
  check "$(jq -r '[.checks[] | .command // "-"] | join("|")' <<<"$OUT")" \
    'out=$(gofmt -l .) && printf "%s" "$out" && test -z "$out"|make lint|-|go test ./...|go build ./...'
}

validate_pyproject_needs_tool_config() {
  printf '[project]\nname = "x"\n\n[tool.pytest.ini_options]\n' >pyproject.toml
  run "$BIN/ccm-validate" --list
  check "$(jq -r '[.checks[] | .command // "-"] | join("|")' <<<"$OUT")" '-|-|-|pytest|-'
  touch ruff.toml
  run "$BIN/ccm-validate" --list
  check "$(jq -r '[.checks[] | .command // "-"] | join("|")' <<<"$OUT")" 'ruff format --check|ruff check|-|pytest|-'
}

# ---- run -------------------------------------------------------------------

for fn in $(declare -F | awk '{print $3}' | grep -E '^(context|ci|merge_gate|guard|post|postreview|stop|threads|reply|validate)_'); do
  t "$fn" "$fn"
done

echo
echo "$PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  printf '  %s\n' "${FAILED[@]}"
  exit 1
fi
