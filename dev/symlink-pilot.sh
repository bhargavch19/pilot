#!/usr/bin/env bash
# Symlink pilot build dir to ~/.claude/skills/pilot for live editing.
set -euo pipefail

BUILD="$(cd "$(dirname "$0")/.." && pwd)/pilot"
TARGET="$HOME/.claude/skills/pilot"

mkdir -p "$HOME/.claude/skills"

if [[ -L "$TARGET" ]]; then
  echo "Removing existing symlink: $TARGET"
  rm "$TARGET"
elif [[ -e "$TARGET" ]]; then
  BACKUP="$TARGET.bak.$(date +%s)"
  echo "Backing up existing dir to $BACKUP"
  mv "$TARGET" "$BACKUP"
fi

ln -s "$BUILD" "$TARGET"
echo "Symlinked: $TARGET -> $BUILD"
ls -la "$TARGET"
