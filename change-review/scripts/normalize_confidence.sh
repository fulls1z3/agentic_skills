#!/usr/bin/env bash
set -euo pipefail

# normalize_confidence.sh — fills missing confidence fields in YAML findings files.
# Adds confidence: medium after severity: for any finding block that lacks it.
# Usage: bash change-review/scripts/normalize_confidence.sh <findings.yaml>
# In-place normalization via temp file. Always exits 0.

FILE="${1:?File argument required}"

[ -s "$FILE" ] || exit 0

# Quick check: if every - severity: line is already followed by a confidence line, skip.
_SCOUNT=$(grep -c '^- severity:' "$FILE" 2>/dev/null) || _SCOUNT=0
_CCOUNT=$(grep -c '^  confidence:' "$FILE" 2>/dev/null) || _CCOUNT=0
if [ "$_SCOUNT" -eq 0 ] || [ "$_SCOUNT" -eq "$_CCOUNT" ]; then
  exit 0
fi

_TMP=$(mktemp)
trap 'rm -f "$_TMP"' EXIT

LC_ALL=C awk '
  BEGIN { first_line = ""; buf = ""; has_conf = 0 }

  function flush() {
    if (first_line == "") return
    print first_line
    if (!has_conf) print "  confidence: medium"
    printf "%s", buf
    first_line = ""; buf = ""; has_conf = 0
  }

  /^- severity:/   { flush(); first_line = $0; next }
  /^  confidence:/ { has_conf = 1; buf = buf $0 "\n"; next }
  { if (first_line != "") buf = buf $0 "\n"; else print }
  END { flush() }
' "$FILE" > "$_TMP"

mv "$_TMP" "$FILE"
echo "CONFIDENCE_NORMALIZED: $FILE"
