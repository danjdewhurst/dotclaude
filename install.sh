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

configured_shell="$(sed -n 's/.*"SHELL"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$REPO/settings.json")"

if [ -n "$configured_shell" ] && [ ! -x "$configured_shell" ]; then
  echo
  echo "WARNING: settings.json sets SHELL to $configured_shell, which is not executable here."
  echo "Claude Code will fail to start a shell until this is fixed."
  if command -v bash >/dev/null; then
    echo "This machine has bash at: $(command -v bash)"
  fi
  if command -v brew >/dev/null; then
    echo "For an up-to-date bash: brew install bash"
  fi
  echo "Edit the SHELL value in $REPO/settings.json to match."
fi
