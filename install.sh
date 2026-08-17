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

# Package installs: Homebrew on macOS, apt on Debian/Ubuntu.
if command -v brew >/dev/null; then
  PM=brew
elif command -v apt-get >/dev/null; then
  PM=apt
  if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi
else
  PM=none
fi

pm_install() {
  case "$PM" in
    brew) brew install "$1" ;;
    apt)  [ "$2" = "-" ] && return 2; $SUDO apt-get install -y -qq "$2" ;;
  esac
}

# Debian renames some binaries to avoid clashes: fd-find installs as `fdfind`.
# Claude expects `fd`, so shim it into ~/.local/bin.
shim_debian_name() {
  want="$1"
  actual="$2"
  command -v "$want" >/dev/null && return 0
  command -v "$actual" >/dev/null || return 0
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$(command -v "$actual")" "$HOME/.local/bin/$want"
  echo "Shimmed $want -> $(command -v "$actual") at $HOME/.local/bin/$want"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) echo "  note: ~/.local/bin is not on PATH — add it so $want is found." ;;
  esac
}

install_tool() {
  cmd="$1"
  brew_pkg="$2"
  apt_pkg="$3"
  alt_cmd="${4:-}"

  if [ -n "$alt_cmd" ]; then
    shim_debian_name "$cmd" "$alt_cmd"
  fi

  if command -v "$cmd" >/dev/null; then
    echo "$brew_pkg already installed: $(command -v "$cmd")"
    return
  fi

  if [ "$PM" = none ]; then
    echo "$brew_pkg not installed and no supported package manager found — install it yourself."
    return
  fi

  if [ "$PM" = apt ] && [ "$apt_pkg" = "-" ]; then
    echo "$brew_pkg has no apt package — install it manually (see its GitHub releases)."
    return
  fi

  echo "Installing $brew_pkg..."
  if ! pm_install "$brew_pkg" "$apt_pkg"; then
    echo "  failed to install $brew_pkg — carrying on."
    return
  fi

  if [ -n "$alt_cmd" ]; then
    shim_debian_name "$cmd" "$alt_cmd"
  fi
}

if [ "$PM" = apt ]; then
  $SUDO apt-get update -qq
fi

install_tool rg ripgrep ripgrep
install_tool fd fd fd-find fdfind
install_tool jq jq jq
install_tool ast-grep ast-grep -
install_tool yq yq -

# The shell Claude Code uses is machine-specific, so it lives in the shell rc
# files rather than the synced settings.json.
detect_bash() {
  candidates="/opt/homebrew/bin/bash /usr/local/bin/bash /usr/bin/bash /bin/bash"
  if command -v brew >/dev/null; then
    candidates="$(brew --prefix)/bin/bash $candidates"
  fi

  for candidate in $candidates; do
    [ -x "$candidate" ] || continue
    major="$("$candidate" -c 'echo ${BASH_VERSINFO[0]}' 2>/dev/null || echo 0)"
    if [ "$major" -ge 4 ]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

if ! BASH_PATH="$(detect_bash)"; then
  if [ "$PM" != none ]; then
    echo "Installing bash..."
    pm_install bash bash
    BASH_PATH="$(detect_bash || true)"
  fi
fi

if [ -z "${BASH_PATH:-}" ]; then
  echo "WARNING: no bash 4+ found. Claude Code will keep using your login shell."
else
  echo "Claude shell: $BASH_PATH ($("$BASH_PATH" --version | head -1))"

  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [ -e "$rc" ] || continue
    tmp="$rc.dotclaude.tmp"
    awk '/^# >>> dotclaude >>>$/{skip=1} !skip{print} /^# <<< dotclaude <<<$/{skip=0}' "$rc" > "$tmp"
    {
      echo "# >>> dotclaude >>>"
      echo "alias claude=\"SHELL=$BASH_PATH claude\""
      echo "# <<< dotclaude <<<"
    } >> "$tmp"
    # Write through the symlink rather than replacing it — ~/.zshrc is often
    # a link into a dotfiles or prezto checkout.
    cat "$tmp" > "$rc"
    rm -f "$tmp"
    echo "Updated claude alias in $rc"
  done
fi
