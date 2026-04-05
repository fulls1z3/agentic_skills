#!/usr/bin/env bash
set -euo pipefail

# Reads branch-scoped review_state.yaml → PRIOR_STATE_EXISTS, PRIOR_HEAD_COMMIT, PRIOR_FINGERPRINTS_FILE. Always exits 0.

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  printf 'PRIOR_STATE_EXISTS=false\n'
  exit 0
}

_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
_PROJECT_KEY=$(printf '%s|%s' "$REPO_ROOT" "$_BRANCH" | cksum | awk '{print $1}')
_STATE_FILE="/tmp/code-review-state-${_PROJECT_KEY}/review_state.yaml"

if [ ! -f "$_STATE_FILE" ]; then
  printf 'PRIOR_STATE_EXISTS=false\n'
  exit 0
fi

# Minimal validity check — must have head_commit key
if ! grep -q '^head_commit:' "$_STATE_FILE" 2>/dev/null; then
  printf 'PRIOR_STATE_EXISTS=false\n'
  exit 0
fi

_FP_TMP=$(mktemp /tmp/code-review-prior-fp.XXXXXX)

PRIOR_HEAD_COMMIT=$(grep -m1 '^head_commit: ' "$_STATE_FILE" 2>/dev/null \
  | sed 's/^[^:]*: "//;s/"[[:space:]]*$//' || true)

# Fingerprints: extract list items under `fingerprints:` section → temp file
awk '
  /^fingerprints:/              { in_fps=1; next }
  in_fps && /^[^ ]/ && !/^  /  { in_fps=0 }
  in_fps && /^  - / {
    val=$0; sub(/^  - "?/,"",val); sub(/"?[[:space:]]*$/,"",val)
    if (val != "") print val
  }
' "$_STATE_FILE" 2>/dev/null > "$_FP_TMP" || { rm -f "$_FP_TMP"; true; }

printf 'PRIOR_STATE_EXISTS=true\n'
printf 'PRIOR_HEAD_COMMIT=%s\n'        "$PRIOR_HEAD_COMMIT"
printf 'PRIOR_FINGERPRINTS_FILE=%s\n' "$_FP_TMP"
