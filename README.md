# dotclaude

My global Claude Code instructions (`CLAUDE.md`), synced between machines via symlink.

`~/.claude/CLAUDE.md` is a symlink into this repo, so editing it in place edits the repo.

## Setup on a new machine

```bash
git clone git@github.com:danjdewhurst/dotclaude.git ~/dotclaude
~/dotclaude/install.sh
```

`install.sh` creates `~/.claude` if needed, backs up any existing `CLAUDE.md` to `CLAUDE.md.bak`, and creates the symlink. Re-running it is a no-op.

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

`~/.claude/settings.json`, `skills/`, and everything else under `~/.claude` stay machine-local.
