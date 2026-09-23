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
  OUT=$(printf '%s' "$input" | "${HOOK_BASH:-bash}" "$HOOKS/pre-tool-use-guard.sh" 2>"$T/stderr")
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
  OUT=$(jq -n --arg c "$1" '{tool_input: {command: $c}}' | "${HOOK_BASH:-bash}" "$HOOKS/post-tool-use-commit.sh" 2>"$T/stderr")
  RC=$?
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
    ${HOOK_BASH:-bash} "$HOOKS/subagent-stop-handshake.sh" 2>"$T/stderr")
  RC=$?
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

threads_open_counts_unanswered_only() {
  seed_threads
  run "$BIN/ccm-pr-threads" 7
  check "$(jqval .open_thread_count),$(jqval '[.threads[] | select(.open) | .id] | join(",")')" "2,T1,T4"
  check "$(jqval .max_review_comment_id),$(jqval .new_comment_count),$(jqval .truncated)" "160,4,false"
}

threads_since_id_marks_new() {
  seed_threads
  run "$BIN/ccm-pr-threads" 7 --since-id 120
  check "$(jqval .new_comment_count),$(jqval '[.threads[] | select(.has_new) | .id] | join(",")')" "2,T3,T4"
}

threads_graphql_error() {
  fx_err graphql 'HTTP 502' 1
  run "$BIN/ccm-pr-threads" 7
  check "$RC" "3"
}

# ---- run -------------------------------------------------------------------

for fn in $(declare -F | awk '{print $3}' | grep -E '^(context|ci|merge_gate|guard|post|stop|threads)_'); do
  t "$fn" "$fn"
done

echo
echo "$PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  printf '  %s\n' "${FAILED[@]}"
  exit 1
fi
