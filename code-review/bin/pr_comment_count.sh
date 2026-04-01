#!/usr/bin/env bash
set -euo pipefail

# Prints PR_NUMBER and COMMENT_COUNT. Writes to /tmp/code-review/pr_meta.txt.

OUTDIR="/tmp/code-review"
mkdir -p "$OUTDIR"

PR_NUMBER=$(gh pr view --json number -q .number 2>/dev/null || true)

if [ -z "$PR_NUMBER" ]; then
  echo "PR_NUMBER= COMMENT_COUNT=0"
  echo "PR_NUMBER=" > "$OUTDIR/pr_meta.txt"
  echo "COMMENT_COUNT=0" >> "$OUTDIR/pr_meta.txt"
  exit 0
fi

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
REVIEW_COMMENTS=$(gh api "repos/$REPO/pulls/$PR_NUMBER/comments" --jq 'length' 2>/dev/null || echo 0)
ISSUE_COMMENTS=$(gh api "repos/$REPO/issues/$PR_NUMBER/comments" --jq 'length' 2>/dev/null || echo 0)
COMMENT_COUNT=$(( REVIEW_COMMENTS + ISSUE_COMMENTS ))

echo "PR_NUMBER=$PR_NUMBER COMMENT_COUNT=$COMMENT_COUNT"
echo "PR_NUMBER=$PR_NUMBER" > "$OUTDIR/pr_meta.txt"
echo "COMMENT_COUNT=$COMMENT_COUNT" >> "$OUTDIR/pr_meta.txt"