#!/usr/bin/env bash
set -euo pipefail

# Returns the base branch name. Prints BASE_BRANCH=<name> to stdout.

BASE=""

# 1. GitHub PR base
BASE=$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null || true)
[ -n "$BASE" ] && echo "BASE_BRANCH=$BASE" && exit 0

# 2. GitHub repo default
BASE=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || true)
[ -n "$BASE" ] && echo "BASE_BRANCH=$BASE" && exit 0

# 3. Git symbolic ref
BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || true)
[ -n "$BASE" ] && echo "BASE_BRANCH=$BASE" && exit 0

# 4. Probe main/master
git rev-parse --verify origin/main >/dev/null 2>&1 && echo "BASE_BRANCH=main" && exit 0
git rev-parse --verify origin/master >/dev/null 2>&1 && echo "BASE_BRANCH=master" && exit 0

# 5. Fallback
echo "BASE_BRANCH=main"