#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME/.claude/CLAUDE.md"

mkdir -p "$HOME/.claude"

if [ -L "$TARGET" ] && [ "$(readlink "$TARGET")" = "$REPO/CLAUDE.md" ]; then
  echo "Already linked: $TARGET"
  exit 0
fi

if [ -e "$TARGET" ]; then
  mv "$TARGET" "$TARGET.bak"
  echo "Backed up existing CLAUDE.md to $TARGET.bak"
fi

ln -sfn "$REPO/CLAUDE.md" "$TARGET"
echo "Linked $TARGET -> $REPO/CLAUDE.md"
