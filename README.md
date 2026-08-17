# dotclaude

My global Claude Code config, synced between machines via symlink:

- `CLAUDE.md` — global instructions
- `settings.json` — global settings

`~/.claude/CLAUDE.md` and `~/.claude/settings.json` are symlinks into this repo, so editing them in place edits the repo.

## Setup on a new machine

```bash
git clone git@github.com:danjdewhurst/dotclaude.git ~/dotclaude
~/dotclaude/install.sh
```

`install.sh` creates `~/.claude` if needed, backs up any existing file to `<name>.bak`, and creates the symlinks. It also installs ripgrep via Homebrew if `rg` isn't already on PATH. Re-running it is a no-op.

One thing to check per machine: `settings.json` sets `env.SHELL` to `/opt/homebrew/bin/bash`. On an Intel Mac that path is `/usr/local/bin/bash`, and on Linux `/usr/bin/bash`. If the configured path isn't executable the script tries `brew install bash`, then warns with the path bash actually has on that machine so you can correct the setting.

macOS ships bash 3.2.57 at `/bin/bash`, which is old enough to matter — the Homebrew build is 5.x.

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
