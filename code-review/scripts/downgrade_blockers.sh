#!/usr/bin/env bash
set -euo pipefail

# downgrade_blockers.sh — downgrades BLOCKER findings that lack a concrete proof shape.
# A BLOCKER is kept if:
#   - its 'why' field is ≥ 8 words (substantive proof), OR
#   - its 'why' + 'summary' fields contain at least one proof-shape keyword.
# Otherwise severity is downgraded to WARNING in-place.
# Usage: bash code-review/scripts/downgrade_blockers.sh <findings.yaml>
# In-place normalization via temp file. Always exits 0.

FILE="${1:?File argument required}"

[ -s "$FILE" ] || exit 0

# Fast-path: no BLOCKERs in file → nothing to check.
_BCOUNT=$(grep -c '^- severity: BLOCKER' "$FILE" 2>/dev/null) || _BCOUNT=0
[ "$_BCOUNT" -eq 0 ] && exit 0

_TMP=$(mktemp)
trap 'rm -f "$_TMP"' EXIT

LC_ALL=C awk '
  function word_count(s,    arr) {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
    if (s == "") return 0
    return split(s, arr, /[[:space:]]+/)
  }

  function has_proof(s,    lc) {
    lc = tolower(s)
    return (lc ~ /fail|crash|exploit|bypass|inject|overflow|race|deadlock|arbitrary|payload|traversal|trigger|execut|corrupt|spoof/)
  }

  function flush(    wc, keep) {
    if (buf == "") return
    if (severity != "BLOCKER") {
      printf "%s", buf
      buf = ""; severity = ""; why = ""; summary = ""
      return
    }
    wc = word_count(why)
    keep = (wc >= 8) || has_proof(why " " summary)
    if (!keep) {
      sub(/severity: BLOCKER/, "severity: WARNING", buf)
      print "BLOCKER_DOWNGRADED: " summary > "/dev/stderr"
    }
    printf "%s", buf
    buf = ""; severity = ""; why = ""; summary = ""
  }

  BEGIN { buf = ""; severity = ""; why = ""; summary = "" }

  /^- severity:/ {
    flush()
    buf = $0 "\n"
    severity = $NF
    next
  }
  /^  why:/ {
    why = $0
    sub(/^  why: *"?/, "", why)
    sub(/"?$/, "", why)
    buf = buf $0 "\n"
    next
  }
  /^  summary:/ {
    summary = $0
    sub(/^  summary: *"?/, "", summary)
    sub(/"?$/, "", summary)
    buf = buf $0 "\n"
    next
  }
  { buf = buf $0 "\n" }
  END { flush() }
' "$FILE" > "$_TMP"

mv "$_TMP" "$FILE"
echo "BLOCKERS_CHECKED: $FILE (${_BCOUNT} found)"
