#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES=(CLAUDE.md settings.json)

mkdir -p "$HOME/.claude"

for f in "${FILES[@]}"; do
  target="$HOME/.claude/$f"

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$REPO/$f" ]; then
    echo "Already linked: $target"
    continue
  fi

  if [ -e "$target" ]; then
    mv "$target" "$target.bak"
    echo "Backed up existing $f to $target.bak"
  fi

  ln -sfn "$REPO/$f" "$target"
  echo "Linked $target -> $REPO/$f"
done
