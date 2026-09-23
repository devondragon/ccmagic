#!/usr/bin/env bash
# PreToolUse hook (Bash): blocks commands that ccmagic's rules forbid, before
# they run. Denials go back to the model with the reason, so it can correct
# course instead of the rule depending on it having read the skill closely.
#
# "Autonomous" below means a ccmagic:auto-* agent (from the hook input's
# agent_type) or `autonomous: true` in ccmagic.local.md.
#
# Rules:
#   Merge gate: `gh pr merge` (or a PUT to .../pulls/N/merge via `gh api`).
#     Autonomous: denied unless bin/ccm-merge-gate passes; always denied when
#     merge_owner is reeve. No override.
#     Interactive: gated only with `merge_guard: on`; the user can merge past
#     it, and the command is then prefixed with CCMAGIC_MERGE_OVERRIDE=1.
#   Force push: `git push --force`, `-f`, `--force-with-lease`, or a `+refspec`.
#     Autonomous: always denied.
#     Interactive: denied when the target is main, master, develop, release/*,
#     or the repo's default branch. Force-pushing your own feature branch is
#     allowed. No override: a person who means it can run it themselves.
#   Sensitive files: `git add` / `git commit` that would stage or commit a
#     secret-shaped file (.env, private keys, credential files; list below).
#     Files listed under "## Always Include" in context/commit-preferences.md
#     are allowed.
#     Autonomous: denied. No override.
#     Interactive: denied until the user confirms; the command is then
#     prefixed with CCMAGIC_ALLOW_SENSITIVE=1.
#   Commit format: `git commit` whose subject doesn't match the
#     conventional-commit pattern in hooks/lib-commit.sh.
#     Autonomous: denied, with the expected format. Interactive: allowed (the
#     PostToolUse hook prints a warning instead).
#
# Exit 0 with no output allows the command. A deny prints the PreToolUse
# decision JSON and exits 0. If jq is missing, everything is allowed.

set -o pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bin="$here/../bin"

INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

cmd=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
agent_type=$(jq -r '.agent_type // empty' <<<"$INPUT")
cwd=$(jq -r '.cwd // empty' <<<"$INPUT")
[ -n "$cmd" ] || exit 0

# A command segment starts at the beginning of a line or after ; & | (.
# Leading VAR=value assignments are allowed; `git -C dir` is allowed.
seg='(^|[;&|(])[[:space:]]*'
envs='([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'
gitcmd="git([[:space:]]+-[cC][[:space:]]+[^[:space:]]+)*[[:space:]]+"

has() { printf '%s' "$cmd" | grep -qE "$1"; }

is_merge=false is_push=false is_add=false is_commit=false
if has "${seg}${envs}gh[[:space:]]+pr[[:space:]]+merge([[:space:]]|$)"; then
  is_merge=true
elif has "gh[[:space:]]+api[[:space:]].*pulls/[0-9]+/merge" && has '(-X|--method)[[:space:]]*PUT'; then
  is_merge=true
fi
has "${seg}${envs}${gitcmd}push([[:space:]]|$)" && is_push=true
has "${seg}${envs}${gitcmd}add([[:space:]]|$)" && is_add=true
has "${seg}${envs}${gitcmd}commit([[:space:]]|$)" && is_commit=true

if [ "$is_merge$is_push$is_add$is_commit" = falsefalsefalsefalse ]; then
  exit 0
fi

if [ -n "$cwd" ]; then
  cd "$cwd" 2>/dev/null || true
fi

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse",
    permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

# Print the arguments of every segment that runs `git <sub>`, one segment per
# line, starting with <sub>. Quoted arguments are not re-split; this is only
# used for flags and path arguments, which are rarely quoted.
segments_of() {
  printf '%s' "$cmd" | SUB=$1 perl -ne '
    for my $s (split /(?:&&|\|\||[;|&(])/) {
      if ($s =~ /^\s*(?:[A-Za-z_]\w*=\S*\s+)*git(?:\s+-[cC]\s+\S+)*\s+($ENV{SUB}(?:\s.*)?)$/) { print "$1\n" }
    }'
}

has_prefix() { has "(^|[[:space:]])$1=1[[:space:]]"; }

# shellcheck source=bin/ccm-lib.sh
. "$bin/ccm-lib.sh"
cfg=$(ccm_config_json 2>/dev/null || echo '{}')
autonomous=false
case $agent_type in ccmagic:auto-*) autonomous=true ;; esac
[ "$(jq -r '.autonomous // "false"' <<<"$cfg")" = true ] && autonomous=true

# ---- merge gate ------------------------------------------------------------

if [ "$is_merge" = true ]; then
  merge_pr=""
  if has "gh[[:space:]]+pr[[:space:]]+merge"; then
    # First non-flag argument after `merge` is the PR (number, URL, or branch).
    merge_pr=$(printf '%s' "$cmd" | sed -nE 's/.*gh[[:space:]]+pr[[:space:]]+merge[[:space:]]+(.*)/\1/p' | head -1 |
      awk '{ for (i = 1; i <= NF; i++) { if ($i ~ /^[;&|]/) exit; if ($i !~ /^-/) { print $i; exit } } }')
    case $merge_pr in
      */pull/*) merge_pr=${merge_pr##*/pull/}; merge_pr=${merge_pr%%[^0-9]*} ;;
    esac
  else
    merge_pr=$(printf '%s' "$cmd" | sed -nE 's/.*pulls\/([0-9]+)\/merge.*/\1/p' | head -1)
  fi
  merge_owner=$(jq -r '.merge_owner // "self"' <<<"$cfg")
  guard=$(jq -r '.merge_guard // "off"' <<<"$cfg")

  if [ "$autonomous" = true ] && [ "$merge_owner" = reeve ]; then
    deny "ccmagic: merge_owner is reeve, so this run must not merge. Take the hand-off path instead (move the ticket to merge_handoff_state and report 'handed off to reeve')."
  fi
  if [ "$autonomous" = true ] || { [ "$guard" = on ] && ! has_prefix CCMAGIC_MERGE_OVERRIDE; }; then
    if ! gate=$("$bin/ccm-merge-gate" ${merge_pr:+"$merge_pr"} 2>/dev/null); then
      blockers=$(jq -r '(.blockers // ["merge gate could not run"]) | join("; ")' <<<"$gate" 2>/dev/null || echo "merge gate could not run")
      if [ "$autonomous" = true ]; then
        deny "ccmagic merge gate failed: $blockers. An autonomous run does not merge past the gate; return needs-human with these blockers as the reason."
      fi
      deny "ccmagic merge gate failed: $blockers. Show these to the user. Only if the user explicitly chooses to merge anyway, rerun the same command prefixed with CCMAGIC_MERGE_OVERRIDE=1."
    fi
  fi
fi

# ---- force push ------------------------------------------------------------

if [ "$is_push" = true ]; then
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    force=false
    read -ra words <<<"$s"
    positional=()
    for a in "${words[@]:1}"; do
      case $a in
        --force|--force-with-lease|--force-with-lease=*|--force-if-includes) force=true ;;
        --*) ;;
        -*) [[ $a == *f* ]] && force=true ;;
        *) positional+=("$a") ;;
      esac
    done
    target=""
    if [ "${#positional[@]}" -ge 2 ]; then
      spec=${positional[1]}
      [[ $spec == +* ]] && force=true
      spec=${spec#+}
      target=${spec##*:}
      target=${target#refs/heads/}
    fi
    [ "$force" = true ] || continue
    [ -n "$target" ] || target=$(git branch --show-current 2>/dev/null || true)
    if [ "$autonomous" = true ]; then
      deny "ccmagic: autonomous runs never force-push (target: ${target:-unknown}). If the branch has diverged, rebase onto the remote (git pull --rebase) and push normally; if that conflicts, return needs-human."
    fi
    default=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
    default=${default#origin/}
    case $target in
      main|master|develop|release/*|"$default")
        deny "ccmagic: force-pushing to the shared branch '$target' is not allowed. Push a new branch and open a PR instead. If the user really wants this, they can run the command themselves."
        ;;
    esac
  done < <(segments_of push)
fi

# ---- sensitive files -------------------------------------------------------

is_sensitive() {
  local p=$1 b=${1##*/}
  case $b in
    .env.example|.env.sample|.env.template|.env.dist|*.pub) return 1 ;;
    .env|.env.*|*.pem|*.key|*.p12|*.pfx|*.jks|*.keystore|id_rsa|id_dsa|id_ecdsa|id_ed25519|.netrc|.pgpass|*.secret) return 0 ;;
    credentials|*credentials*.json|secrets.yml|secrets.yaml|secrets.json|secrets.env) return 0 ;;
  esac
  case $p in
    .claude/settings.local.json|*/.claude/settings.local.json) return 0 ;;
  esac
  return 1
}

always_included() {
  local f=context/commit-preferences.md
  [ -f "$f" ] || return 1
  awk '/^## /{ on = ($0 ~ /^## Always Include/); next } on && /^- /{ sub(/^- +/, ""); print }' "$f" | grep -qxF -- "$1"
}

# Files the command would add to the index or commit.
candidate_files() {
  local s a p all tracked_only words paths after_dashdash
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    read -ra words <<<"$s"
    all=false tracked_only=false paths=() after_dashdash=false
    for a in "${words[@]:1}"; do
      if [ "$after_dashdash" = true ]; then
        case $a in
          .|./|:/) all=true ;;
          *) paths+=("$a") ;;
        esac
        continue
      fi
      case $a in
        --) after_dashdash=true ;;
        -A|--all|--no-ignore-removal) all=true ;;
        -u|--update) all=true; tracked_only=true ;;
        -*) ;;
        .|./|:/) all=true ;;
        *) paths+=("$a") ;;
      esac
    done
    if [ "$all" = true ]; then
      if [ "$tracked_only" = true ]; then
        git diff --name-only --diff-filter=ACMR
      else
        git ls-files --modified --others --exclude-standard
      fi
    fi
    for p in "${paths[@]}"; do
      if [ -d "$p" ]; then
        git ls-files --modified --others --exclude-standard -- "$p"
      else
        printf '%s\n' "${p#./}"
      fi
    done
  done < <(segments_of add)
  if [ "$is_commit" = true ]; then
    git diff --cached --name-only --diff-filter=ACMR
    while IFS= read -r s; do
      read -ra words <<<"$s"
      for a in "${words[@]:1}"; do
        case $a in
          --all) git diff --name-only --diff-filter=ACMR ;;
          --*) ;;
          -*a*) [[ $a =~ ^-[a-zA-Z]+$ ]] && git diff --name-only --diff-filter=ACMR ;;
        esac
      done
    done < <(segments_of commit)
  fi
}

if { [ "$is_add" = true ] || [ "$is_commit" = true ]; } && git rev-parse --git-dir >/dev/null 2>&1; then
  flagged=()
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if is_sensitive "$f" && ! always_included "$f"; then
      flagged+=("$f")
    fi
  done < <(candidate_files 2>/dev/null | sort -u)
  if [ "${#flagged[@]}" -gt 0 ]; then
    list=$(printf '%s, ' "${flagged[@]}")
    list=${list%, }
    if [ "$autonomous" = true ]; then
      deny "ccmagic: refusing to stage or commit secret-shaped files in an autonomous run: $list. Leave them out of the commit (unstage with git restore --staged). If the change can't be correct without them, return needs-human naming the file."
    fi
    if ! has_prefix CCMAGIC_ALLOW_SENSITIVE; then
      deny "ccmagic: this would stage or commit files that often hold secrets: $list. Ask the user whether they belong in the repo. Only if they confirm, rerun the same command prefixed with CCMAGIC_ALLOW_SENSITIVE=1 (or add the file under '## Always Include' in context/commit-preferences.md)."
    fi
  fi
fi

# ---- commit format (autonomous only) ---------------------------------------

if [ "$is_commit" = true ] && [ "$autonomous" = true ]; then
  # shellcheck source=hooks/lib-commit.sh
  . "$here/lib-commit.sh"
  subject=$(ccm_commit_subject "$cmd")
  if [ -n "$subject" ] && ! ccm_commit_subject_exempt "$subject" &&
     ! printf '%s' "$subject" | grep -qE "$CCM_COMMIT_PATTERN"; then
    deny "ccmagic: commit subject does not follow the conventional-commit format, so the commit was not made. Rewrite the subject and commit again.
$CCM_COMMIT_FORMAT_HELP
Actual subject: $subject"
  fi
fi

exit 0
