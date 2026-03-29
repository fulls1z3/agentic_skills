#!/usr/bin/env bash
set -euo pipefail

REPO_SKILLS_DIR="$(cd "$(dirname "$0")/.claude/skills" && pwd)"
GLOBAL_SKILLS_DIR="$HOME/.claude/skills"

if [ ! -d "$REPO_SKILLS_DIR" ]; then
  echo "ERROR: Repo skills directory not found: $REPO_SKILLS_DIR"
  exit 1
fi

mkdir -p "$GLOBAL_SKILLS_DIR"

echo "Installing skills from $REPO_SKILLS_DIR → $GLOBAL_SKILLS_DIR"
echo ""

installed=0
updated=0

for skill_dir in "$REPO_SKILLS_DIR"/*/; do
  [ -d "$skill_dir" ] || continue

  skill_name="$(basename "$skill_dir")"
  dest="$GLOBAL_SKILLS_DIR/$skill_name"

  if [ -d "$dest" ]; then
    cp -r "$skill_dir" "$GLOBAL_SKILLS_DIR/"
    echo "  updated  $skill_name"
    updated=$((updated + 1))
  else
    cp -r "$skill_dir" "$GLOBAL_SKILLS_DIR/"
    echo "  installed  $skill_name"
    installed=$((installed + 1))
  fi
done

echo ""
echo "Done. $installed installed, $updated updated."
echo "Restart Claude Code to pick up changes."
