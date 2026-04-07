#!/usr/bin/env bash
set -euo pipefail

# Persists branch-scoped review state. Required: ARTEFACTS_DIR (except no-change mode). Always exits 0.

REVIEW_MODE="${REVIEW_MODE:-full}"
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || REPO_ROOT="$(pwd)"
_BRANCH=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
_PROJECT_KEY=$(printf '%s|%s' "$REPO_ROOT" "$_BRANCH" | cksum | awk '{print $1}')
STATE_DIR="/tmp/change-review-state-${_PROJECT_KEY}"
STATE_FILE="$STATE_DIR/review_state.yaml"

if [ "$REVIEW_MODE" = "no-change" ]; then
  if [ -f "$STATE_FILE" ]; then
    _FINISHED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    _NO_CHANGE_TMP=$(mktemp)
    if sed \
        -e "s|^  finished_at: \"[^\"]*\"|  finished_at: \"${_FINISHED_AT}\"|" \
        -e "s|^  mode: \"[^\"]*\"|  mode: \"no-change\"|" \
        "$STATE_FILE" > "$_NO_CHANGE_TMP" && mv "$_NO_CHANGE_TMP" "$STATE_FILE"; then
      printf 'REVIEW_STATE_WRITTEN: %s\n' "$STATE_FILE"
    else
      rm -f "$_NO_CHANGE_TMP"
      printf 'REVIEW_STATE_WARNING: failed to update review_state.yaml for no-change mode\n' >&2
    fi
  fi
  exit 0
fi

ARTEFACTS_DIR="${ARTEFACTS_DIR:?ARTEFACTS_DIR env var required}"
SPECIALISTS_RUN="${SPECIALISTS_RUN:-}"
BASE_BRANCH="${BASE_BRANCH:-main}"
STARTED_AT="${STARTED_AT:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
FINISHED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

BRANCH=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
HEAD_COMMIT=$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "unknown")
MERGE_BASE=$(git -C "$REPO_ROOT" merge-base HEAD "origin/${BASE_BRANCH}" 2>/dev/null \
  | cut -c1-8 || echo "unknown")

# Emit fingerprint YAML lines
_fingerprints() {
  local file="$1" indent="$2"
  [ -s "$file" ] || return 0
  awk -v IND="$indent" '
    BEGIN { sev=""; fil=""; sum=""; fp="" }
    function flush() {
      if (sev == "" && sum == "") return
      if (fp == "") fp = sev "|" fil "|" sum
      if (fp != "") printf "%s- \"%s\"\n", IND, fp
    }
    /^- severity: /    { flush(); sev=$0; sub(/^- severity:[[:space:]]*/,"",sev); gsub(/[[:space:]]*$/,"",sev); fil=""; sum=""; fp="" }
    /^  file: /        { fil=$0; sub(/^  file:[[:space:]]*"?/,"",fil);        sub(/"?[[:space:]]*$/,"",fil)        }
    /^  summary: /     { sum=$0; sub(/^  summary:[[:space:]]*"?/,"",sum);     sub(/"?[[:space:]]*$/,"",sum)        }
    /^  fingerprint: / { fp=$0;  sub(/^  fingerprint:[[:space:]]*"?/,"",fp);  sub(/"?[[:space:]]*$/,"",fp)         }
    END { flush() }
  ' "$file" 2>/dev/null || true
}

_TMPDIR=$(mktemp -d)
trap 'rm -rf "$_TMPDIR"' EXIT

{
  _fingerprints "$ARTEFACTS_DIR/findings.yaml"      "  " 2>/dev/null || true
  _fingerprints "$ARTEFACTS_DIR/cross_review_structured.yaml" "  " 2>/dev/null || true
} | sort -u > "$_TMPDIR/fingerprints.yaml"

_do_write() {
  if [ -e "$STATE_DIR" ] && { [ ! -d "$STATE_DIR" ] || [ -L "$STATE_DIR" ]; }; then
    printf 'state path blocked (symlink or non-directory): %s\n' "$STATE_DIR" >&2
    return 1
  fi
  mkdir -m 0700 -p "$STATE_DIR"
  local out="$_TMPDIR/review_state.yaml"
  > "$out"

  printf 'branch: "%s"\n'      "$BRANCH"       >> "$out"
  printf 'base_branch: "%s"\n' "$BASE_BRANCH"  >> "$out"
  printf 'merge_base: "%s"\n'  "$MERGE_BASE"   >> "$out"
  printf 'head_commit: "%s"\n' "$HEAD_COMMIT"  >> "$out"
  printf '\n'                                   >> "$out"

  if [ -s "$_TMPDIR/fingerprints.yaml" ]; then
    printf 'fingerprints:\n' >> "$out"
    cat "$_TMPDIR/fingerprints.yaml" >> "$out"
  else
    printf 'fingerprints: []\n' >> "$out"
  fi
  printf '\n' >> "$out"

  printf 'specialists:\n' >> "$out"
  _SPEC_TRIMMED=$(printf '%s' "$SPECIALISTS_RUN" | tr -d '[:space:]')
  if [ -n "$_SPEC_TRIMMED" ]; then
    printf '  run:\n' >> "$out"
    printf '%s\n' "$SPECIALISTS_RUN" | tr ',' '\n' | while IFS= read -r item; do
      item=$(printf '%s' "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      [ -n "$item" ] && printf '    - %s\n' "$item" >> "$out"
    done
  else
    printf '  run: []\n' >> "$out"
  fi
  printf '\n' >> "$out"

  printf 'incremental:\n'                    >> "$out"
  printf '  mode: "%s"\n' "$REVIEW_MODE"    >> "$out"
  printf '\n' >> "$out"

  printf 'timestamps:\n'                              >> "$out"
  printf '  started_at: "%s"\n'  "$STARTED_AT"       >> "$out"
  printf '  finished_at: "%s"\n' "$FINISHED_AT"      >> "$out"

  mv "$out" "$STATE_FILE"
}

_ERR_LOG="$_TMPDIR/write_err.log"
if _do_write 2>"$_ERR_LOG"; then
  printf 'REVIEW_STATE_WRITTEN: %s\n' "$STATE_FILE"
else
  _ERR=$(head -1 "$_ERR_LOG" 2>/dev/null || echo "unknown error")
  printf 'REVIEW_STATE_WARNING: failed to write review_state.yaml — %s\n' "$_ERR" >&2
fi

exit 0
