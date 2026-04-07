#!/usr/bin/env bash
set -euo pipefail

# Generates incremental diff artifacts and emits reviewability signal.
# Required env: ARTEFACTS_DIR, PRIOR_HEAD_COMMIT
# Writes: incremental_diff.patch, incremental_changed_files.txt
# Emits: INCREMENTAL_CHANGED_COUNT, INCREMENTAL_DIFF_TOTAL, INCREMENTAL_REVIEWABLE

ARTEFACTS_DIR="${ARTEFACTS_DIR:?ARTEFACTS_DIR required}"
PRIOR_HEAD_COMMIT="${PRIOR_HEAD_COMMIT:?PRIOR_HEAD_COMMIT required}"

_DIFF="$ARTEFACTS_DIR/incremental_diff.patch"
_FILES="$ARTEFACTS_DIR/incremental_changed_files.txt"

# Commit-to-commit delta (empty when HEAD == PRIOR_HEAD_COMMIT)
git diff "${PRIOR_HEAD_COMMIT}..HEAD" -- > "$_DIFF"
git diff --name-only "${PRIOR_HEAD_COMMIT}..HEAD" > "$_FILES"

# Append tracked working-tree changes (staged + unstaged)
_WT_DIFF=$(git diff HEAD 2>/dev/null || true)
if [ -n "$_WT_DIFF" ]; then
  printf '%s\n' "$_WT_DIFF" >> "$_DIFF"
  git diff --name-only HEAD 2>/dev/null >> "$_FILES" || true
  sort -u "$_FILES" -o "$_FILES" 2>/dev/null || true
fi

# Untracked reviewable files — extension allowlist (not a giant ignore list)
_REVIEW_EXTS='\.(tsx?|jsx?|py|rb|rs|go|java|kt|swift|c|cpp|h|hpp|cs|php|sh|bash|zsh|sql|ya?ml|json|toml|ini|cfg|md|txt|html|css|scss|vue|svelte|proto|graphql|tf|hcl)$'
_REVIEW_NAMES='^(Dockerfile|Makefile|Gemfile|Rakefile|Procfile|Justfile)$'

_REVIEWABLE_UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null \
  | grep -iE "($_REVIEW_EXTS|$_REVIEW_NAMES)" || true)

if [ -n "$_REVIEWABLE_UNTRACKED" ]; then
  printf '%s\n' "$_REVIEWABLE_UNTRACKED" >> "$_FILES"
  sort -u "$_FILES" -o "$_FILES" 2>/dev/null || true
  # Generate diff vs /dev/null for each untracked file
  while IFS= read -r _uf; do
    [ -f "$_uf" ] && git diff --no-index /dev/null "$_uf" >> "$_DIFF" 2>/dev/null || true
  done <<< "$_REVIEWABLE_UNTRACKED"
fi

INCREMENTAL_CHANGED_COUNT=$(wc -l < "$_FILES" 2>/dev/null | tr -d ' ')
INCREMENTAL_DIFF_TOTAL=$(wc -l < "$_DIFF" 2>/dev/null | tr -d ' ')

# Reviewability signal: false when no changed files (authoritative)
if [ "$INCREMENTAL_CHANGED_COUNT" -gt 0 ]; then
  INCREMENTAL_REVIEWABLE=true
else
  INCREMENTAL_REVIEWABLE=false
fi

printf 'INCREMENTAL_CHANGED_COUNT=%d\n' "$INCREMENTAL_CHANGED_COUNT"
printf 'INCREMENTAL_DIFF_TOTAL=%d\n' "$INCREMENTAL_DIFF_TOTAL"
printf 'INCREMENTAL_REVIEWABLE=%s\n' "$INCREMENTAL_REVIEWABLE"
