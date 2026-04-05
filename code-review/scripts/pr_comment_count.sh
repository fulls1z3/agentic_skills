#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "ERROR: Not inside a git repository" >&2
  exit 1
}
cd "$REPO_ROOT"

PR_NUMBER=$(gh pr view --json number -q .number 2>/dev/null || true)

if [ -z "$PR_NUMBER" ]; then
  echo "PR_NUMBER="
  echo "COMMENT_COUNT=0"
  exit 0
fi

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
REVIEW_COMMENTS=$(gh api "repos/$REPO/pulls/$PR_NUMBER/comments" --jq 'length' 2>/dev/null || echo 0)
ISSUE_COMMENTS=$(gh api "repos/$REPO/issues/$PR_NUMBER/comments" --jq 'length' 2>/dev/null || echo 0)
COMMENT_COUNT=$(( REVIEW_COMMENTS + ISSUE_COMMENTS ))

echo "PR_NUMBER=$PR_NUMBER"
echo "COMMENT_COUNT=$COMMENT_COUNT"
