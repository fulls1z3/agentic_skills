#!/usr/bin/env bash
set -euo pipefail

# run.sh — Entry point for cross-review skill.
# Required env: ARTEFACTS_DIR (must contain diff.patch)
# Always exits 0 — failures reported via CROSS_REVIEW_* signals.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ARTEFACTS_DIR="${ARTEFACTS_DIR:?ARTEFACTS_DIR env var required}"

# Env-only configuration (no config files)
CROSS_REVIEW_TOOL="${CROSS_REVIEW_TOOL:-none}"
CROSS_REVIEW_MODEL="${CROSS_REVIEW_MODEL:-}"
CROSS_REVIEW_TIMEOUT="${CROSS_REVIEW_TIMEOUT:-300}"

# Sanitize model: strip anything that could execute in a sourced context
CROSS_REVIEW_MODEL=$(printf '%s' "$CROSS_REVIEW_MODEL" | tr -cd 'a-zA-Z0-9._:/-')

# Validate tool
case "$CROSS_REVIEW_TOOL" in
  none|codex|gemini) ;;
  *) CROSS_REVIEW_TOOL="none" ;;
esac

# Degrade if binary not installed
if [ "$CROSS_REVIEW_TOOL" != "none" ]; then
  command -v "$CROSS_REVIEW_TOOL" >/dev/null 2>&1 || {
    echo "WARNING: CROSS_REVIEW_TOOL='$CROSS_REVIEW_TOOL' not found in PATH — skipping" >&2
    CROSS_REVIEW_TOOL="none"
  }
fi

# Emit resolved config
printf 'CROSS_REVIEW_TOOL=%s\n' "$CROSS_REVIEW_TOOL"
printf 'CROSS_REVIEW_MODEL=%s\n' "$CROSS_REVIEW_MODEL"

if [ "$CROSS_REVIEW_TOOL" = "none" ]; then
  printf 'CROSS_REVIEW_STATUS=skipped\n'
  exit 0
fi

# Export for structured.sh
export CROSS_REVIEW_TOOL CROSS_REVIEW_MODEL

# Run structured review with timeout enforcement
_EXIT=0
if command -v timeout >/dev/null 2>&1; then
  ARTEFACTS_DIR="$ARTEFACTS_DIR" DIFF_PATCH="${DIFF_PATCH:-}" \
    timeout "$CROSS_REVIEW_TIMEOUT" bash "$SCRIPT_DIR/structured.sh" || _EXIT=$?
elif command -v gtimeout >/dev/null 2>&1; then
  ARTEFACTS_DIR="$ARTEFACTS_DIR" DIFF_PATCH="${DIFF_PATCH:-}" \
    gtimeout "$CROSS_REVIEW_TIMEOUT" bash "$SCRIPT_DIR/structured.sh" || _EXIT=$?
else
  # Portable fallback: background + guard
  ARTEFACTS_DIR="$ARTEFACTS_DIR" DIFF_PATCH="${DIFF_PATCH:-}" \
    bash "$SCRIPT_DIR/structured.sh" &
  _PID=$!
  ( sleep "$CROSS_REVIEW_TIMEOUT" && kill "$_PID" 2>/dev/null ) &
  _GUARD=$!
  wait "$_PID" 2>/dev/null || _EXIT=$?
  kill "$_GUARD" 2>/dev/null || true
  wait "$_GUARD" 2>/dev/null || true
  # Normalize signal exits to GNU timeout convention (124)
  if [ "$_EXIT" -eq 137 ] || [ "$_EXIT" -eq 143 ]; then
    _EXIT=124
  fi
fi

# Determine final status
if [ "$_EXIT" -eq 124 ]; then
  # Timeout expired — preserve partial artifacts if any
  [ -f "$ARTEFACTS_DIR/cross_review_structured.yaml" ] || printf '[]\n' > "$ARTEFACTS_DIR/cross_review_structured.yaml"
  [ -f "$ARTEFACTS_DIR/cross_review_structured.txt" ] || : > "$ARTEFACTS_DIR/cross_review_structured.txt"
  printf 'CROSS_REVIEW_STATUS=timed-out\n'
  exit 0
fi

# Read status from file (written by structured.sh)
if [ -f "$ARTEFACTS_DIR/cross_review_status.txt" ] && [ -s "$ARTEFACTS_DIR/cross_review_status.txt" ]; then
  CROSS_REVIEW_STATUS=$(cat "$ARTEFACTS_DIR/cross_review_status.txt")
else
  CROSS_REVIEW_STATUS="failed"
fi

# Validate status value
case "$CROSS_REVIEW_STATUS" in
  ran|raw-only|failed) ;;
  *) CROSS_REVIEW_STATUS="failed" ;;
esac

printf 'CROSS_REVIEW_STATUS=%s\n' "$CROSS_REVIEW_STATUS"
