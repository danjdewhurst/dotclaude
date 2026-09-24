# shellcheck shell=bash
# Minimal bash setup for Claude Code's shell.
# Interactive conveniences live in ~/.zshrc and deliberately aren't here.

if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -x "$HOME/.linuxbrew/bin/brew" ]; then
  eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
fi

# Prepend only if absent, so re-sourcing in a nested shell doesn't grow PATH.
_dotclaude_prepend_path() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$1:$PATH" ;;
  esac
}

# Before mise, so the mise.run installer's binary is found on Linux.
_dotclaude_prepend_path "$HOME/.local/bin"

_dotclaude_prepend_path "$HOME/.composer/vendor/bin"
_dotclaude_prepend_path "$HOME/.bun/bin"

case "$OSTYPE" in
  darwin*) export PNPM_HOME="$HOME/Library/pnpm" ;;
  *) export PNPM_HOME="$HOME/.local/share/pnpm" ;;
esac
_dotclaude_prepend_path "$PNPM_HOME/bin"

# After the PATH entries above so mise-managed runtimes win over anything a
# package manager dropped in ~/.bun or ~/Library/pnpm. Shims rather than the
# default activation: that one installs a `mise` shell function and a
# PROMPT_COMMAND hook, neither of which survives into a non-interactive shell.
# Redirected because mise writes update notices to stderr.
if command -v mise >/dev/null; then
  eval "$(mise activate bash --shims 2>/dev/null)"
fi

if [ -f "$HOME/.orbstack/shell/init.bash" ]; then
  . "$HOME/.orbstack/shell/init.bash" >/dev/null 2>&1
fi

# Redirected: a banner or deprecation notice from any of these would land at
# the top of every command's output.
for _dotclaude_f in "$HOME/.local/bin/env" "$HOME/.cargo/env" "$HOME/.safe-chain/scripts/init-posix.sh"; do
  [ -f "$_dotclaude_f" ] && . "$_dotclaude_f" >/dev/null 2>&1
done
unset _dotclaude_f
unset -f _dotclaude_prepend_path

# Machine-local additions, not tracked here. An if rather than a && so the file
# being absent doesn't leave this rc returning 1 to whatever sourced it.
if [ -f "$HOME/.bashrc.local" ]; then
  . "$HOME/.bashrc.local"
fi

# opencode
export PATH=/home/dan/.opencode/bin:$PATH

# --- prompt ---------------------------------------------------------------
__prompt() {
  local status=$?
  local reset='\[\e[0m\]' dim='\[\e[2m\]' blue='\[\e[34m\]' green='\[\e[32m\]'
  local red='\[\e[31m\]' yellow='\[\e[33m\]' magenta='\[\e[35m\]'

  local git="" branch
  if branch=$(git symbolic-ref --short -q HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null); then
    local flags=""
    [[ -n $(git status --porcelain 2>/dev/null | head -n1) ]] && flags+="*"
    local counts
    if counts=$(git rev-list --left-right --count '@{u}...HEAD' 2>/dev/null); then
      local behind=${counts%%[[:space:]]*} ahead=${counts##*[[:space:]]}
      (( ahead ))  && flags+=" ↑$ahead"
      (( behind )) && flags+=" ↓$behind"
    fi
    git=" ${magenta}${branch}${yellow}${flags}${reset}"
  fi

  local arrow="${green}❯${reset}"
  (( status )) && arrow="${red}❯${reset}"

  PS1="${dim}\u@\h${reset} ${blue}\w${reset}${git}\n${arrow} "
}
PROMPT_COMMAND=__prompt
