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

`install.sh` creates `~/.claude` if needed, backs up any existing file to `<name>.bak`, and creates the symlinks. Re-running it is a no-op.

One thing to check per machine: `settings.json` sets `env.SHELL` to `/opt/homebrew/bin/bash`. On an Intel Mac that path is `/usr/local/bin/bash`, and on Linux `/usr/bin/bash`. The script warns if the configured path isn't executable and tells you where bash actually lives — it doesn't install anything.

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
