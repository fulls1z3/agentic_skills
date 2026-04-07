#!/usr/bin/env bash
set -euo pipefail

# Usage: gather_context.sh <base_branch>
# Creates per-run ARTEFACTS_DIR and writes diff artifacts. Prints ARTEFACTS_DIR= and DIFF_TOTAL=.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "ERROR: Not inside a git repository" >&2
  exit 1
}
cd "$REPO_ROOT"

_PROJECT_KEY=$(printf '%s' "$REPO_ROOT" | cksum | awk '{print $1}')
OUTDIR="/tmp/change-review-${_PROJECT_KEY}-$$"
rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"

if [ -n "${1:-}" ]; then
  BASE_BRANCH="$1"
  MERGE_BASE=$(git -C "$REPO_ROOT" merge-base HEAD "origin/$BASE_BRANCH" 2>/dev/null || echo "origin/$BASE_BRANCH")
else
  _DETECT_OUT=$(bash "$SCRIPT_DIR/detect_base.sh" 2>/dev/null || true)
  BASE_BRANCH=$(printf '%s\n' "$_DETECT_OUT" | grep '^BASE_BRANCH=' | cut -d= -f2-)
  MERGE_BASE=$(printf '%s\n' "$_DETECT_OUT" | grep '^MERGE_BASE=' | cut -d= -f2-)
fi
# Fallbacks — must never be empty under set -euo pipefail
[ -z "${BASE_BRANCH:-}" ] && BASE_BRANCH="main"
[ -z "${MERGE_BASE:-}" ]  && MERGE_BASE="origin/$BASE_BRANCH"

git -C "$REPO_ROOT" diff "$MERGE_BASE"...HEAD > "$OUTDIR/diff.patch"
git -C "$REPO_ROOT" diff "$MERGE_BASE"...HEAD --name-only > "$OUTDIR/changed_files.txt"
git -C "$REPO_ROOT" log "$MERGE_BASE"..HEAD --oneline > "$OUTDIR/commits.txt"

DIFF_TOTAL=$(git -C "$REPO_ROOT" diff "$MERGE_BASE"...HEAD --numstat 2>/dev/null \
  | awk '{s+=$1+$2} END{print int(s+0)}')
echo "$DIFF_TOTAL" > "$OUTDIR/diff_total.txt"

git -C "$REPO_ROOT" diff HEAD --stat > "$OUTDIR/uncommitted.txt" 2>/dev/null || true

gh pr view --json title,body,number -q '{"number":.number,"title":.title,"body":.body}' \
  2>/dev/null > "$OUTDIR/pr.json" || echo "{}" > "$OUTDIR/pr.json"

# Transition-state detection: bulk deletions (staged or unstaged) + untracked replacements
_TRANSITION=false
_PORCELAIN=$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null || true)
if [ -n "$_PORCELAIN" ]; then
  _DEL_COUNT=$(printf '%s\n' "$_PORCELAIN" | grep -cE '^D|^ D' 2>/dev/null) || _DEL_COUNT=0
  _UNTRACKED=$(printf '%s\n' "$_PORCELAIN" | grep -c '^??' 2>/dev/null) || _UNTRACKED=0
  if [ "$_DEL_COUNT" -gt 10 ] && [ "$_UNTRACKED" -gt 5 ]; then
    _TRANSITION=true
  fi
fi
echo "$_TRANSITION" > "$OUTDIR/transition_state.txt"

echo "ARTEFACTS_DIR=$OUTDIR"
echo "DIFF_TOTAL=$DIFF_TOTAL"
echo "TRANSITION_STATE=$_TRANSITION"
