#!/usr/bin/env bash
# evals/run.sh: run the eval suite under a throwaway HOME.
#
# Usage: evals/run.sh [claude plugin eval options...]
#   evals/run.sh                                     full suite
#   evals/run.sh --case 02-quick-off-by-one --runs 3 one case
#
# Why: cases 01 to 05 grant Bash, and the eval tool refuses a Bash-granting run
# when ~/.docker holds a symbolic link. Docker Desktop keeps symlinks in
# ~/.docker/bin and ~/.docker/cli-plugins, and DOCKER_CONFIG doesn't change what
# the tool checks. Running with HOME set to an empty temporary directory avoids
# the check without touching the real ~/.docker. The directory is removed on exit.
# It also replaces installed plugins' bin/ directories on PATH with this
# checkout's bin/, so a bare `ccm-*` name runs the plugin under test.
#
# Auth: with a different HOME, Claude Code can't read its keychain login, so the
# run needs a token in the environment. In order of preference:
#   CLAUDE_CODE_OAUTH_TOKEN   already exported
#   macOS keychain item "ccmagic-eval-oauth-token" (see evals/README.md)
#   ANTHROPIC_API_KEY         already exported (billed per use)
#
# Always passed: --ablation with-without --judge-model opus --trust-plugin
# --allow-tools Bash. Anything you pass comes after them.
#
# Exit codes: the eval tool's own (0 pass, 1 below threshold, 2 cost ceiling),
# or 4 when no credential was found.

set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

case ${1:-} in
  -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
esac

if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  if command -v security >/dev/null 2>&1 &&
    token=$(security find-generic-password -s ccmagic-eval-oauth-token -w 2>/dev/null); then
    export CLAUDE_CODE_OAUTH_TOKEN=$token
  else
    echo "evals/run.sh: no credential. Run 'claude setup-token', then store the token with:" >&2
    echo "  security add-generic-password -a \"\$USER\" -s ccmagic-eval-oauth-token -w" >&2
    echo "(it prompts for the token), or export CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY." >&2
    exit 4
  fi
fi

eval_home=$(mktemp -d "${TMPDIR:-/tmp}/ccmagic-eval-home.XXXXXX")
trap 'rm -rf "$eval_home"' EXIT
# Keep the git identity for anything in a run that commits.
if [ -f "$HOME/.gitconfig" ]; then
  cp "$HOME/.gitconfig" "$eval_home/.gitconfig"
fi

# Drop installed plugins' bin/ directories from PATH. A Claude Code session
# puts them there, and a run started from one would otherwise resolve a bare
# `ccm-*` name to the installed plugin instead of the one under test. Then put
# the plugin under test's bin/ first, as Claude Code does for an enabled plugin;
# the eval tool doesn't, so a bare name would otherwise not resolve at all.
clean_path=$(printf '%s' "$PATH" | tr ':' '\n' | grep -v '/\.claude/plugins/' | paste -sd: -)
clean_path=$root/bin:$clean_path

PATH=$clean_path HOME=$eval_home claude plugin eval "$root" \
  --ablation with-without --judge-model opus --trust-plugin --allow-tools Bash "$@"
