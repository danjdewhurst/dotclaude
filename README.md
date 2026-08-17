# dotclaude

My global [Claude Code](https://claude.com/claude-code) config, kept in one place so a new machine takes two commands instead of an afternoon of remembering.

Three files are symlinked out of this repo into `$HOME`. Editing them in place edits the repo, so there is no copy step and nothing to forget to commit.

| Repo file | Links to | What it is |
|---|---|---|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | How I want Claude to work: scope, code style, how to communicate |
| `settings.json` | `~/.claude/settings.json` | Model, effort level, notification channel |
| `bashrc` | `~/.bashrc` | The shell Claude runs commands in |

## Setup on a new machine

```bash
git clone git@github.com:danjdewhurst/dotclaude.git ~/dotclaude
~/dotclaude/install.sh
```

That creates `~/.claude` if it's missing, backs up anything already at those paths to `<name>.bak`, and links the three files. Then it installs the CLI tools Claude leans on from Bash: `git`, `rg`, `fd` and `jq` through Homebrew or apt, and `mise`, which in turn supplies `ast-grep` and `yq` on any platform.

Run it as many times as you like. Everything it does is idempotent.

Tested on macOS 26 (Apple Silicon) and Ubuntu 24.04.

## Why there's a bashrc in here

Claude Code runs its Bash tool in your login shell. Mine is zsh, and feeding zsh to something expecting bash produces a screen of `autoload: command not found` and prezto refusing to load. So Claude gets bash instead, and bash needs its own config.

`bashrc` is deliberately dull: Homebrew, mise, PATH, nothing interactive. No aliases, no zoxide, no completions. Those belong in `~/.zshrc`, which is not synced, because they only matter when a human is typing.

It is not optional. Homebrew on Apple Silicon lives at `/opt/homebrew/bin`, which is not on the default PATH, so without `brew shellenv` a fresh machine hands Claude a shell with no `node`, no `php`, no `rg`, and no clue why.

## Why the bash path isn't in settings.json

Because it's different on every machine. Homebrew puts bash at `/opt/homebrew/bin/bash` on Apple Silicon and `/usr/local/bin/bash` on Intel, Linux uses `/usr/bin/bash`, and macOS still ships bash 3.2.57 at `/bin/bash`. One synced file cannot hold all four.

So `install.sh` finds the newest bash 4+ on the machine and writes a marked block into `~/.zshrc` and `~/.bash_profile`:

```bash
# >>> dotclaude >>>
alias claude="SHELL=/opt/homebrew/bin/bash claude"
# <<< dotclaude <<<
```

Those are the shells you launch `claude` from, never the synced `~/.bashrc`. Re-running rewrites the block in place rather than stacking a second copy, and it writes *through* a symlinked rc file instead of replacing the symlink, which matters if your `~/.zshrc` points into prezto or another dotfiles checkout.

## Day to day

Edit `~/.claude/CLAUDE.md` as normal, then:

```bash
git -C ~/dotclaude commit -am "tweak the debug-spiral rule"
git -C ~/dotclaude push
```

On the other machine, `git -C ~/dotclaude pull`. Claude reads `CLAUDE.md` at session start, so the next session picks it up with no restart dance.

## Not synced

`skills/`, `projects/`, and everything else under `~/.claude` stay machine-local. So does `~/.zshrc`.

## Known rough edges

Neither `ast-grep` nor `yq` is packaged for apt, so they come from mise instead, which carries both in its registry and works the same on macOS and Linux. On macOS, where Homebrew already has them, mise stays out of the way. Debian also ships `fd-find` with its binary named `fdfind`, so the script drops an `fd` symlink in `~/.local/bin` to match what Claude expects.

On a machine without Homebrew the script installs mise with `curl https://mise.run | sh`, which is the vendor's documented method but is still piping a remote script into a shell. Swap it for [their apt repo](https://mise.jdx.dev/installing-mise.html) if that bothers you.

## If you found this

It's my config, not a template. `CLAUDE.md` is written in first person about how I want to be worked with, and `bashrc` assumes my toolchain. Fork it and rewrite both rather than copying them and wondering why Claude keeps mentioning mise.

MIT licensed. Take whatever's useful.
