# Minimal bash setup for Claude Code's shell.
# Interactive conveniences live in ~/.zshrc and deliberately aren't here.

if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

if command -v mise >/dev/null; then
  eval "$(mise activate bash)"
fi

if [ -f "$HOME/.orbstack/shell/init.bash" ]; then
  . "$HOME/.orbstack/shell/init.bash"
fi

export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.composer/vendor/bin:$PATH"
export PATH="$HOME/.bun/bin:$PATH"

if [ "$(uname -s)" = "Darwin" ]; then
  export PNPM_HOME="$HOME/Library/pnpm"
else
  export PNPM_HOME="$HOME/.local/share/pnpm"
fi
export PATH="$PNPM_HOME/bin:$PATH"

for f in "$HOME/.local/bin/env" "$HOME/.cargo/env" "$HOME/.safe-chain/scripts/init-posix.sh"; do
  [ -f "$f" ] && . "$f"
done
unset f
