#!/usr/bin/env bash
# tests/relay-smoke.sh: run /ccmagic:auto-ticket end to end on the prompt-relay
# transport against a sandbox GitHub repo, then check the relay contract.
#
# Usage: tests/relay-smoke.sh [--repo OWNER/NAME] [--budget USD] [--narrow-bash] [--keep]
#   --repo         sandbox repo (default devondragon/ccmagic-relay-sandbox, or $CCM_RELAY_REPO)
#   --budget       --max-budget-usd for the claude run (default 25)
#   --narrow-bash  grant only narrow Bash rules instead of plain Bash, so the run
#                  checks the skills' own allowed-tools grants
#   --keep         leave the PR open and the clone on disk for inspection
#
# What it does: clones the sandbox under a throwaway HOME (no user plugins, no
# claude.ai connectors, and --strict-mcp-config, so no Linear MCP exists), makes
# a Cyrus-style branch, and runs `claude -p` with this checkout as the plugin
# and the Cyrus prompt template from docs/cyrus-deployment.md, filled with a fake
# Linear ticket. The top-level session writes .ccmagic-ticket.md and invokes
# /ccmagic:auto-ticket, as Cyrus does. The sandbox's .claude/ccmagic.local.md
# pins tracker: linear and merge_owner: reeve, so the run hands off without
# merging. By default tools are granted as Cyrus grants them (plain Bash
# included), so the run does not test the skills' own narrower allowed-tools
# grants. --narrow-bash grants Bash only as git, gh, make, and the ccm-*
# scripts by bare name (the set docs/cyrus-deployment.md lists for a harness
# without plain Bash), so anything else a skill runs, such as the handoff-file
# rm, must be granted by that skill.
#
# Checks: no Linear tool or server in the session; the handoff file is deleted
# and in no commit; a PR was opened; the final output carries the relay block
# and a Requested state: line; no rm was denied; with --narrow-bash, no ccm-*
# script call was denied. The sandbox PR is closed and its branch deleted
# afterward unless --keep. The stream-json log is kept.
#
# Not run by tests/run.sh or CI: it calls the model and pushes to GitHub, and a
# run takes several minutes. It can't check what Cyrus itself does with the
# final message; that needs the live throwaway ticket in docs/cyrus-deployment.md.
#
# Auth: the same token lookup as evals/run.sh (CLAUDE_CODE_OAUTH_TOKEN, the
# keychain item ccmagic-eval-oauth-token, or ANTHROPIC_API_KEY), and gh's own
# login, passed to the run as GH_TOKEN.
#
# Exit codes: 0 all checks passed, 1 a check failed, 3 a tool is missing,
# 4 no credential.

set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
repo=${CCM_RELAY_REPO:-devondragon/ccmagic-relay-sandbox}
budget=25
keep=false
narrow=false

while [ $# -gt 0 ]; do
  case $1 in
    --repo) repo=$2; shift 2 ;;
    --budget) budget=$2; shift 2 ;;
    --keep) keep=true; shift ;;
    --narrow-bash) narrow=true; shift ;;
    -h|--help) sed -n '2,/^[^#]/{/^#/p;}' "$0" | cut -c3-; exit 0 ;;
    *) echo "relay-smoke: unknown option $1" >&2; exit 3 ;;
  esac
done

for tool in claude gh git jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "relay-smoke: $tool not found" >&2; exit 3; }
done

if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  if command -v security >/dev/null 2>&1 &&
    token=$(security find-generic-password -s ccmagic-eval-oauth-token -w 2>/dev/null); then
    export CLAUDE_CODE_OAUTH_TOKEN=$token
  else
    echo "relay-smoke: no Claude credential; see evals/README.md for the keychain setup." >&2
    exit 4
  fi
fi
GH_TOKEN=${GH_TOKEN:-$(gh auth token)}
export GH_TOKEN
gh_bin=$(command -v gh)

id=SBX-$(date +%H%M%S)
branch=sbx-${id#SBX-}-add-farewell
work=$(mktemp -d "${TMPDIR:-/tmp}/ccmagic-relay-smoke.XXXXXX")
home=$work/home
clone=$work/repo
log=${TMPDIR:-/tmp}/ccmagic-relay-smoke-$id.jsonl
mkdir -p "$home"
trap '[ "$keep" = true ] || rm -rf "$work"' EXIT

# Keep the git identity; route git's HTTPS auth through gh and GH_TOKEN, since
# the throwaway HOME has no keychain or gh config.
if [ -f "$HOME/.gitconfig" ]; then
  cp "$HOME/.gitconfig" "$home/.gitconfig"
fi
gh repo clone "$repo" "$clone" -- -q
git -C "$clone" config --local --replace-all credential.helper ''
git -C "$clone" config --local --add credential.helper "!$gh_bin auth git-credential"
git -C "$clone" checkout -q -b "$branch"

title="Add a farewell function"
description="Add a \`farewell NAME\` function to greet.sh that prints \`Goodbye, NAME!\`.

Acceptance criteria:
- \`farewell World\` prints \`Goodbye, World!\`
- test.sh covers farewell, and \`make test\` passes"

# The Cyrus prompt template (docs/cyrus-deployment.md), filled in.
prompt="First, write the ticket content to a handoff file the forked skill can read.
\`/ccmagic:auto-ticket\` runs as a forked skill and only sees its own invocation
arguments, not this prompt, so the ticket content must be handed off via a file
in the working directory, which the fork shares.

Write a file named \`.ccmagic-ticket.md\` in the working directory
($clone) with exactly this content:
~~~
$title

$description
~~~

Then run:

/ccmagic:auto-ticket $id

Environment (already prepared by Cyrus; do not re-create the branch or worktree):
- Working directory: $clone
- Branch: $branch
- Base branch: main

When the command finishes, its output ends with a block delimited by:
=== FINAL MESSAGE TO RELAY (reproduce verbatim) ===
...
=== END FINAL MESSAGE ===

Reproduce the contents of that block verbatim as your own final message.
Do not summarize, paraphrase, or add commentary around it."

# The tools Cyrus grants (docs/cyrus-deployment.md), minus its MCP servers.
# --narrow-bash swaps plain Bash for the rules a locked-down harness grants
# (the sandbox's checks run through make) plus the other commands and every
# ccm-* script by bare name, as docs/cyrus-deployment.md lists them.
allowed=(Read Edit Write Bash Glob Grep Task Skill TodoWrite)
if [ "$narrow" = true ]; then
  allowed=(Read Edit Write 'Bash(git:*)' 'Bash(gh:*)' 'Bash(make:*)' 'Bash(timeout:*)' 'Bash(gtimeout:*)'
    'Bash(mkdir:*)' 'Bash(mktemp:*)' 'Bash(codex:*)' Glob Grep Task Skill TodoWrite)
  for script in "$root"/bin/ccm-*; do
    case $script in *.sh) continue ;; esac
    allowed+=("Bash($(basename "$script") *)")
  done
fi

# Same PATH handling as evals/run.sh: this checkout's bin/ first, installed
# plugins' bin/ directories dropped.
clean_path=$(printf '%s' "$PATH" | tr ':' '\n' | grep -v '/\.claude/plugins/' | paste -sd: -)

echo "relay-smoke: $id on $repo, branch $branch; log: $log"
echo "relay-smoke: running auto-ticket (several minutes)..."
(
  cd "$clone"
  PATH=$root/bin:$clean_path HOME=$home claude -p "$prompt" \
    --plugin-dir "$root" \
    --strict-mcp-config --mcp-config '{"mcpServers":{}}' \
    --permission-mode default \
    --allowedTools "${allowed[@]}" \
    --output-format stream-json --verbose \
    --max-budget-usd "$budget" </dev/null
) >"$log" 2>&1 || echo "relay-smoke: claude exited non-zero; checking what it left"

failed=0
pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; failed=1; }

# trim S: S without leading and trailing whitespace.
trim() {
  local t=$1
  t=${t#"${t%%[![:space:]]*}"}
  printf '%s' "${t%"${t##*[![:space:]]}"}"
}

init=$(jq -c 'select(.type == "system" and .subtype == "init")' "$log" 2>/dev/null | head -1)
last_result=$(jq -cs '[.[] | select(.type == "result")] | last // {}' "$log" 2>/dev/null || echo '{}')
result=$(jq -r '.result // empty' <<<"$last_result")
# denied_commands: the command of every denied Bash call, subagents' included.
# The log has a permission_denied event per call but not its command, and a
# subagent's calls are only in its transcript under the throwaway HOME.
denied_commands() {
  local ids
  ids=$(jq -R -c -s '[split("\n")[] | fromjson? | select(.type == "system" and .subtype == "permission_denied" and .tool_name == "Bash") | .tool_use_id]' "$log" 2>/dev/null) || return 0
  [ "$ids" != "[]" ] || return 0
  { cat "$log"; find "$home/.claude/projects" -name '*.jsonl' -exec cat {} + 2>/dev/null; } |
    jq -R -r --argjson ids "$ids" 'fromjson? | select(.type == "assistant") | .message.content[]?
      | select(.type == "tool_use" and (.id as $i | any($ids[]; . == $i))) | "\(.id)\t\(.input.command)"' 2>/dev/null |
    awk -F'\t' '!seen[$1]++ { sub(/^[^\t]*\t/, ""); print }' || true
}
# The result message's permission_denials covers the top-level session, in case
# a build emits no permission_denied events.
denied=$( { denied_commands; jq -r '(.permission_denials // [])[] | select(.tool_name == "Bash") | .tool_input.command // empty' <<<"$last_result" 2>/dev/null; } | awk '!seen[$0]++')
# The relay block is in auto-ticket's own output, which the top-level session
# gets back as a tool result. Match the delimiters as whole lines, so a Read of
# the contract (which quotes them with line numbers) doesn't count, and keep the
# last block.
block=$(jq -r 'select(.type == "user") | .message.content[]? | select(.type == "tool_result")
    | if (.content | type) == "array" then (.content | map(.text // "") | join("\n")) else (.content // "") end' "$log" 2>/dev/null |
  awk '$0 == "=== FINAL MESSAGE TO RELAY (reproduce verbatim) ===" { cap = 1; buf = ""; next }
       $0 == "=== END FINAL MESSAGE ===" && cap { last = buf; cap = 0; next }
       cap { buf = buf $0 "\n" }
       END { printf "%s", last }')

if [ -z "$init" ]; then
  fail "session started (no init message in the log)"
else
  linear=$(jq -r '(.tools // [])[], ((.mcp_servers // [])[] | .name)' <<<"$init" | grep -i linear || true)
  if [ -z "$linear" ]; then pass "no Linear MCP in the session"; else fail "Linear MCP present, so this was not a relay run: $linear"; fi
fi

if [ -e "$clone/.ccmagic-ticket.md" ]; then
  fail "handoff file deleted (.ccmagic-ticket.md is still in the working tree)"
else
  pass "handoff file deleted"
fi

pr=$(gh pr list --repo "$repo" --state all --search "$id" --json number,url,headRefName --jq '.[0] // empty')
if [ -z "$pr" ]; then
  fail "PR opened (none found for $id)"
else
  pr_number=$(jq -r .number <<<"$pr")
  pass "PR opened: $(jq -r .url <<<"$pr")"
fi

committed=$(git -C "$clone" log --all --not origin/main --name-only --format= 2>/dev/null | grep -Fx .ccmagic-ticket.md || true)
if [ -n "${pr_number:-}" ]; then
  committed+=$(gh pr view "$pr_number" --repo "$repo" --json files --jq '.files[].path' | grep -Fx .ccmagic-ticket.md || true)
fi
if [ -z "$committed" ]; then pass "handoff file in no commit"; else fail "handoff file in no commit (it was committed)"; fi

if [ -n "$(trim "$block")" ]; then
  pass "auto-ticket output carries the relay block"
  if [ "$(trim "$block")" = "$(trim "$result")" ]; then
    pass "final message reproduces the block verbatim"
  else
    trim "$block" >"$log.block"
    trim "$result" >"$log.final"
    fail "final message reproduces the block verbatim (diff $log.block $log.final)"
  fi
  if grep -q 'Requested state:' <<<"$block"; then pass "Requested state: line in the block"; else fail "Requested state: line in the block"; fi
else
  fail "auto-ticket output carries the relay block"
fi

rm_denied=$(grep -E '(^|[;&|[:space:]])rm[[:space:]]' <<<"$denied" || true)
if [ -z "$rm_denied" ]; then pass "no rm denied"; else fail "no rm denied: $rm_denied"; fi

if [ "$narrow" = true ]; then
  ccm_denied=$(grep -E '(^|[/;&|[:space:]])ccm-[a-z-]+' <<<"$denied" || true)
  if [ -z "$ccm_denied" ]; then pass "no ccm-* script denied"; else fail "no ccm-* script denied: $ccm_denied"; fi
fi

[ -z "$denied" ] || printf 'info denied Bash commands:\n%s\n' "$denied"
outcome=$(grep -o '"outcome": *"[a-z-]*"' <<<"$block" | tail -1 || true)
printf 'info run outcome: %s\n' "${outcome:-not found in the relay block}"

if [ -n "${pr_number:-}" ]; then
  if [ "$keep" = true ]; then
    echo "relay-smoke: --keep: PR #$pr_number left open, clone at $clone"
  else
    gh pr close "$pr_number" --repo "$repo" --delete-branch --comment "Closed by ccmagic relay-smoke ($id)." >/dev/null ||
      echo "relay-smoke: could not close PR #$pr_number" >&2
  fi
elif [ "$keep" != true ]; then
  git -C "$clone" push -q origin --delete "$branch" 2>/dev/null || true
fi

if [ "$failed" = 0 ]; then echo "relay-smoke: all checks passed"; else echo "relay-smoke: checks failed; see $log"; fi
exit "$failed"
