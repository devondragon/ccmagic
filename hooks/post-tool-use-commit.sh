#!/usr/bin/env bash
# PostToolUse hook: validates commit message format after git commit commands.
# Receives tool input as JSON on stdin. Non-blocking — always exits 0.
#
# Canonical commit types and ticket-ID regex are documented in the ccmagic
# plugin's .claude/CLAUDE.md (not the consuming project's .claude/CLAUDE.md).
# This script hardcodes the same regex — keep them in sync if you change either.

set -euo pipefail

INPUT=$(cat)

# Extract the command. Prefer jq (robust against escapes); fall back to Perl.
if command -v jq >/dev/null 2>&1; then
  COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
else
  # Fallback: handle JSON-escaped quotes (\") inside the command field.
  # Captures everything between "command":" and the next unescaped ".
  COMMAND=$(printf '%s' "$INPUT" | perl -ne 'if (/"command"\s*:\s*"((?:[^"\\]|\\.)*)"/) { my $c = $1; $c =~ s/\\(.)/$1/g; print $c; exit }' 2>/dev/null || true)
fi

# Only act on `git commit` invocations.
if ! printf '%s' "$COMMAND" | grep -qE '^[[:space:]]*git[[:space:]]+commit\b'; then
  exit 0
fi

# Extract the commit message. Handle three forms:
#   1. git commit -m "subject"
#   2. git commit -m "$(cat <<'EOF' ... EOF )"  (HEREDOC)
#   3. git commit (no -m; uses editor) → skip validation
COMMIT_MSG=""

# Form 2: HEREDOC — grab the first non-empty line between the EOF markers as the subject.
if printf '%s' "$COMMAND" | grep -qE "<<'?EOF'?"; then
  COMMIT_MSG=$(printf '%s' "$COMMAND" | awk "
    /<<'?EOF'?/ { capturing = 1; next }
    /^[[:space:]]*EOF[[:space:]]*\)?\"?[[:space:]]*$/ { capturing = 0 }
    capturing && NF > 0 { print; exit }
  ")
fi

# Form 1: inline -m "..." — only try if HEREDOC didn't yield anything.
if [ -z "$COMMIT_MSG" ]; then
  COMMIT_MSG=$(printf '%s' "$COMMAND" | perl -ne 'if (/-m\s+"((?:[^"\\]|\\.)*)"/) { my $m = $1; $m =~ s/\\(.)/$1/g; my @lines = split /\n/, $m; print $lines[0]; exit }' 2>/dev/null || true)
fi

# Form 3: nothing extracted — likely editor-driven. Skip silently.
if [ -z "$COMMIT_MSG" ]; then
  exit 0
fi

# Skip git-generated or intentionally-non-conventional subjects. The hook is a
# helper, not a gate — no point warning on commits the user can't reasonably
# reformat (merges, reverts, fixup/squash autosquash markers, initial commits).
case "$COMMIT_MSG" in
  Merge\ *|Revert\ *|"Revert \""*|fixup!\ *|squash!\ *|amend!\ *|"Initial commit"*) exit 0 ;;
esac

# Canonical pattern: {TYPE}({scope})!?: [TICKET-ID] {description}
# Types match the list documented in .claude/CLAUDE.md.
# Scope, breaking-change marker (`!`), ticket ID, and the space before the
# description are all optional.
# Ticket-ID regex: [A-Z][A-Z0-9]+-[0-9]+ (or a plain integer for GitHub issues)
PATTERN='^(feat|fix|docs|style|refactor|test|chore|perf|ci)(\([a-zA-Z0-9_-]+\))?!?: (([A-Z][A-Z0-9]+-[0-9]+|#?[0-9]+) )?.+'

if ! printf '%s' "$COMMIT_MSG" | grep -qE "$PATTERN"; then
  echo ""
  echo "WARNING: Commit message does not follow the project's conventional-commit format."
  echo "Expected format: {TYPE}({scope})!?: [TICKET-ID] {description}"
  echo "  Types: feat, fix, docs, style, refactor, test, chore, perf, ci"
  echo "  Scope, breaking-change marker (!), and ticket ID are optional."
  echo "  Example: feat(catalog): PROJ-123 add configurable product price override"
  echo "  Example: fix(checkout): #42 prevent duplicate order submission"
  echo "  Example: feat(api)!: drop deprecated /v1 endpoints"
  echo "  Example: docs(api): add endpoint documentation for returns"
  echo ""
  echo "Actual subject: $COMMIT_MSG"
  echo ""
fi

exit 0
