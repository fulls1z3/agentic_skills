#!/usr/bin/env bash
set -euo pipefail

# Usage: gather_context.sh <base_branch>
# Produces: /tmp/code-review/{diff.patch,changed_files.txt,diff_stat.txt,pr.json,commits.txt,uncommitted.txt}

BASE="${1:?BASE_BRANCH required}"
OUTDIR="/tmp/code-review"
mkdir -p "$OUTDIR"

# Branch diff artefacts — use the same comparison basis everywhere
git diff "origin/${BASE}...HEAD" > "$OUTDIR/diff.patch"
git diff "origin/${BASE}...HEAD" --stat > "$OUTDIR/diff_stat.txt"
git diff "origin/${BASE}...HEAD" --name-only > "$OUTDIR/changed_files.txt"
git log "origin/${BASE}..HEAD" --oneline > "$OUTDIR/commits.txt"

# Diff size
DIFF_INS=$(tail -1 "$OUTDIR/diff_stat.txt" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
DIFF_DEL=$(tail -1 "$OUTDIR/diff_stat.txt" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")
DIFF_TOTAL=$(( DIFF_INS + DIFF_DEL ))
echo "$DIFF_TOTAL" > "$OUTDIR/diff_total.txt"

# Uncommitted changes
git diff --stat > "$OUTDIR/uncommitted.txt" 2>/dev/null || true

# PR metadata
gh pr view --json title,body,number -q '{"number":.number,"title":.title,"body":.body}' \
  2>/dev/null > "$OUTDIR/pr.json" || echo "{}" > "$OUTDIR/pr.json"

# TODOS
[ -f TODOS.md ] && cp TODOS.md "$OUTDIR/todos.txt" || touch "$OUTDIR/todos.txt"

echo "ARTEFACTS_DIR=$OUTDIR"
echo "DIFF_TOTAL=$DIFF_TOTAL"