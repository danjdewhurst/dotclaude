#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Which agents get the config. agents.conf ships the defaults; a machine adds
# its own or redefines the list in ~/.dotclaude.local, sourced second so it
# wins and never committed here.
. "$REPO/agents.conf"
if [ -f "$HOME/.dotclaude.local" ]; then
  . "$HOME/.dotclaude.local"
fi

# repo file -> where it goes
LINKS=(
  "bashrc:$HOME/.bashrc"
)

AGENT_SKILL_DIRS=()
for entry in ${AGENT_DIRS[@]+"${AGENT_DIRS[@]}"}; do
  case "$entry" in
    *:*) ;;
    *)
      echo "WARNING: AGENT_DIRS entry '$entry' is not <dir>:<filename> — skipped." >&2
      continue
      ;;
  esac
  dir="${entry%:*}"
  name="${entry##*:}"

  if [ -e "$dir" ] && [ ! -d "$dir" ]; then
    echo "ERROR: $dir exists but is not a directory. Move it aside and re-run." >&2
    exit 1
  fi
  mkdir -p "$dir"

  LINKS+=("CLAUDE.md:$dir/$name")
  LINKS+=("unslop.md:$dir/unslop.md")
  AGENT_SKILL_DIRS+=("$dir/skills")
done

# Migration: settings.json used to be symlinked out of this repo. It is now a
# real per-machine file, so a machine set up before that change is left with a
# link to a path git has since deleted. Materialise it -- from the repo file if
# it is still there, from the last commit that carried it otherwise -- so the
# machine keeps running the settings it already had.
migrate_settings() {
  target="$HOME/.claude/settings.json"

  [ -L "$target" ] || return 0
  case "$(readlink "$target")" in
    "$REPO"/settings.json) ;;
    *)
      # A link into a checkout that has since moved. Left in place, the jq write
      # below would follow it and resurrect settings.json in the old checkout.
      if [ ! -e "$target" ]; then
        rm -f "$target"
        echo "Removed a dangling settings.json symlink. Claude Code will write a fresh one."
      fi
      return 0
      ;;
  esac

  if [ -e "$target" ]; then
    content="$(cat "$target")"
  else
    deleted="$(git -C "$REPO" log --diff-filter=D -1 --format=%H -- settings.json 2>/dev/null || true)"
    if [ -z "$deleted" ] || ! content="$(git -C "$REPO" show "$deleted^:settings.json" 2>/dev/null)"; then
      rm -f "$target"
      echo "Removed a dangling settings.json symlink. Claude Code will write a fresh one."
      return 0
    fi
  fi

  rm -f "$target"
  printf '%s\n' "$content" > "$target"
  echo "settings.json is no longer synced from the repo -- kept your copy at $target"
}

migrate_settings

# Move whatever is on this path out of the way, never clobbering an older
# backup. Symlinks included: mv moves the link itself, so the user keeps it.
preserve() {
  target="$1"

  backup="$target.bak"
  if [ -e "$backup" ] || [ -L "$backup" ]; then
    backup="$target.bak.$(date +%Y%m%d%H%M%S)"
  fi
  mv "$target" "$backup"
  echo "Backed up $(basename "$target") to $backup"
}

for entry in "${LINKS[@]}"; do
  src="$REPO/${entry%%:*}"
  target="${entry#*:}"

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
    echo "Already linked: $target"
    continue
  fi

  if [ -e "$target" ] || [ -L "$target" ]; then
    preserve "$target"
  fi

  ln -sfn "$src" "$target"
  echo "Linked $target -> $src"
done

# Skills. The content lives in this repo; ~/.claude/skills is what Claude
# reads, and ~/.agents/skills is the shared directory other agents look in.
# Each skill is a direct symlink into the repo, so a pull updates it.
link_skills() {
  dest="$1"
  mkdir -p "$dest"

  for src in "$REPO"/skills/*/; do
    src="${src%/}"
    [ -d "$src" ] || continue
    name="$(basename "$src")"

    link="$dest/$name"
    if [ -L "$link" ] && [ "$(readlink "$link")" = "$src" ]; then
      echo "Already linked: $link"
      continue
    fi

    # Skills used to route ~/.claude through ~/.agents; a link of that shape is
    # ours to replace. A real directory with identical content is redundant and
    # gets removed; anything else is backed up, so local edits to a skill are
    # never silently thrown away.
    if [ -L "$link" ] && [ "$(readlink "$link")" = "../../.agents/skills/$name" ]; then
      rm -f "$link"
    elif [ -d "$link" ] && [ ! -L "$link" ] && diff -rq "$src" "$link" >/dev/null 2>&1; then
      rm -rf "$link"
    elif [ -e "$link" ] || [ -L "$link" ]; then
      preserve "$link"
    fi
    ln -sfn "$src" "$link"
    echo "Linked $link -> $src"
  done

  # Prune the links this script made for skills the repo no longer carries. A
  # pull that drops one would otherwise leave a dangling link behind for good.
  # Only broken links shaped like the ones we make (any checkout, not just the
  # current $REPO: a link made before the repo moved is broken the same way)
  # are touched; anything else on this path belongs to the user.
  for link in "$dest"/*; do
    [ -L "$link" ] && [ ! -e "$link" ] || continue
    case "$(readlink "$link")" in
      */skills/"${link##*/}")
        rm -f "$link"
        echo "Pruned $link — no longer in the repo"
        ;;
    esac
  done
}

if [ -d "$REPO/skills" ]; then
  for dest in ${AGENT_SKILL_DIRS[@]+"${AGENT_SKILL_DIRS[@]}"}; do
    link_skills "$dest"
  done
fi
lock="$HOME/.agents/.skill-lock.json"
if [ -L "$lock" ]; then
  case "$(readlink "$lock")" in
    */skill-lock.json)
      if [ "$(readlink "$lock")" = "$REPO/skill-lock.json" ] || [ ! -e "$lock" ]; then
        rm -f "$lock"
        echo "Removed $lock — the repo no longer carries a skill lock"
      fi
      ;;
  esac
fi

# Package manager detection: brew, then the common Linux families.
SUDO=""
APT_UPDATED=""
if command -v brew >/dev/null; then
  PM=brew
elif command -v apt-get >/dev/null; then
  PM=apt
elif command -v dnf >/dev/null; then
  PM=dnf
elif command -v pacman >/dev/null; then
  PM=pacman
else
  PM=none
fi

if [ "$PM" != brew ] && [ "$PM" != none ] && [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null; then
    SUDO="sudo"
  else
    echo "Not root and sudo is unavailable — skipping package installs."
    PM=none
  fi
fi

# Package names differ per distro.
pkg_name() {
  case "$1:$PM" in
    fd:apt)       echo "fd-find" ;;
    fd:dnf)       echo "fd-find" ;;
    ripgrep:*)    echo "ripgrep" ;;
    *)            echo "$1" ;;
  esac
}

pm_install() {
  pkg="$(pkg_name "$1")"
  case "$PM" in
    brew)   brew install "$pkg" ;;
    apt)
      # Without this a fresh machine has no package lists and every install fails.
      if [ -z "$APT_UPDATED" ]; then
        $SUDO apt-get update -qq || echo "  apt-get update failed — carrying on."
        APT_UPDATED=1
      fi
      $SUDO apt-get install -y -qq "$pkg"
      ;;
    dnf)    $SUDO dnf install -y -q "$pkg" ;;
    pacman) $SUDO pacman -S --noconfirm --needed "$pkg" ;;
    *)      return 2 ;;
  esac
}

# Debian renames fd to avoid a clash and ships the binary as `fdfind` (the
# package is fd-find on both Debian and Fedora). Claude expects `fd`, so shim it
# into ~/.local/bin and make sure the rest of this script can see it.
shim_debian_name() {
  want="$1"
  actual="$2"
  command -v "$want" >/dev/null && return 0
  command -v "$actual" >/dev/null || return 0

  actual_path="$(command -v "$actual")"
  mkdir -p "$HOME/.local/bin"
  shim="$HOME/.local/bin/$want"
  # A real file here is the user's own binary, invisible only because
  # ~/.local/bin is not on PATH yet.
  if [ -e "$shim" ] && [ ! -L "$shim" ]; then
    echo "WARNING: $shim exists and is not a symlink — left alone, no $want shim." >&2
  elif [ "$(readlink "$shim" 2>/dev/null)" != "$actual_path" ]; then
    ln -sfn "$actual_path" "$shim"
    echo "Shimmed $want -> $actual_path at $shim"
  fi
  PATH="$HOME/.local/bin:$PATH"
  export PATH
}

install_tool() {
  cmd="$1"
  pkg="$2"
  alt_cmd="${3:-}"

  if [ -n "$alt_cmd" ]; then
    shim_debian_name "$cmd" "$alt_cmd"
  fi

  if command -v "$cmd" >/dev/null; then
    echo "$pkg already installed: $(command -v "$cmd")"
    return
  fi

  if [ "$PM" = none ]; then
    echo "$pkg not installed and no supported package manager found — install it yourself."
    return
  fi

  echo "Installing $pkg..."
  if ! pm_install "$pkg"; then
    echo "  could not install $pkg — carrying on."
    return
  fi

  if [ -n "$alt_cmd" ]; then
    shim_debian_name "$cmd" "$alt_cmd"
  fi
}

install_tool git git
install_tool rg ripgrep
install_tool fd fd fdfind
install_tool jq jq

# mise manages language runtimes, and installs the tools no distro packages.
if ! command -v mise >/dev/null; then
  if [ "$PM" = brew ]; then
    echo "Installing mise..."
    brew install mise || echo "  could not install mise — carrying on."
  elif command -v curl >/dev/null; then
    echo "Installing mise from mise.run..."
    curl -fsSL https://mise.run | sh || echo "  could not install mise — carrying on."
  else
    echo "mise not installed and curl is unavailable — install it yourself."
  fi
fi

MISE=""
if command -v mise >/dev/null; then
  MISE="$(command -v mise)"
elif [ -x "$HOME/.local/bin/mise" ]; then
  MISE="$HOME/.local/bin/mise"
fi

# ast-grep and yq: package manager first where it has them, mise otherwise.
install_portable_tool() {
  cmd="$1"

  if command -v "$cmd" >/dev/null; then
    echo "$cmd already installed: $(command -v "$cmd")"
    return
  fi

  # mise-installed tools aren't on this shell's PATH, so ask mise directly
  # rather than reinstalling them on every run.
  if [ -n "$MISE" ] && "$MISE" which "$cmd" >/dev/null 2>&1; then
    echo "$cmd already installed: $("$MISE" which "$cmd")"
    return
  fi

  if [ "$PM" = brew ]; then
    echo "Installing $cmd..."
    if brew install "$cmd"; then
      return
    fi
    echo "  brew could not install $cmd, trying mise..."
  fi

  if [ -z "$MISE" ]; then
    echo "$cmd not installed and mise is unavailable — install it yourself."
    return
  fi

  echo "Installing $cmd via mise..."
  "$MISE" use -g -y "$cmd@latest" || echo "  could not install $cmd — carrying on."
}

install_portable_tool ast-grep
install_portable_tool yq

# Claude Code takes the Bash tool's shell from env.CLAUDE_CODE_SHELL in
# settings.json, which write_shell_setting below owns. The rc alias sets $SHELL
# for the claude command as the fallback for a machine with no jq, a broken
# settings.json, or a CLI old enough to predate the setting. The bash path
# differs per machine, so neither is synced from this repo.
bash_version_key() {
  "$1" -c 'printf "%s%03d\n" "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}"' 2>/dev/null || true
}

detect_bash() {
  candidates=(/opt/homebrew/bin/bash /usr/local/bin/bash /usr/bin/bash /bin/bash)
  if command -v brew >/dev/null; then
    candidates=("$(brew --prefix)/bin/bash" "${candidates[@]}")
  fi

  best=""
  best_key=0
  for candidate in "${candidates[@]}"; do
    [ -x "$candidate" ] || continue
    key="$(bash_version_key "$candidate")"
    case "$key" in
      ''|*[!0-9]*) continue ;;
    esac
    [ "$key" -lt 4000 ] && continue
    if [ "$key" -gt "$best_key" ]; then
      best_key="$key"
      best="$candidate"
    fi
  done

  [ -n "$best" ] || return 1
  echo "$best"
}

if ! BASH_PATH="$(detect_bash)"; then
  if [ "$PM" != none ]; then
    echo "Installing bash..."
    pm_install bash || echo "  could not install bash — carrying on."
    BASH_PATH="$(detect_bash || true)"
  fi
fi

MARK_START="# >>> dotclaude >>>"
MARK_END="# <<< dotclaude <<<"

# Rewrite our marked block in $1, leaving the rest of the file alone. Refuses
# to touch a file whose markers are damaged rather than risk eating content.
write_block() {
  rc="$1"

  link="$(readlink "$rc" 2>/dev/null || true)"
  case "$link" in
    "") link="$rc" ;;
    /*) ;;
    # A relative link into the repo has to be resolved against the file's own
    # directory, or it does not look like a repo path at all.
    *)  link="$(cd "$(dirname "$rc")/$(dirname "$link")" && pwd)/$(basename "$link")" ;;
  esac
  case "$link" in
    "$REPO"/*)
      echo "Skipping $rc — it is synced from the repo."
      return
      ;;
  esac

  starts="$(grep -c "^${MARK_START}[[:space:]]*$" "$rc" || true)"
  ends="$(grep -c "^${MARK_END}[[:space:]]*$" "$rc" || true)"

  damage=""
  if [ "$starts" != "$ends" ] || [ "$starts" -gt 1 ]; then
    damage="$starts start, $ends end"
  elif [ "$starts" = "1" ]; then
    # An end marker above the start passes the count check, and the rewrite
    # below would then delete everything from the start marker to the end of
    # the file.
    start_line="$(grep -n "^${MARK_START}[[:space:]]*$" "$rc" | cut -d: -f1)"
    end_line="$(grep -n "^${MARK_END}[[:space:]]*$" "$rc" | cut -d: -f1)"
    [ "$start_line" -lt "$end_line" ] || damage="end marker above start marker"
  fi

  if [ -n "$damage" ]; then
    echo "WARNING: $rc has damaged dotclaude markers ($damage)." >&2
    echo "  Left untouched. Fix the markers by hand, or delete the block, then re-run." >&2
    return
  fi

  comment="# Point Claude Code's Bash tool at bash instead of the login shell."
  alias_line="alias claude=\"SHELL='$BASH_PATH' claude\""

  # Rewrite the block where it already sits. Stripping and re-appending would
  # move it to the end of the file and reorder whatever the user has after it.
  tmp="$rc.dotclaude.tmp"
  if [ "$starts" = "1" ]; then
    awk -v s="^${MARK_START}[[:space:]]*$" -v e="^${MARK_END}[[:space:]]*$" \
      -v l1="$MARK_START" -v l2="$comment" -v l3="$alias_line" -v l4="$MARK_END" \
      '$0 ~ s {print l1; print l2; print l3; print l4; skip=1; next}
       $0 ~ e {skip=0; next}
       !skip {print}' "$rc" > "$tmp"
  else
    {
      cat "$rc"
      # A file with no trailing newline would glue the marker onto its last line.
      if [ -s "$rc" ] && [ -n "$(tail -c1 "$rc")" ]; then
        echo
      fi
      echo "$MARK_START"
      echo "$comment"
      echo "$alias_line"
      echo "$MARK_END"
    } > "$tmp"
  fi

  if cmp -s "$tmp" "$rc"; then
    rm -f "$tmp"
    echo "Already current: claude alias in $rc"
    return
  fi

  # Before the first modification, so the backup is of the file as it was.
  [ -e "$rc.dotclaude.bak" ] || cp "$rc" "$rc.dotclaude.bak"

  # Write through the symlink rather than replacing it — ~/.zshrc is often a
  # link into a dotfiles or prezto checkout.
  cat "$tmp" > "$rc"
  rm -f "$tmp"
  echo "Updated claude alias in $rc"
}

# Claude Code reads the Bash tool's shell from env.CLAUDE_CODE_SHELL in
# settings.json. That file is per-machine, so the installer merges the one key
# it owns and leaves everything else in there alone.
write_shell_setting() {
  settings="$HOME/.claude/settings.json"
  # ~/.claude usually exists from the linking above, but the agents config can
  # drop the claude entry and this write must still land.
  mkdir -p "$HOME/.claude"

  if ! command -v jq >/dev/null; then
    echo "WARNING: jq is unavailable, so $settings was left alone." >&2
    echo "  Add by hand: \"env\": { \"CLAUDE_CODE_SHELL\": \"$BASH_PATH\" }" >&2
    return
  fi

  if [ ! -e "$settings" ]; then
    jq -n --arg shell "$BASH_PATH" '{env: {CLAUDE_CODE_SHELL: $shell}}' > "$settings"
    echo "Created $settings with CLAUDE_CODE_SHELL=$BASH_PATH"
    return
  fi

  if ! jq -e . "$settings" >/dev/null 2>&1; then
    echo "WARNING: $settings is not valid JSON. Left untouched." >&2
    echo "  Fix it and re-run, or add: \"env\": { \"CLAUDE_CODE_SHELL\": \"$BASH_PATH\" }" >&2
    return
  fi

  if [ "$(jq -r '.env.CLAUDE_CODE_SHELL // empty' "$settings")" = "$BASH_PATH" ]; then
    echo "Already current: CLAUDE_CODE_SHELL in $settings"
    return
  fi

  tmp="$settings.dotclaude.tmp"
  jq --arg shell "$BASH_PATH" '.env.CLAUDE_CODE_SHELL = $shell' "$settings" > "$tmp"

  [ -e "$settings.dotclaude.bak" ] || cp "$settings" "$settings.dotclaude.bak"

  # Write through the file rather than replacing it, so a settings.json someone
  # has symlinked out of their own dotfiles keeps its link.
  cat "$tmp" > "$settings"
  rm -f "$tmp"
  echo "Set CLAUDE_CODE_SHELL=$BASH_PATH in $settings"
}

# The unslop SessionStart hook is gone. CLAUDE.md points at unslop.md, so the
# agent reads the file. A machine set up before that still has the hook in
# settings.json. Strip it so it does not keep injecting a second copy.
remove_unslop_hook() {
  settings="$HOME/.claude/settings.json"

  [ -e "$settings" ] || return 0

  if ! command -v jq >/dev/null; then
    echo "WARNING: jq is unavailable, so the unslop hook was left in $settings." >&2
    echo "  Delete the SessionStart command that reads unslop.md or unslop/SKILL.md." >&2
    return
  fi

  if ! jq -e . "$settings" >/dev/null 2>&1; then
    echo "WARNING: $settings is not valid JSON, so the unslop hook was left in place." >&2
    return
  fi

  tmp="$settings.dotclaude.tmp"
  if ! jq '
    .hooks.SessionStart = [(.hooks.SessionStart? // [])[] | .hooks |= map(select((.command? // "" | tostring | test("unslop(\\.md|/SKILL\\.md)")) | not)) | select(.hooks | length > 0)]
    | if (.hooks.SessionStart? // []) == [] then del(.hooks.SessionStart) else . end
    | if .hooks == {} then del(.hooks) else . end
  ' "$settings" > "$tmp"; then
    rm -f "$tmp"
    echo "WARNING: could not remove the unslop hook from $settings. Left untouched." >&2
    return
  fi

  if cmp -s "$tmp" "$settings"; then
    rm -f "$tmp"
    echo "Already current: no unslop hook in $settings"
    return
  fi

  [ -e "$settings.dotclaude.bak" ] || cp "$settings" "$settings.dotclaude.bak"

  cat "$tmp" > "$settings"
  rm -f "$tmp"
  echo "Removed the unslop SessionStart hook from $settings"
}

remove_unslop_hook

# Auto memory stays off everywhere. settings.json is per-machine, so like the
# keys above this one is merged rather than synced.
write_memory_setting() {
  settings="$HOME/.claude/settings.json"
  mkdir -p "$HOME/.claude"

  if ! command -v jq >/dev/null; then
    echo "WARNING: jq is unavailable, so $settings was left alone." >&2
    echo "  Add by hand: \"autoMemoryEnabled\": false" >&2
    return
  fi

  if [ ! -e "$settings" ]; then
    jq -n '{autoMemoryEnabled: false}' > "$settings"
    echo "Created $settings with autoMemoryEnabled=false"
    return
  fi

  if ! jq -e . "$settings" >/dev/null 2>&1; then
    echo "WARNING: $settings is not valid JSON. Left untouched." >&2
    echo "  Fix it and re-run, or add: \"autoMemoryEnabled\": false" >&2
    return
  fi

  # Not `// empty` — jq's // treats false itself as absent.
  if jq -e '.autoMemoryEnabled == false' "$settings" >/dev/null; then
    echo "Already current: autoMemoryEnabled in $settings"
    return
  fi

  tmp="$settings.dotclaude.tmp"
  jq '.autoMemoryEnabled = false' "$settings" > "$tmp"

  [ -e "$settings.dotclaude.bak" ] || cp "$settings" "$settings.dotclaude.bak"

  # Through the file, not over it, same as the shell setting.
  cat "$tmp" > "$settings"
  rm -f "$tmp"
  echo "Set autoMemoryEnabled=false in $settings"
}

write_memory_setting

if [ -z "${BASH_PATH:-}" ]; then
  echo "WARNING: no bash 4+ found. Claude Code will keep using your login shell."
else
  echo "Claude shell: $BASH_PATH ($("$BASH_PATH" --version | sed -n 1p))"

  write_shell_setting

  login_shell="$(basename "${SHELL:-}")"

  if [ "$login_shell" = "fish" ]; then
    echo "WARNING: your login shell is fish, which cannot parse the alias this script writes."
    echo "  Add this to ~/.config/fish/config.fish by hand:"
    echo "    alias claude \"SHELL='$BASH_PATH' claude\""
  fi

  # zsh is the macOS default and a fresh machine has no ~/.zshrc at all, so
  # create it rather than silently skipping the shell the user actually uses.
  if [ "$login_shell" = "zsh" ] && [ ! -e "$HOME/.zshrc" ]; then
    : > "$HOME/.zshrc"
    echo "Created $HOME/.zshrc"
  fi

  # Prefer an existing login-shell file over creating ~/.bash_profile, which
  # would shadow ~/.profile and silently disable everything in it.
  bash_login_rc=""
  for candidate in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
    if [ -e "$candidate" ]; then
      bash_login_rc="$candidate"
      break
    fi
  done
  if [ -z "$bash_login_rc" ]; then
    bash_login_rc="$HOME/.bash_profile"
    echo '[ -f ~/.bashrc ] && . ~/.bashrc' > "$bash_login_rc"
    echo "Created $bash_login_rc"
  fi

  for rc in "$HOME/.zshrc" "$bash_login_rc"; do
    [ -e "$rc" ] || continue
    write_block "$rc"
  done

  echo
  echo "Note: settings.json is what points Claude Code's Bash tool at $BASH_PATH."
  echo "The alias is only a fallback, and it covers login shells alone — a"
  echo "non-login shell, a script or cron gets it from settings.json or not at all."
fi
