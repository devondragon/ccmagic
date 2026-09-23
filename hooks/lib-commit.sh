# shellcheck shell=bash
# shellcheck disable=SC2034  # variables are used by the scripts that source this file
# Shared by the commit hooks. Sourced, never executed.

# Conventional-commit subject: {TYPE}({scope})!?: [TICKET-ID] {description}
# Types match the list documented in the plugin's .claude/CLAUDE.md. Scope,
# breaking-change marker (!), ticket ID (Linear/JIRA key or GitHub integer),
# and the space before the description are all optional.
CCM_COMMIT_PATTERN='^(feat|fix|docs|style|refactor|test|chore|perf|ci)(\([a-zA-Z0-9_-]+\))?!?: (([A-Z][A-Z0-9]+-[0-9]+|#?[0-9]+) )?.+'

CCM_COMMIT_FORMAT_HELP='Expected format: {TYPE}({scope})!?: [TICKET-ID] {description}
  Types: feat, fix, docs, style, refactor, test, chore, perf, ci
  Scope, breaking-change marker (!), and ticket ID are optional.
  Example: feat(catalog): PROJ-123 add configurable product price override
  Example: fix(checkout): #42 prevent duplicate order submission
  Example: feat(api)!: drop deprecated /v1 endpoints
  Example: docs(api): add endpoint documentation for returns'

# True when the command runs `git commit` as a command (at the start of a
# line or after ; & | ( ), not merely mentions it inside a string. Leading
# VAR=value assignments and `git -C dir` are allowed, as in the PreToolUse guard.
ccm_is_git_commit() {
  printf '%s' "$1" | grep -qE '(^|[;&|(])[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*git([[:space:]]+-[cC][[:space:]]+[^[:space:]]+)*[[:space:]]+commit([[:space:]]|$)'
}

# Print the subject line of the commit message in a `git commit` command, or
# nothing when it can't be read from the command (editor-driven commits,
# -F with a file). Handles -m "...", -m '...', and heredoc bodies fed through
# -m "$(cat <<'EOF' ...)" or -F -.
ccm_commit_subject() {
  local cmd=$1 subject=""
  if printf '%s' "$cmd" | grep -qE "<<-?[[:space:]]*['\"]?EOF['\"]?"; then
    subject=$(printf '%s' "$cmd" | awk "
      /<<-?[[:space:]]*['\"]?EOF['\"]?/ { capturing = 1; next }
      /^[[:space:]]*EOF[[:space:]]*\)?\"?[[:space:]]*$/ { capturing = 0 }
      capturing && NF > 0 { sub(/^[[:space:]]+/, \"\"); print; exit }
    ")
  fi
  if [ -z "$subject" ]; then
    subject=$(printf '%s' "$cmd" | perl -0777 -ne '
      if (/(?:^|\s)(?:-[a-zA-Z]*m|--message)(?:\s*|=)"((?:[^"\\]|\\.)*)"/) { my $m = $1; $m =~ s/\\(.)/$1/g; my @l = split /\n/, $m; print $l[0]; exit }
      if (/(?:^|\s)(?:-[a-zA-Z]*m|--message)(?:\s*|=)'"'"'([^'"'"']*)'"'"'/) { my @l = split /\n/, $1; print $l[0]; exit }
    ' 2>/dev/null || true)
  fi
  printf '%s' "$subject"
}

# True when the subject should not be checked: git-generated or
# intentionally non-conventional (merges, reverts, autosquash markers).
ccm_commit_subject_exempt() {
  case $1 in
    Merge\ *|Revert\ *|fixup!\ *|squash!\ *|amend!\ *|"Initial commit"*) return 0 ;;
  esac
  return 1
}
