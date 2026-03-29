#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_SKILLS_DIR="$HOME/.agents/skills"
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
SKILL_NAME=""

usage() {
  echo "Usage: $0 [-s <skill_name>]"
  echo ""
  echo "  -s <skill_name>   Install a single skill by name"
  echo ""
  echo "Without -s, installs all skills found in the repository."
  exit 1
}

while getopts ":s:h" opt; do
  case $opt in
    s) SKILL_NAME="$OPTARG" ;;
    h) usage ;;
    :) echo "ERROR: -$OPTARG requires an argument."; usage ;;
    *) echo "ERROR: Unknown option -$OPTARG"; usage ;;
  esac
done

# List skill names: directories at repo root that contain SKILL.md
find_skills() {
  for dir in "$SCRIPT_DIR"/*/; do
    [ -d "$dir" ] || continue
    [ -f "$dir/SKILL.md" ] || continue
    basename "$dir"
  done
}

install_skill() {
  local name="$1"
  local src="$SCRIPT_DIR/$name"
  local dest="$AGENTS_SKILLS_DIR/$name"
  local link="$CLAUDE_SKILLS_DIR/$name"

  if [ ! -d "$src" ]; then
    echo "ERROR: Skill '$name' not found at $src"
    exit 1
  fi
  if [ ! -f "$src/SKILL.md" ]; then
    echo "ERROR: '$name' has no SKILL.md — not a valid skill directory"
    exit 1
  fi

  # Install (copy) into ~/.agents/skills, replacing any existing version
  rm -rf "$dest"
  cp -r "$src" "$dest"

  # Create or refresh symlink in ~/.claude/skills
  if [ -L "$link" ]; then
    rm "$link"
  elif [ -e "$link" ]; then
    echo "ERROR: $link exists and is not a symlink. Remove it manually, then rerun."
    exit 1
  fi
  ln -s "$dest" "$link"

  echo "  installed  $name"
  echo "             $dest"
  echo "             $link -> $dest"
}

# Validate -s target early so we fail before touching the filesystem
if [ -n "$SKILL_NAME" ]; then
  if [ ! -d "$SCRIPT_DIR/$SKILL_NAME" ] || [ ! -f "$SCRIPT_DIR/$SKILL_NAME/SKILL.md" ]; then
    echo "ERROR: Skill '$SKILL_NAME' not found in $SCRIPT_DIR"
    echo ""
    echo "Available skills:"
    find_skills | sed 's/^/  /'
    exit 1
  fi
fi

mkdir -p "$AGENTS_SKILLS_DIR"
mkdir -p "$CLAUDE_SKILLS_DIR"

if [ -n "$SKILL_NAME" ]; then
  echo "Installing skill: $SKILL_NAME"
  echo ""
  install_skill "$SKILL_NAME"
else
  echo "Installing all skills from $SCRIPT_DIR"
  echo ""
  count=0
  while IFS= read -r skill; do
    install_skill "$skill"
    echo ""
    count=$((count + 1))
  done < <(find_skills)
  echo "Done. $count skill(s) installed."
fi

echo ""
echo "Restart Claude Code to pick up new or updated skills."
