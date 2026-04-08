#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "ERROR: Not inside a git repository" >&2
  exit 1
}
cd "$REPO_ROOT"

BASE=""
_REMOTE="origin"

# 0. Branch's upstream tracking ref (most accurate when configured via push -u or checkout -t)
_TRACKING=$(git rev-parse --abbrev-ref "@{u}" 2>/dev/null || true)
if [ -n "$_TRACKING" ]; then
  _REMOTE=$(printf '%s' "$_TRACKING" | cut -d/ -f1)
  BASE=$(printf '%s' "$_TRACKING" | sed 's|^[^/]*/||')
fi

# 1. GitHub PR base (overrides tracking-derived base when a PR is open)
_GH_BASE=$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null || true)
[ -n "$_GH_BASE" ] && BASE="$_GH_BASE"

# 2. GitHub repo default
[ -z "$BASE" ] && BASE=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || true)

# 3. Git symbolic ref
[ -z "$BASE" ] && BASE=$(git -C "$REPO_ROOT" symbolic-ref "refs/remotes/${_REMOTE}/HEAD" 2>/dev/null | sed "s|refs/remotes/${_REMOTE}/||" || true)

# 4. Probe main/master
[ -z "$BASE" ] && git -C "$REPO_ROOT" rev-parse --verify "${_REMOTE}/main" >/dev/null 2>&1 && BASE="main"
[ -z "$BASE" ] && git -C "$REPO_ROOT" rev-parse --verify "${_REMOTE}/master" >/dev/null 2>&1 && BASE="master"

# 5. Fallback
[ -z "$BASE" ] && BASE="main"

# Merge-base (REAL anchor)
MERGE_BASE=$(git -C "$REPO_ROOT" merge-base HEAD "${_REMOTE}/$BASE" 2>/dev/null || true)

# Hard fallback (never empty)
[ -z "$MERGE_BASE" ] && MERGE_BASE="${_REMOTE}/$BASE"

echo "BASE_BRANCH=$BASE"
echo "MERGE_BASE=$MERGE_BASE"
