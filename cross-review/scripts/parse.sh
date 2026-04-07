#!/usr/bin/env bash
set -euo pipefail

# Parses raw cross-review text → normalized YAML findings. Always exits 0.
# Usage: parse.sh <input_txt> <output_yaml> <source_label>

INPUT="${1:?Input file required}"
OUTPUT="${2:?Output YAML file required}"
SOURCE="${3:?Source label required}"

if [ ! -f "$INPUT" ]; then
  echo "CROSS_REVIEW_PARSE_WARNING: input file '$INPUT' not found — zero findings written" >&2
  printf '[]\n' > "$OUTPUT"
  exit 0
fi

# Check for pass/no-finding sentinels (first 60 lines only)
_PASS_SIGNAL=0
if head -60 "$INPUT" | grep -qiE '^\s*(PASS|NO[[:space:]]FINDINGS?|NO[[:space:]]ISSUES?|LGTM|LOOKS[[:space:]]GOOD)' 2>/dev/null; then
  _PASS_SIGNAL=1
fi

LC_ALL=C awk -v src="$SOURCE" '

# Skip unambiguous diff format markers
/^diff --git / { next }
/^index [0-9a-f]/ { next }
/^--- a\// { next }
/^\+\+\+ b\// { next }
/^@@ / { next }

# Skip sentinel lines emitted by the skill scripts themselves
/^CROSS_REVIEW_/ { next }

{
  line = $0

  # Strip leading list/bullet markers: "1. ", "1) ", "* ", "- "
  sub(/^[[:space:]]*[0-9]+[.)][[:space:]]+/, "", line)
  sub(/^[[:space:]]*[-*][[:space:]]+/, "", line)
  sub(/^[[:space:]]+/, "", line)

  # Strip markdown bold/italic/code markers
  gsub(/\*\*|\*|`/, "", line)


  sev = ""

  if (line ~ /\[(P1|BLOCKER|CRITICAL|blocker|critical)\]/)       sev = "BLOCKER"
  else if (line ~ /\[(P2|WARNING|HIGH|warning|high)\]/)           sev = "WARNING"
  else if (line ~ /\[(P3|NIT|MEDIUM|nit|medium)\]/)               sev = "NIT"
  else if (line ~ /^P1[[:space:]]/)                               sev = "BLOCKER"
  else if (line ~ /^P2[[:space:]]/)                               sev = "WARNING"
  else if (line ~ /^P3[[:space:]]/)                               sev = "NIT"
  else if (line ~ /^(BLOCKER|CRITICAL|blocker|critical)[[:space:]:,]/) sev = "BLOCKER"
  else if (line ~ /^(WARNING|HIGH|warning|high)[[:space:]:,]/)        sev = "WARNING"
  else if (line ~ /^(NIT|MEDIUM|nit|medium)[[:space:]:,]/)            sev = "NIT"

  # Skip lines with no severity signal
  if (sev == "") next


  gsub(/\[(P[123]|BLOCKER|WARNING|NIT|CRITICAL|HIGH|MEDIUM|blocker|warning|nit|critical|high|medium)[^]]*\]/, "", line)
  sub(/^(P[123]|BLOCKER|WARNING|NIT|CRITICAL|HIGH|MEDIUM|blocker|warning|nit|critical|high|medium)[[:space:]:,]+/, "", line)
  sub(/^[[:space:]]+/, "", line)

  # Path extraction (avoids / in char class and {n,m} — macOS awk limitations)
  file = "unknown"
  if (match(line, /[^ 	]+\/[^ 	]*\.[a-zA-Z]+(:[0-9]+(-[0-9]+)?)?/)) {
    file = substr(line, RSTART, RLENGTH)
    line = substr(line, 1, RSTART - 1) substr(line, RSTART + RLENGTH)
  }
  # Fallback: root-level file (no directory separator) with known extension
  if (file == "unknown" && match(line, /[a-zA-Z_][a-zA-Z0-9_.-]*\.(md|txt|yml|yaml|json|toml|ini|ts|tsx|js|jsx|py|rb|rs|go|java|c|cpp|h|sh|sql|html|css|vue|proto|graphql|tf|lock|mod)(:[0-9]+(-[0-9]+)?)?/)) {
    file = substr(line, RSTART, RLENGTH)
    line = substr(line, 1, RSTART - 1) substr(line, RSTART + RLENGTH)
  }
  # Fallback: known extensionless filenames
  if (file == "unknown" && match(line, /(Dockerfile|Makefile|Gemfile|Rakefile|Procfile|Justfile)(:[0-9]+(-[0-9]+)?)?/)) {
    file = substr(line, RSTART, RLENGTH)
    line = substr(line, 1, RSTART - 1) substr(line, RSTART + RLENGTH)
    sub(/-[0-9]+$/, "", file)
  }

  gsub(/\\/, "/", file)
  # Normalize line ranges :N-M → :N
  sub(/-[0-9]+$/, "", file)

  sub(/^[[:space:]]*[-:|][[:space:]]+/, "", line)
  # Strip any remaining leading non-alphanumeric bytes (handles em-dash U+2014 as 3 UTF-8 bytes)
  while (length(line) > 0 && substr(line, 1, 1) !~ /[[:alnum:]_(]/) {
    line = substr(line, 2)
  }
  summary = line

  if (length(summary) < 10) next

  fp = sev "|" file "|" summary

  gsub(/\\/, "\\\\", file);    gsub(/"/, "\\\"", file)
  gsub(/\\/, "\\\\", summary); gsub(/"/, "\\\"", summary)
  gsub(/\\/, "\\\\", fp);      gsub(/"/, "\\\"", fp)

  printf "- severity: %s\n",        sev
  printf "  confidence: medium\n"
  printf "  file: \"%s\"\n",        file
  printf "  summary: \"%s\"\n",     summary
  printf "  source: %s\n",          src
  printf "  fingerprint: \"%s\"\n", fp
}

' "$INPUT" > "$OUTPUT" || true

if [ ! -s "$OUTPUT" ]; then
  printf '[]\n' > "$OUTPUT"
fi

_COUNT=0
[ -s "$OUTPUT" ] && _COUNT=$(grep -c '^- severity:' "$OUTPUT" 2>/dev/null) || _COUNT=0

if [ "$_COUNT" -eq 0 ] && [ "$_PASS_SIGNAL" -eq 0 ]; then
  echo "CROSS_REVIEW_PARSE_WARNING: no structured findings extracted from '$INPUT'" >&2
elif [ "$_COUNT" -eq 0 ] && [ "$_PASS_SIGNAL" -eq 1 ]; then
  echo "CROSS_REVIEW_PARSE_WARNING: PASS signal detected — zero findings (expected)" >&2
fi

exit 0
