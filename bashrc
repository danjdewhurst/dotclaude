# Minimal bash setup for Claude Code's shell.
# Interactive conveniences live in ~/.zshrc and deliberately aren't here.

if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Before mise, so the mise.run installer's binary is found on Linux.
export PATH="$HOME/.local/bin:$PATH"

export PATH="$HOME/.composer/vendor/bin:$PATH"
export PATH="$HOME/.bun/bin:$PATH"

if [ "$(uname -s)" = "Darwin" ]; then
  export PNPM_HOME="$HOME/Library/pnpm"
else
  export PNPM_HOME="$HOME/.local/share/pnpm"
fi
export PATH="$PNPM_HOME/bin:$PATH"

# After the PATH entries above so mise-managed runtimes win over anything a
# package manager dropped in ~/.bun or ~/Library/pnpm.
if command -v mise >/dev/null; then
  eval "$(mise activate bash)"
fi

if [ -f "$HOME/.orbstack/shell/init.bash" ]; then
  . "$HOME/.orbstack/shell/init.bash" >/dev/null
fi

# Redirected: a banner or deprecation notice from any of these would land at
# the top of every command's output.
for f in "$HOME/.local/bin/env" "$HOME/.cargo/env" "$HOME/.safe-chain/scripts/init-posix.sh"; do
  [ -f "$f" ] && . "$f" >/dev/null
done
unset f
