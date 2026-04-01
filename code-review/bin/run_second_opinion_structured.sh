#!/usr/bin/env bash
set -euo pipefail

# Usage: run_second_opinion_structured.sh <base_branch>
# Sources /tmp/code-review/so_config.sh for SO_TOOL / MODEL_FLAG / SO_TIMEOUT
# Writes stdout to /tmp/code-review/so_structured.txt

BASE="${1:?BASE_BRANCH required}"
OUTDIR="/tmp/code-review"
source "$OUTDIR/so_config.sh"

PROMPT_FILE="code-review/prompts/second_opinion_structured.txt"
BOUNDARY=$(cat code-review/prompts/boundary.txt)
PROMPT=$(cat "$PROMPT_FILE")
TMPERR=$(mktemp /tmp/so-review-XXXXXXXX)
_REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$_REPO_ROOT"

if [ "$SO_TOOL" = "none" ]; then
  echo "SECOND_OPINION_SKIPPED: no tool available" | tee "$OUTDIR/so_structured.txt"
  exit 0
fi

if [ "$SO_TOOL" = "codex" ]; then
  codex review \
    "$BOUNDARY $PROMPT" \
    --base "$BASE" \
    -c 'model_reasoning_effort="high"' \
    --enable web_search_cached \
    $MODEL_FLAG \
    2>"$TMPERR" | tee "$OUTDIR/so_structured.txt"
fi

if [ "$SO_TOOL" = "gemini" ]; then
  gemini \
    --sandbox \
    --approval-mode=plan \
    $MODEL_FLAG \
    "$BOUNDARY

$PROMPT

First, run this exact command and read its full output:
cat $OUTDIR/diff.patch

Do not start the review before you have read that file.
Then review that diff only." \
    2>"$TMPERR" | tee "$OUTDIR/so_structured.txt"
fi

cat "$TMPERR" >&2 || true