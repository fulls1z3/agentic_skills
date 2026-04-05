#!/usr/bin/env bash
set -euo pipefail

# Classifies findings against prior fingerprints → CLASSIFY_NEW, CLASSIFY_FIXED, CLASSIFY_STILL_UNRESOLVED, CLASSIFY_STALE
# Required: ARTEFACTS_DIR. Always exits 0.

ARTEFACTS_DIR="${ARTEFACTS_DIR:?ARTEFACTS_DIR required}"
PRIOR_FINGERPRINTS_FILE="${PRIOR_FINGERPRINTS_FILE:-}"
REVIEW_MODE="${REVIEW_MODE:-full}"
INCREMENTAL_CHANGED_FILES="${INCREMENTAL_CHANGED_FILES:-}"
DIFF_LINE_COUNT="${DIFF_LINE_COUNT:-0}"

# Large diff guard: >200 lines → downgrade prior-only to stale
_LARGE_DIFF=0
[ "${DIFF_LINE_COUNT:-0}" -gt 200 ] && _LARGE_DIFF=1

_TMPDIR=$(mktemp -d)
trap 'rm -rf "$_TMPDIR"' EXIT

_CURR_FPS="$_TMPDIR/current_fps.txt"

{
  for _f in \
    "$ARTEFACTS_DIR/findings.yaml" \
    "$ARTEFACTS_DIR/so_structured.yaml"; do
    [ -s "$_f" ] || continue
    awk '
      BEGIN { sev=""; file=""; sum=""; fp="" }
      /^- severity: / {
        if (sev != "" || sum != "") {
          out = (fp != "") ? fp : (sev "|" file "|" sum)
          if (out != "") print out
        }
        sev = $0; sub(/^- severity:[[:space:]]*/,"",sev); gsub(/[[:space:]]*$/,"",sev)
        file=""; sum=""; fp=""
      }
      /^  file: /        { file = $0; sub(/^  file:[[:space:]]*"?/,"",file);        sub(/"?[[:space:]]*$/,"",file)        }
      /^  summary: /     { sum  = $0; sub(/^  summary:[[:space:]]*"?/,"",sum);      sub(/"?[[:space:]]*$/,"",sum)         }
      /^  fingerprint: / { fp   = $0; sub(/^  fingerprint:[[:space:]]*"?/,"",fp);   sub(/"?[[:space:]]*$/,"",fp)          }
      END {
        if (sev != "" || sum != "") {
          out = (fp != "") ? fp : (sev "|" file "|" sum)
          if (out != "") print out
        }
      }
    ' "$_f" 2>/dev/null || true
  done
} | LC_ALL=C sort -u > "$_CURR_FPS"

_PRIOR_FPS="$_TMPDIR/prior_fps.txt"
if [ -n "$PRIOR_FINGERPRINTS_FILE" ] && [ -s "$PRIOR_FINGERPRINTS_FILE" ]; then
  LC_ALL=C sort -u < "$PRIOR_FINGERPRINTS_FILE" > "$_PRIOR_FPS"
else
  > "$_PRIOR_FPS"
fi

# Set operations (comm requires sorted input):
# current-only → new; both → still-unresolved; prior-only → fixed|carry|stale
_NEW_FPS="$_TMPDIR/new_fps.txt"
_BOTH_FPS="$_TMPDIR/both_fps.txt"
_PRIOR_ONLY_FPS="$_TMPDIR/prior_only_fps.txt"

comm -23 "$_CURR_FPS" "$_PRIOR_FPS" > "$_NEW_FPS"   || true
comm -12 "$_CURR_FPS" "$_PRIOR_FPS" > "$_BOTH_FPS"  || true
comm -13 "$_CURR_FPS" "$_PRIOR_FPS" > "$_PRIOR_ONLY_FPS" || true

_COUNT_NEW=$(wc -l < "$_NEW_FPS"  | tr -d ' ')
_COUNT_STILL=$(wc -l < "$_BOTH_FPS" | tr -d ' ')
_COUNT_PRIOR_ONLY=$(wc -l < "$_PRIOR_ONLY_FPS" | tr -d ' ')

_COUNT_FIXED=0
_COUNT_CARRY=0
_COUNT_STALE=0

if [ "$_COUNT_PRIOR_ONLY" -gt 0 ]; then
  if [ -n "$INCREMENTAL_CHANGED_FILES" ] && [ -s "$INCREMENTAL_CHANGED_FILES" ]; then
    # A finding is "fixed" only when its fingerprint is absent AND its file was in the diff window.
    # If the file wasn't reviewed in this window, carry forward as still-unresolved.
    while IFS= read -r fp; do
      [ -z "$fp" ] && continue
      _fp_file=$(printf '%s' "$fp" | cut -d'|' -f2 | cut -d':' -f1)
      if [ -z "$_fp_file" ] || [ "$_fp_file" = "unknown" ]; then
        # Cannot map to a file → stale
        _COUNT_STALE=$(( _COUNT_STALE + 1 ))
      elif grep -qxF "$_fp_file" "$INCREMENTAL_CHANGED_FILES" 2>/dev/null; then
        # Large diff guard: too large to review thoroughly → downgrade to stale
        if [ "$_LARGE_DIFF" -eq 1 ]; then
          _COUNT_STALE=$(( _COUNT_STALE + 1 ))
        else
          _COUNT_FIXED=$(( _COUNT_FIXED + 1 ))
        fi
      else
        _COUNT_CARRY=$(( _COUNT_CARRY + 1 ))
      fi
    done < "$_PRIOR_ONLY_FPS"
  else
    _COUNT_CARRY="$_COUNT_PRIOR_ONLY"
  fi
fi

_COUNT_TOTAL_STILL=$(( _COUNT_STILL + _COUNT_CARRY ))

printf 'CLASSIFY_NEW=%d\n'              "$_COUNT_NEW"
printf 'CLASSIFY_FIXED=%d\n'           "$_COUNT_FIXED"
printf 'CLASSIFY_STILL_UNRESOLVED=%d\n' "$_COUNT_TOTAL_STILL"
printf 'CLASSIFY_STALE=%d\n'           "$_COUNT_STALE"

exit 0
