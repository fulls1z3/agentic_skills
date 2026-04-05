#!/usr/bin/env bash
set -euo pipefail

# Resolves second-opinion config → so_config.sh. Required: ARTEFACTS_DIR.

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "ERROR: Not inside a git repository" >&2
  exit 1
}

OUTDIR="${ARTEFACTS_DIR:?ARTEFACTS_DIR not set}"
if [ ! -d "$OUTDIR" ]; then
  echo "ERROR: $OUTDIR does not exist" >&2
  exit 1
fi

CONFIG_FILE=""
_ENV_CONFIG="${SECOND_OPINION_CONFIG:-}"
if [ -n "$_ENV_CONFIG" ]; then
  if [ ! -f "$_ENV_CONFIG" ]; then
    echo "ERROR: config env var set to '$_ENV_CONFIG' but file not found" >&2
    exit 1
  fi
  CONFIG_FILE="$_ENV_CONFIG"
elif [ -f "$REPO_ROOT/.claude/second-opinion.json" ]; then
  CONFIG_FILE="$REPO_ROOT/.claude/second-opinion.json"
elif [ -f "$REPO_ROOT/.agents/second-opinion.json" ]; then
  CONFIG_FILE="$REPO_ROOT/.agents/second-opinion.json"
elif [ -f "$HOME/.claude/second-opinion.json" ]; then
  CONFIG_FILE="$HOME/.claude/second-opinion.json"
elif [ -f "$HOME/.agents/second-opinion.json" ]; then
  CONFIG_FILE="$HOME/.agents/second-opinion.json"
fi

if [ -n "$CONFIG_FILE" ]; then
  # Flat JSON key-value extraction (no Python/Ruby)
  SO_TOOL=$(grep -oE '"tool"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" \
            | grep -oE '"[^"]*"$' | tr -d '"' || true)
  SO_MODEL=$(grep -oE '"model"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" \
             | grep -oE '"[^"]*"$' | tr -d '"' || true)
  # Sanitize SO_MODEL: strip anything that could execute in a sourced shell file
  SO_MODEL=$(printf '%s' "${SO_MODEL:-}" | tr -cd 'a-zA-Z0-9._:/-')
  [ -z "$SO_TOOL" ] && SO_TOOL="none"
else
  SO_TOOL="none"
  SO_MODEL=""
fi

case "$SO_TOOL" in
  none|codex|gemini) ;;
  *) SO_TOOL="none" ;;
esac

# Degrade if tool not installed
if [ "$SO_TOOL" != "none" ]; then
  command -v "$SO_TOOL" >/dev/null 2>&1 || {
    echo "WARNING: SO_TOOL '$SO_TOOL' configured but not found in PATH — defaulting to none" >&2
    SO_TOOL="none"
  }
fi

echo "SO_TOOL=$SO_TOOL"
echo "SO_MODEL=${SO_MODEL:-}"

cat > "$OUTDIR/so_config.sh" <<EOF
SO_TOOL="$SO_TOOL"
SO_MODEL="${SO_MODEL:-}"
EOF
