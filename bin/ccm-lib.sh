# shellcheck shell=bash
# Shared helpers for the ccm-* scripts. Sourced, never executed.
#
# Config lives in YAML frontmatter of .claude/ccmagic.local.md (project) and
# ~/.claude/ccmagic.local.md (user). Only flat `key: value` lines are read,
# which is all ccmagic's config uses. Project values win over user values;
# both win over the built-in defaults below.

CCM_CONFIG_DEFAULTS='{
  "tracker": "auto",
  "ticket_url_base": "",
  "ticket_id_regex": "[A-Z][A-Z0-9]+-[0-9]+",
  "github_repo": "",
  "default_qa_workflow": "false",
  "qa_label": "",
  "autonomous": "false",
  "needs_human_state": "",
  "needs_human_label": "needs-human",
  "merge_owner": "self",
  "merge_handoff_state": "Awaiting Merge",
  "max_feedback_passes": "3",
  "max_review_fix_passes": "3",
  "max_validate_attempts": "2",
  "ci_timeout_minutes": "30",
  "ci_poll_interval_seconds": "60"
}'

# Print the frontmatter of a markdown file as a JSON object of string values.
# Missing file or no frontmatter prints {}.
ccm_frontmatter_json() {
  local file=$1
  if [ ! -f "$file" ]; then
    echo '{}'
    return
  fi
  awk '
    NR == 1 && $0 !~ /^---[[:space:]]*$/ { exit }
    NR == 1 { infm = 1; next }
    infm && /^---[[:space:]]*$/ { exit }
    infm { print }
  ' "$file" |
    sed -nE 's/^([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*:[[:space:]]*(.*)$/\1\t\2/p' |
    while IFS=$'\t' read -r key val; do
      # Drop a trailing comment only when it is preceded by whitespace, so a
      # value such as a URL fragment keeps its '#'.
      val=$(printf '%s' "$val" | sed -E 's/[[:space:]]+#.*$//; s/[[:space:]]+$//')
      # Strip one layer of matching quotes.
      case $val in
        \"*\") val=${val#\"}; val=${val%\"} ;;
        \'*\') val=${val#\'}; val=${val%\'} ;;
      esac
      [ -n "$val" ] || continue
      jq -n --arg k "$key" --arg v "$val" '{($k): $v}'
    done | jq -s 'add // {}'
}

# Print the resolved config as JSON: defaults < user file < project file.
# CCM_USER_CONFIG and CCM_PROJECT_CONFIG override the paths (used by tests).
ccm_config_json() {
  local root project user
  root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  project=${CCM_PROJECT_CONFIG:-$root/.claude/ccmagic.local.md}
  user=${CCM_USER_CONFIG:-$HOME/.claude/ccmagic.local.md}
  jq -n \
    --argjson d "$CCM_CONFIG_DEFAULTS" \
    --argjson u "$(ccm_frontmatter_json "$user")" \
    --argjson p "$(ccm_frontmatter_json "$project")" \
    '$d + $u + $p'
}

# Read one resolved config value.
ccm_config_get() {
  ccm_config_json | jq -r --arg k "$1" '.[$k] // empty'
}

# "owner/repo" for the current checkout, from config or gh. Empty if unknown.
ccm_repo_slug() {
  local slug
  slug=$(ccm_config_get github_repo)
  if [ -z "$slug" ] && command -v gh >/dev/null 2>&1; then
    slug=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
  fi
  printf '%s' "$slug"
}

# Per-checkout scratch directory for ccmagic state. Lives inside the git dir,
# so nothing written here can be committed.
ccm_state_dir() {
  local d
  d="$(git rev-parse --path-format=absolute --git-dir)/ccmagic"
  mkdir -p "$d"
  printf '%s' "$d"
}
