#!/usr/bin/env bash
set -euo pipefail

# Posts main report comment and inline review comments with local persistence.
# Main comment: skip if fingerprint unchanged, update if changed + prior exists, create otherwise.
# Inline comments: dedupe by fingerprint, never update/replace/resolve old ones.
# Always exits 0.

ARTEFACTS_DIR="${ARTEFACTS_DIR:?ARTEFACTS_DIR not set}"

_report_file="$ARTEFACTS_DIR/report.md"
_inline_file="$ARTEFACTS_DIR/inline_comments.txt"

PR_COMMENT_POSTED=false
PR_INLINE_COUNT=0

_emit() {
  echo "PR_COMMENT_POSTED=$PR_COMMENT_POSTED"
  echo "PR_INLINE_COUNT=$PR_INLINE_COUNT"
}

if [ ! -f "$_report_file" ] || [ ! -s "$_report_file" ]; then
  _emit; exit 0
fi

PR_NUMBER=$(gh pr view --json number -q .number 2>/dev/null || true)
if [ -z "$PR_NUMBER" ]; then
  _emit; exit 0
fi

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
if [ -z "$REPO" ]; then
  _emit; exit 0
fi

# --- State directory (matches write_review_state.sh derivation) ---
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || REPO_ROOT="$(pwd)"
_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
_PROJECT_KEY=$(printf '%s|%s' "$REPO_ROOT" "$_BRANCH" | cksum | awk '{print $1}')
STATE_DIR="/tmp/change-review-state-${_PROJECT_KEY}"
_PR_STATE="$STATE_DIR/pr_comment_state.yaml"
if [ -e "$STATE_DIR" ] && { [ ! -d "$STATE_DIR" ] || [ -L "$STATE_DIR" ]; }; then
  _emit; exit 0
fi
mkdir -m 0700 -p "$STATE_DIR" 2>/dev/null || true
_DIR_OWNER=$(stat -f '%u' "$STATE_DIR" 2>/dev/null || stat -c '%u' "$STATE_DIR" 2>/dev/null || true)
if [ -n "$_DIR_OWNER" ] && [ "$_DIR_OWNER" != "$(id -u)" ]; then
  _emit; exit 0
fi

# Temp files
_TMPDIR=$(mktemp -d)
trap 'rm -rf "$_TMPDIR"' EXIT
_PRIOR_INLINE_FPS="$_TMPDIR/prior_inline_fps.txt"
_NEW_INLINE_FPS="$_TMPDIR/new_inline_fps.txt"
> "$_PRIOR_INLINE_FPS"
> "$_NEW_INLINE_FPS"

# --- Load prior PR comment state ---
_PRIOR_MAIN_ID=""
_PRIOR_MAIN_FP=""
if [ -f "$_PR_STATE" ]; then
  _PRIOR_MAIN_ID=$(grep -m1 '^main_comment_id: ' "$_PR_STATE" 2>/dev/null \
    | sed 's/^[^:]*: //;s/^"//;s/"[[:space:]]*$//' || true)
  _PRIOR_MAIN_FP=$(grep -m1 '^main_comment_fingerprint: ' "$_PR_STATE" 2>/dev/null \
    | sed 's/^[^:]*: //;s/^"//;s/"[[:space:]]*$//' || true)
  awk '
    /^posted_inline_fingerprints:/  { in_fp=1; next }
    in_fp && /^[^ ]/ && !/^  /     { in_fp=0 }
    in_fp && /^  - / {
      val=$0; sub(/^  - "?/,"",val); sub(/"?[[:space:]]*$/,"",val)
      if (val != "") print val
    }
  ' "$_PR_STATE" 2>/dev/null > "$_PRIOR_INLINE_FPS" || true
fi
cat "$_PRIOR_INLINE_FPS" > "$_NEW_INLINE_FPS" 2>/dev/null || true

# --- Compute summary fingerprint ---
_SUMMARY_FP=$(cksum < "$_report_file" | awk '{print $1}')

# --- Main comment ---
_NEW_MAIN_ID="$_PRIOR_MAIN_ID"
_PERSIST_FP="$_PRIOR_MAIN_FP"
if [ "$_SUMMARY_FP" = "$_PRIOR_MAIN_FP" ]; then
  # Fingerprint unchanged → skip
  PR_COMMENT_POSTED=true
  _PERSIST_FP="$_SUMMARY_FP"
elif [ -n "$_PRIOR_MAIN_ID" ]; then
  # Fingerprint changed + prior comment exists → update
  _UPD=$(gh api --method PATCH "repos/$REPO/issues/comments/$_PRIOR_MAIN_ID" \
    --field body=@"$_report_file" --jq '.id' 2>/dev/null || true)
  if [ -n "$_UPD" ]; then
    PR_COMMENT_POSTED=true
    _NEW_MAIN_ID="$_UPD"
    _PERSIST_FP="$_SUMMARY_FP"
  fi
else
  # No prior comment → create
  _CRE=$(gh api --method POST "repos/$REPO/issues/$PR_NUMBER/comments" \
    --field body=@"$_report_file" --jq '.id' 2>/dev/null || true)
  if [ -n "$_CRE" ]; then
    PR_COMMENT_POSTED=true
    _NEW_MAIN_ID="$_CRE"
    _PERSIST_FP="$_SUMMARY_FP"
  fi
fi

# --- Inline comments ---
if [ -s "$_inline_file" ]; then
  HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || true)
  if [ -n "$HEAD_SHA" ]; then
    while IFS='|' read -r _f _l _b; do
      [ -z "$_f" ] || [ -z "$_l" ] || [ -z "$_b" ] && continue
      _INLINE_FP=$(printf '%s|%s|%s' "$_f" "$_l" "$_b" | cksum | awk '{print $1}')
      # Dedupe: skip if already posted
      if grep -qxF "$_INLINE_FP" "$_PRIOR_INLINE_FPS" 2>/dev/null; then
        continue
      fi
      gh api --method POST "repos/$REPO/pulls/$PR_NUMBER/comments" \
        --raw-field body="$_b" \
        --field commit_id="$HEAD_SHA" \
        --raw-field path="$_f" \
        --field line="$_l" \
        --field side="RIGHT" \
        --silent 2>/dev/null \
        && { PR_INLINE_COUNT=$(( PR_INLINE_COUNT + 1 ))
             printf '%s\n' "$_INLINE_FP" >> "$_NEW_INLINE_FPS"
           } || true
    done < "$_inline_file"
  fi
fi

# --- Persist PR comment state ---
{
  printf 'main_comment_id: "%s"\n' "$_NEW_MAIN_ID"
  printf 'main_comment_fingerprint: "%s"\n' "$_PERSIST_FP"
  printf 'posted_inline_fingerprints:\n'
  if [ -s "$_NEW_INLINE_FPS" ]; then
    sort -u "$_NEW_INLINE_FPS" | while IFS= read -r _fp; do
      [ -n "$_fp" ] && printf '  - "%s"\n' "$_fp"
    done
  fi
} > "$_PR_STATE" || true

_emit
exit 0
