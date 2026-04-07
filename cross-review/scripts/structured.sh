#!/usr/bin/env bash
set -euo pipefail

# Structured cross-review. Requires: ARTEFACTS_DIR with diff.patch
# Env: CROSS_REVIEW_TOOL (codex/gemini), CROSS_REVIEW_MODEL (optional)
# Writes: cross_review_structured.txt (raw), cross_review_structured.yaml (parsed), cross_review_status.txt (status signal)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "ERROR: Not inside a git repository" >&2
  exit 1
}
cd "$REPO_ROOT"

OUTDIR="${ARTEFACTS_DIR:?ARTEFACTS_DIR not set}"
if [ ! -d "$OUTDIR" ]; then
  echo "ERROR: $OUTDIR does not exist" >&2
  exit 1
fi
OUTFILE="$OUTDIR/cross_review_structured.txt"
STATUS_FILE="$OUTDIR/cross_review_status.txt"

# Default status: failed (overwritten on success paths)
printf 'failed\n' > "$STATUS_FILE"

DIFF_PATCH="${DIFF_PATCH:-$OUTDIR/diff.patch}"
if [ ! -f "$DIFF_PATCH" ]; then
  echo "ERROR: diff not found at $DIFF_PATCH" >&2
  exit 1
fi

BOUNDARY_FILE="$SKILL_DIR/prompts/boundary.txt"
PROMPT_FILE="$SKILL_DIR/prompts/structured.txt"
if [ ! -f "$BOUNDARY_FILE" ] || [ ! -f "$PROMPT_FILE" ]; then
  echo "ERROR: prompt files missing" >&2
  exit 1
fi

TMPERR=$(mktemp)
trap 'rm -f "$TMPERR"' EXIT
TOOL_STATUS=0

if [ "$CROSS_REVIEW_TOOL" = "codex" ]; then
  _CMD=(codex review -c 'model_reasoning_effort="high"')
  [ -n "${CROSS_REVIEW_MODEL:-}" ] && _CMD+=(-c "model=\"$CROSS_REVIEW_MODEL\"")
  _CMD+=(--enable web_search_cached -)
  # codex: prompt + diff via stdin, stdout captured to file
  {
    cat "$BOUNDARY_FILE"
    printf '\n\n'
    cat "$PROMPT_FILE"
    printf '\n\n--- BEGIN DIFF ---\n'
    cat "$DIFF_PATCH"
    printf '\n--- END DIFF ---\n'
  } | "${_CMD[@]}" >"$OUTFILE" 2>"$TMPERR" || TOOL_STATUS=$?
fi

if [ "$CROSS_REVIEW_TOOL" = "gemini" ]; then
  _CMD=(gemini --yolo)
  [ -n "${CROSS_REVIEW_MODEL:-}" ] && _CMD+=(--model "$CROSS_REVIEW_MODEL")
  # Gemini: embed diff in prompt, capture stdout to file
  _PROMPT="$(cat "$BOUNDARY_FILE")

$(cat "$PROMPT_FILE")

--- BEGIN DIFF ---
$(cat "$DIFF_PATCH")
--- END DIFF ---"
  "${_CMD[@]}" "$_PROMPT" >"$OUTFILE" 2>"$TMPERR" || TOOL_STATUS=$?
fi

# Both Codex and Gemini may write findings to stderr/display instead of stdout.
# Extract structured finding lines from stderr and append to the output file.
if [ -s "$TMPERR" ]; then
  grep -E '^\[P[123]\]|^P[123][[:space:]]|^(PASS|NO[[:space:]]FINDINGS?|LGTM|LOOKS[[:space:]]GOOD)' \
    "$TMPERR" >> "$OUTFILE" 2>/dev/null || true
fi

# Tool failure: skip parse, write empty YAML
if [ "$TOOL_STATUS" -ne 0 ]; then
  printf 'CROSS_REVIEW_TOOL_EXIT: %s exited with status %d\n' "$CROSS_REVIEW_TOOL" "$TOOL_STATUS" >&2
  cat "$TMPERR" >&2 || true
  printf '[]\n' > "$OUTDIR/cross_review_structured.yaml"
  printf 'failed\n' > "$STATUS_FILE"
  exit 0
fi

cat "$TMPERR" >&2 || true

# Empty capture: tool exited 0 but produced no output
if [ ! -s "$OUTFILE" ]; then
  printf 'CROSS_REVIEW_CAPTURE_EMPTY: %s exited 0 but produced no capturable output\n' "$CROSS_REVIEW_TOOL" >&2
  printf '[]\n' > "$OUTDIR/cross_review_structured.yaml"
  printf 'failed\n' > "$STATUS_FILE"
  exit 0
fi

# Parse raw output → normalized YAML findings
bash "$SCRIPT_DIR/parse.sh" \
  "$OUTFILE" \
  "$OUTDIR/cross_review_structured.yaml" \
  "cross-review-structured"

# Determine status
_PARSED_COUNT=0
[ -s "$OUTDIR/cross_review_structured.yaml" ] && \
  _PARSED_COUNT=$(grep -c '^- severity:' "$OUTDIR/cross_review_structured.yaml" 2>/dev/null) || _PARSED_COUNT=0
_HAS_PASS=$(head -60 "$OUTFILE" | grep -qiE '^\s*(PASS|NO[[:space:]]FINDINGS?)' 2>/dev/null && echo 1 || echo 0)

if [ "$_PARSED_COUNT" -gt 0 ] || [ "$_HAS_PASS" = "1" ]; then
  printf 'ran\n' > "$STATUS_FILE"
else
  printf 'raw-only\n' > "$STATUS_FILE"
fi
