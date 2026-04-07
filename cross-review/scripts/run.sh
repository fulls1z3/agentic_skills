#!/usr/bin/env bash
set -euo pipefail

# run.sh — Entry point for cross-review skill. Structured review only.
# Required env: ARTEFACTS_DIR (must contain diff.patch)
# Always exits 0 — failures reported via SO_*_STATUS signals.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ARTEFACTS_DIR="${ARTEFACTS_DIR:?ARTEFACTS_DIR env var required}"

# Timeout policy: 5 minutes for both Codex and Gemini
SO_TIMEOUT="${SO_TIMEOUT:-300}"

# Step 1: Resolve config
_CONFIG_OUT=$(ARTEFACTS_DIR="$ARTEFACTS_DIR" bash "$SCRIPT_DIR/resolve.sh") || true
SO_TOOL=$(printf '%s\n' "$_CONFIG_OUT" | grep '^SO_TOOL=' | cut -d= -f2-)
printf '%s\n' "$_CONFIG_OUT"

if [ "${SO_TOOL:-none}" = "none" ]; then
  printf 'SO_STRUCTURED_STATUS=skipped\n'
  exit 0
fi

# Step 2: Run structured review with timeout enforcement
_EXIT=0
if command -v timeout >/dev/null 2>&1; then
  ARTEFACTS_DIR="$ARTEFACTS_DIR" DIFF_PATCH="${DIFF_PATCH:-}" \
    timeout "$SO_TIMEOUT" bash "$SCRIPT_DIR/structured.sh" || _EXIT=$?
elif command -v gtimeout >/dev/null 2>&1; then
  ARTEFACTS_DIR="$ARTEFACTS_DIR" DIFF_PATCH="${DIFF_PATCH:-}" \
    gtimeout "$SO_TIMEOUT" bash "$SCRIPT_DIR/structured.sh" || _EXIT=$?
else
  # Portable fallback: background + guard
  ARTEFACTS_DIR="$ARTEFACTS_DIR" DIFF_PATCH="${DIFF_PATCH:-}" \
    bash "$SCRIPT_DIR/structured.sh" &
  _PID=$!
  ( sleep "$SO_TIMEOUT" && kill "$_PID" 2>/dev/null ) &
  _GUARD=$!
  wait "$_PID" 2>/dev/null || _EXIT=$?
  kill "$_GUARD" 2>/dev/null || true
  wait "$_GUARD" 2>/dev/null || true
  # Normalize signal exits to GNU timeout convention (124)
  if [ "$_EXIT" -eq 137 ] || [ "$_EXIT" -eq 143 ]; then
    _EXIT=124
  fi
fi

# Step 3: Determine final status
if [ "$_EXIT" -eq 124 ]; then
  # Timeout expired — preserve partial artifacts if any
  [ -f "$ARTEFACTS_DIR/so_structured.yaml" ] || printf '[]\n' > "$ARTEFACTS_DIR/so_structured.yaml"
  [ -f "$ARTEFACTS_DIR/so_structured.txt" ] || : > "$ARTEFACTS_DIR/so_structured.txt"
  printf 'SO_STRUCTURED_STATUS=timed-out\n'
  exit 0
fi

# Read status from file (written by structured.sh)
if [ -f "$ARTEFACTS_DIR/so_status.txt" ] && [ -s "$ARTEFACTS_DIR/so_status.txt" ]; then
  SO_STRUCTURED_STATUS=$(cat "$ARTEFACTS_DIR/so_status.txt")
else
  SO_STRUCTURED_STATUS="failed"
fi

# Validate status value
case "$SO_STRUCTURED_STATUS" in
  ran|raw-only|failed) ;;
  *) SO_STRUCTURED_STATUS="failed" ;;
esac

printf 'SO_STRUCTURED_STATUS=%s\n' "$SO_STRUCTURED_STATUS"
