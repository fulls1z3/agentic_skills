#!/usr/bin/env bash
set -euo pipefail

# Usage: run_second_opinion_adversarial.sh <base_branch>
# HIGH only. Sources /tmp/code-review/so_config.sh
# Writes to /tmp/code-review/so_adversarial.txt

BASE="${1:?BASE_BRANCH required}"
OUTDIR="/tmp/code-review"
source "$OUTDIR/so_config.sh"

BOUNDARY=$(cat code-review/prompts/boundary.txt)
PROMPT=$(cat code-review/prompts/second_opinion_adversarial.txt)
TMPERR=$(mktemp /tmp/so-adv-XXXXXXXX)
_REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$_REPO_ROOT"

if [ "$SO_TOOL" = "none" ]; then
  echo "ADVERSARIAL_SKIPPED: no tool available" | tee "$OUTDIR/so_adversarial.txt"
  exit 0
fi

if [ "$SO_TOOL" = "codex" ]; then
  codex exec \
    "$BOUNDARY $PROMPT" \
    -C "$_REPO_ROOT" \
    -s read-only \
    -c 'model_reasoning_effort="high"' \
    --enable web_search_cached \
    $MODEL_FLAG \
    2>"$TMPERR" | tee "$OUTDIR/so_adversarial.txt"
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
Then perform the adversarial review on that diff only." \
    2>"$TMPERR" | tee "$OUTDIR/so_adversarial.txt"
fi

cat "$TMPERR" >&2 || true