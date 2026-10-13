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
  "linear_team": "",
  "linear_project": "",
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
  "ci_poll_interval_seconds": "60",
  "validate_timeout_seconds": "540",
  "validate_format": "",
  "validate_lint": "",
  "validate_types": "",
  "validate_test": "",
  "validate_build": "",
  "visual_checklist": "on"
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

# ---- Diff base and personal identifiers -------------------------------------

# ccm_default_diff_base: print "<commit><TAB><description>" for the commit a
# branch's changes are measured from: the merge base of HEAD with the default
# branch (refs/remotes/origin/HEAD, else origin/main, origin/master, main,
# master), else HEAD itself (an empty commit in a repository with none).
ccm_default_diff_base() {
  local def cand base=""
  def=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)
  for cand in $def origin/main origin/master main master; do
    if git rev-parse -q --verify "$cand^{commit}" >/dev/null; then
      base=$(git merge-base HEAD "$cand" 2>/dev/null || true)
      if [ -n "$base" ]; then printf '%s\tmerge-base of HEAD and %s\n' "$base" "$cand"; return 0; fi
    fi
  done
  base=$(git rev-parse -q --verify 'HEAD^{commit}' || true)
  printf '%s\tHEAD\n' "$base"
}

# An email address written out, or spelled "<word> at <domain>.<tld>", as ERE
# for grep -i. The spelled form needs a domain ending in a common TLD, so "at
# the edge", "at most 4", and "looked at config.yaml" pass.
# shellcheck disable=SC2034 # used by the scripts that source this file
CCM_EMAIL_TLDS='com|net|org|edu|gov|io|co|us|uk|de|fr|ca|au|info|biz|dev|app|me'
# shellcheck disable=SC2034
CCM_EMAIL_RE='[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}'
# shellcheck disable=SC2034
CCM_SPELLED_EMAIL_RE="(^|[^A-Za-z0-9._@-])[A-Za-z][A-Za-z0-9._-]*[ ]+at[ ]+[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)*\\.($CCM_EMAIL_TLDS)([^A-Za-z0-9-]|\$)"

# ---- OpenSpec helpers ---------------------------------------------------------

# ccm_parse_tasks FILE: a port of Reeve's parseTasks (src/openspec/parse.ts), which
# is stricter than the openspec CLI. Prints "S<TAB>number<TAB>line" per section
# and "T<TAB>line<TAB>section<TAB>id<TAB>checked<TAB>boxbytes" per task
# (checked 1 for x or X, boxbytes the byte length of the box's character), or
# one "E<TAB>rule<TAB>line<TAB>reason" line on the first rejection. It reads
# bytes (LC_ALL=C, the same under gawk, mawk, and BSD awk): the box holds one
# character as JavaScript's "." reads it, so one UTF-8 sequence of up to three
# bytes, and a no-break space (U+00A0) counts as whitespace, as in "\s". Line
# breaks are Reeve's: CRLF and a lone carriage return each end a line, so the
# file is rewritten with LF line ends before it is read.
ccm_parse_tasks() {
  LC_ALL=C awk '
    # boxlen(s, p): the byte length of the one character at p when s[p + len]
    # is "]", else 0.
    function boxlen(s, p,   b, len, i) {
      b = substr(s, p, 1)
      if (b == "" || b == "\n" || b == "\r") return 0
      if (b < "\200") len = 1
      else if (b >= "\300" && b < "\340") len = 2
      else if (b >= "\340" && b < "\360") len = 3
      else return 0
      for (i = 1; i < len; i++) { c = substr(s, p + i, 1); if (c < "\200" || c >= "\300") return 0 }
      if (len == 3 && (substr(s, p, 3) == LS || substr(s, p, 3) == PS)) return 0
      return substr(s, p + len, 1) == "]" ? len : 0
    }
    function nbsp(s,   k) { while ((k = index(s, NB)) > 0) s = substr(s, 1, k - 1) " " substr(s, k + 2); return s }
    function trim(s) { sub(/^[ \t\r\n\f\v]+/, "", s); sub(/[ \t\r\n\f\v]+$/, "", s); return s }
    function safe(d) { sub(/^0+/, "", d); return length(d) < 16 || (length(d) == 16 && d <= "9007199254740991") }
    function safeparts(id,   n, parts, i) {
      gsub(/[^0-9]+/, " ", id); n = split(id, parts, " ")
      for (i = 1; i <= n; i++) if (!safe(parts[i])) return 0
      return 1
    }
    function reject(rule, line, reason) { printf "E\t%s\t%s\t%s\n", rule, line, reason; bad = 1; exit }
    function closesec() {
      if (cur != "" && ntasks == 0) reject("empty-section", curline, "Section " cur " has no checkbox task.")
      cur = ""
    }
    BEGIN {
      fence = ""; cur = ""; nsec = 0; prev = ""
      NB = sprintf("%c%c", 194, 160); LS = sprintf("%c%c%c", 226, 128, 168); PS = sprintf("%c%c%c", 226, 128, 169)
    }
    {
      raw = $0; sub(/\r$/, "", raw); n = NR
      if (fence == "") {
        if (match(raw, /^ ? ? ?(```+|~~~+)/)) { f = substr(raw, RSTART, RLENGTH); sub(/^ +/, "", f); fence = f; next }
      } else {
        c = substr(fence, 1, 1); t = raw; sub(/^ ? ? ?/, "", t)
        k = 0; while (substr(t, k + 1, 1) == c) k++
        if (k >= length(fence) && substr(t, k + 1) ~ /^[ \t\r\n\f\v]*$/) fence = ""
        next
      }
      if (match(raw, /^ ? ? ?##[ \t]+[0-9]+\./)) {
        head = substr(raw, 1, RLENGTH); rest = substr(raw, RLENGTH + 1)
        if (rest == "" || rest ~ /^[ \t]/) {
          closesec()
          num = head; sub(/^ *##[ \t]+/, "", num); sub(/\.$/, "", num)
          if (!safeparts(num)) reject("number-range", n, "Section number " num " is too large.")
          num = num + 0; title = trim(rest)
          if (title == "") reject("section-title", n, "Section " num " has no title.")
          if (prev != "" && num <= prev) reject("section-order", n, "Section " num " follows section " prev ".")
          cur = num; curline = n; ntasks = 0; prev = num; nsec++
          printf "S\t%s\t%s\n", num, n
          next
        }
      }
      if (raw ~ /^ ? ? ?##/ && substr(raw, index(raw, "##") + 2, 1) != "#") { closesec(); next }
      norm = nbsp(raw)
      if (norm ~ /^[ \t\f\v]*[0-9]+[.)][ \t\f\v]+\[/ && boxlen(raw, index(raw, "[") + 1)) reject("task-marker", n, "A checkbox task uses an ordered list marker.")
      if (norm ~ /^[ \t\f\v]*[-*+][ \t\f\v]+\[/ && (bl = boxlen(raw, (p = index(raw, "[")) + 1))) {
        mark = substr(raw, p + 1, bl); after = nbsp(substr(raw, p + bl + 2))
        if (after == "" || after ~ /^[ \t\r\n\f\v]/) {
          if (cur == "") reject("task-outside-section", n, "A checkbox task is not under a numbered section heading.")
          rest = trim(after)
          if (!match(rest, /^[0-9]+(\.[0-9]+)+[A-Za-z]*/)) reject("unnumbered-task", n, "A checkbox task in section " cur " has no task id.")
          id = substr(rest, 1, RLENGTH); tail = substr(rest, RLENGTH + 1)
          if (tail != "" && tail !~ /^[ \t\r\n\f\v]/) reject("unnumbered-task", n, "A checkbox task in section " cur " has no task id.")
          if (!safeparts(id)) reject("number-range", n, "Task id " id " has a number too large.")
          if (trim(tail) == "") reject("task-text", n, "Task " id " has no text.")
          split(id, ip, "."); if (ip[1] + 0 != cur) reject("task-prefix", n, "Task " id " is under section " cur ".")
          if (id in seen) reject("duplicate-task", n, "Task " id " appears twice.")
          seen[id] = 1; ntasks++
          printf "T\t%s\t%s\t%s\t%s\t%s\n", n, cur, id, (mark == "x" || mark == "X") ? 1 : 0, bl
          next
        }
      }
    }
    END {
      if (bad) exit
      closesec()
      if (!bad && nsec == 0) reject("no-section", "", "The file has no numbered section heading (## 1. Title).")
    }
  ' < <(LC_ALL=C awk '{ sub(/\r$/, ""); gsub(/\r/, "\n"); print }' "$1")
}

ccm_archive_matches() { # FOLDER NAME: Reeve's archiveFolderMatches
  local d='^[0-9]{4}-[0-9]{2}-[0-9]{2}-'
  if [[ $2 =~ $d ]]; then [ "$1" = "$2" ]; else [[ $1 =~ $d ]] && [ "${1:11}" = "$2" ]; fi
}
