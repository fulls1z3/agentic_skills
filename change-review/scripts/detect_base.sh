#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "ERROR: Not inside a git repository" >&2
  exit 1
}
cd "$REPO_ROOT"

BASE=""

# 1. GitHub PR base
BASE=$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null || true)

# 2. GitHub repo default
[ -z "$BASE" ] && BASE=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || true)

# 3. Git symbolic ref
[ -z "$BASE" ] && BASE=$(git -C "$REPO_ROOT" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || true)

# 4. Probe main/master
[ -z "$BASE" ] && git -C "$REPO_ROOT" rev-parse --verify origin/main >/dev/null 2>&1 && BASE="main"
[ -z "$BASE" ] && git -C "$REPO_ROOT" rev-parse --verify origin/master >/dev/null 2>&1 && BASE="master"

# 5. Fallback
[ -z "$BASE" ] && BASE="main"

# Merge-base (REAL anchor)
MERGE_BASE=$(git -C "$REPO_ROOT" merge-base HEAD "origin/$BASE" 2>/dev/null || true)

# Hard fallback (never empty)
[ -z "$MERGE_BASE" ] && MERGE_BASE="origin/$BASE"

echo "BASE_BRANCH=$BASE"
echo "MERGE_BASE=$MERGE_BASE"
