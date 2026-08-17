# dotclaude

My global Claude Code config, synced between machines via symlink:

- `CLAUDE.md` → `~/.claude/CLAUDE.md` — global instructions
- `settings.json` → `~/.claude/settings.json` — global settings
- `bashrc` → `~/.bashrc` — the shell Claude Code runs commands in

Each is a symlink into this repo, so editing the file in place edits the repo.

`bashrc` is deliberately minimal: Homebrew, mise, PATH, nothing interactive. Without it a fresh machine gives Claude a bare shell with no `node`, `php` or `rg`, since Homebrew on Apple Silicon needs `brew shellenv` to be on PATH at all. Interactive conveniences (zoxide, eza, completions) stay in `~/.zshrc`, which is not synced.

## Setup on a new machine

```bash
git clone git@github.com:danjdewhurst/dotclaude.git ~/dotclaude
~/dotclaude/install.sh
```

`install.sh` creates `~/.claude` if needed, backs up any existing file to `<name>.bak`, and symlinks the config. It then:

- **Installs the CLI tools Claude uses from Bash** — `git`, `rg`, `fd`, `jq`, `ast-grep`, `yq` — via Homebrew on macOS or apt on Debian/Ubuntu. `ast-grep` and `yq` have no apt package and are skipped there with a note. On Debian, `fd-find` installs its binary as `fdfind`, so the script shims `~/.local/bin/fd` to point at it.
- **Points Claude Code at bash.** The bash path is machine-specific, so it is deliberately *not* in the synced `settings.json`. Instead the script finds the newest bash 4+ on the machine and writes a marked block into `~/.zshrc` and `~/.bashrc`:

  ```bash
  # >>> dotclaude >>>
  alias claude="SHELL=/opt/homebrew/bin/bash claude"
  # <<< dotclaude <<<
  ```

  The block goes in `~/.zshrc` and `~/.bash_profile` — the shells you launch `claude` from — never in the synced `~/.bashrc`. Re-running rewrites that block in place instead of appending a second one, and writes *through* a symlinked rc file rather than replacing the link.

macOS ships bash 3.2.57 at `/bin/bash`, so Homebrew's 5.x is preferred where present.

Re-running the whole script is a no-op.

## Day to day

Push a change:

```bash
git -C ~/dotclaude commit -am "tweak"
git -C ~/dotclaude push
```

Pull on another machine:

```bash
git -C ~/dotclaude pull
```

No restart needed — Claude Code reads `CLAUDE.md` at session start.

## Not synced

`skills/` and everything else under `~/.claude` stay machine-local.
