#!/usr/bin/env bash
# PostToolUse hook: validates commit message format after git commit commands.
# Receives tool input as JSON on stdin. Non-blocking — always exits 0.
#
# Autonomous runs never reach this warning with a bad subject: the PreToolUse
# guard (pre-tool-use-guard.sh) denies those commits before they happen. This
# hook covers interactive use, where the format is advice, not a rule.
#
# The pattern lives in hooks/lib-commit.sh; the canonical types and ticket-ID
# regex are documented in the ccmagic plugin's .claude/CLAUDE.md. Keep them in
# sync if you change either.

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=hooks/lib-commit.sh
. "$here/lib-commit.sh"

INPUT=$(cat)

# Extract the command. Prefer jq (robust against escapes); fall back to Perl.
if command -v jq >/dev/null 2>&1; then
  COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
else
  # Fallback: handle JSON-escaped quotes (\") inside the command field.
  # Captures everything between "command":" and the next unescaped ".
  COMMAND=$(printf '%s' "$INPUT" | perl -ne 'if (/"command"\s*:\s*"((?:[^"\\]|\\.)*)"/) { my $c = $1; $c =~ s/\\(.)/$1/g; print $c; exit }' 2>/dev/null || true)
fi

ccm_is_git_commit "$COMMAND" || exit 0

# Editor-driven commits and -F <file> can't be read from the command; skip.
COMMIT_MSG=$(ccm_commit_subject "$COMMAND")
[ -n "$COMMIT_MSG" ] || exit 0

# The hook is a helper, not a gate — no point warning on commits the user
# can't reasonably reformat (merges, reverts, fixup/squash markers, initial commits).
ccm_commit_subject_exempt "$COMMIT_MSG" && exit 0

if ! printf '%s' "$COMMIT_MSG" | grep -qE "$CCM_COMMIT_PATTERN"; then
  echo ""
  echo "WARNING: Commit message does not follow the project's conventional-commit format."
  echo "$CCM_COMMIT_FORMAT_HELP"
  echo ""
  echo "Actual subject: $COMMIT_MSG"
  echo ""
fi

exit 0
