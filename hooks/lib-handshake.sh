# shellcheck shell=bash
# Status handshake validation, shared by hooks/subagent-stop-handshake.sh and
# bin/ccm-post-review. Sourced, never executed.
#
# The handshake (skills/auto-ticket/autonomous-contract.md §3):
#
#   status: <value>
#   reason: <one line>
#   follow_ups: [...]
#   requested_state: <state>     (prompt-relay only)

# ccm_handshake_problem ALLOWED: read text on stdin and print what is wrong
# with the handshake that ends it, or nothing when it is valid. ALLOWED is a
# space-separated list of accepted status values; each caller passes its own.
#
# Takes the last `status:` line and everything after it. After it, only the
# other handshake keys, list continuation lines, code fences, and blank lines
# may appear, and `reason:` and `follow_ups:` must both be there.
ccm_handshake_problem() {
  awk -v allowed="$1" '
    { lines[NR] = $0 }
    /^[[:space:]]*status:[[:space:]]*/ { last = NR }
    END {
      if (!last) { print "no `status:` line"; exit }
      s = lines[last]
      sub(/^[[:space:]]*status:[[:space:]]*/, "", s); sub(/[[:space:]]+$/, "", s)
      n = split(allowed, ok, " "); valid = 0
      for (i = 1; i <= n; i++) if (s == ok[i]) valid = 1
      if (!valid) { print "status `" s "` is not one of: " allowed; exit }
      reason = 0; follow = 0
      for (i = last + 1; i <= NR; i++) {
        l = lines[i]
        if (l ~ /^[[:space:]]*reason:/) { reason = 1; continue }
        if (l ~ /^[[:space:]]*follow_ups:/) { follow = 1; continue }
        if (l ~ /^[[:space:]]*requested_state:/) continue
        if (l ~ /^[[:space:]]*(- |-$|```|$)/) continue
        print "text after the handshake (`" substr(l, 1, 60) "`); the handshake must be the last thing"; exit
      }
      if (!reason) { print "no `reason:` line after `status:`"; exit }
      if (!follow) { print "no `follow_ups:` line after `status:`"; exit }
    }'
}
