#!/usr/bin/env bash
set -euo pipefail

# Reads .claude/code-review.json, resolves SO_TOOL, prints env vars.
# Writes /tmp/code-review/so_config.sh (sourceable).

OUTDIR="/tmp/code-review"
CONFIG_FILE=".claude/code-review.json"

if [ -f "$CONFIG_FILE" ]; then
  SO_TOOL=$(python3 -c "import json,sys; d=json.load(open('$CONFIG_FILE')); print(d.get('second-opinion-tool','auto'))" 2>/dev/null || echo "auto")
  SO_MODEL=$(python3 -c "import json,sys; d=json.load(open('$CONFIG_FILE')); print(d.get('second-opinion-model',''))" 2>/dev/null || echo "")
  SO_TIMEOUT=$(python3 -c "import json,sys; d=json.load(open('$CONFIG_FILE')); print(d.get('timeout',300000))" 2>/dev/null || echo "300000")
else
  SO_TOOL="auto"
  SO_MODEL=""
  SO_TIMEOUT=300000
fi

# Resolve auto
if [ "$SO_TOOL" = "auto" ]; then
  if which codex >/dev/null 2>&1; then
    SO_TOOL="codex"
  elif which gemini >/dev/null 2>&1; then
    SO_TOOL="gemini"
  else
    SO_TOOL="none"
  fi
fi

# Verify binary exists
if [ "$SO_TOOL" != "none" ] && ! which "$SO_TOOL" >/dev/null 2>&1; then
  echo "WARNING: $SO_TOOL not found, falling back to none"
  SO_TOOL="none"
fi

# Model flag
MODEL_FLAG=""
[ -n "$SO_MODEL" ] && MODEL_FLAG="-m $SO_MODEL"

echo "SO_TOOL=$SO_TOOL"
echo "SO_MODEL=$SO_MODEL"
echo "SO_TIMEOUT=$SO_TIMEOUT"
echo "MODEL_FLAG=$MODEL_FLAG"

# Write sourceable file
cat > "$OUTDIR/so_config.sh" <<EOF
SO_TOOL="$SO_TOOL"
SO_MODEL="$SO_MODEL"
SO_TIMEOUT="$SO_TIMEOUT"
MODEL_FLAG="$MODEL_FLAG"
EOF