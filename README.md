# dotclaude

```
██████╗  ██████╗ ████████╗ ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗
██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝
██║  ██║██║   ██║   ██║   ██║     ██║     ███████║██║   ██║██║  ██║█████╗
██║  ██║██║   ██║   ██║   ██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝
██████╔╝╚██████╔╝   ██║   ╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗
╚═════╝  ╚═════╝    ╚═╝    ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝
```

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)](#setup-on-a-new-machine)
[![Shell: bash](https://img.shields.io/badge/shell-bash-4EAA25.svg)](#why-theres-a-bashrc-in-here)

My global [Claude Code](https://claude.com/claude-code) config, kept in one place so a new machine takes two commands instead of an afternoon of remembering.

Three files are symlinked out of this repo into `$HOME`. Editing them in place edits the repo, so there is no copy step and nothing to forget to commit.

```text
~/dotclaude/                            ~/
├── CLAUDE.md ─────────────────────────▶ .claude/CLAUDE.md
├── settings.json ─────────────────────▶ .claude/settings.json
├── bashrc ────────────────────────────▶ .bashrc
├── install.sh
├── README.md
└── LICENSE
```

| Repo file | What it is |
|---|---|
| `CLAUDE.md` | How I want Claude to work: scope, code style, how to communicate |
| `settings.json` | Model, effort level, notification channel |
| `bashrc` | The shell Claude runs commands in |

## Setup on a new machine

```bash
git clone git@github.com:danjdewhurst/dotclaude.git ~/dotclaude
~/dotclaude/install.sh
```

That creates `~/.claude` if it's missing, backs up anything already at those paths to `<name>.bak`, and links the three files. Then it installs the tools Claude leans on from Bash:

| Tool | What Claude uses it for | macOS | Linux |
|---|---|---|---|
| `git` | Everything | Homebrew | apt |
| `rg` | Searching code without drowning in dependencies | Homebrew | apt |
| `fd` | Finding files | Homebrew | apt |
| `jq` | Reading JSON | Homebrew | apt |
| `mise` | Language runtimes, plus the two below | Homebrew | mise.run |
| `ast-grep` | Structural search by syntax rather than regex | Homebrew | mise |
| `yq` | Reading YAML | Homebrew | mise |

Run it as many times as you like. Everything it does is idempotent.

> Tested on macOS 26 (Apple Silicon) and Ubuntu 24.04.

## Why there's a bashrc in here

Claude Code runs its Bash tool in whatever your `$SHELL` says, which for me is zsh. That works, but I'd rather the tool that runs commands on my behalf used bash: it's what the commands Claude writes assume, and it keeps its environment separate from the one I've spent years customising for typing.

Switching means bash needs config of its own, and the obvious shortcut is a trap. My first attempt was one line, `source ~/.zshrc` from `~/.bashrc`, which hands zsh syntax to bash and produces about sixty lines of `autoload: command not found`, prezto refusing to load with `old shell detected`, and mise's hooks failing on `$+functions[...]`. Worse, a stray `echo` in that file printed into the top of every command's output.

Hence a real `bashrc` here rather than a redirect to the zsh one.

`bashrc` is deliberately dull: Homebrew, mise, PATH, nothing interactive. No aliases, no zoxide, no completions. Those belong in `~/.zshrc`, which is not synced, because they only matter when a human is typing.

> **It is not optional.** Homebrew on Apple Silicon lives at `/opt/homebrew/bin`, which is not on the default PATH. Without `brew shellenv` a fresh machine hands Claude a shell with no `node`, no `php`, no `rg`, and no clue why.

## Why the bash path isn't in settings.json

Claude Code takes the shell from `$SHELL`, so pointing it at bash is a matter of setting that variable when you launch it. The path, though, is different on every machine:

| Machine | bash lives at |
|---|---|
| macOS, Apple Silicon | `/opt/homebrew/bin/bash` |
| macOS, Intel | `/usr/local/bin/bash` |
| Linux | `/usr/bin/bash` |
| macOS, preinstalled | `/bin/bash` — still 3.2.57, avoid |

One synced file cannot hold all four. So `install.sh` finds the newest bash 4+ on the machine and writes a marked block into `~/.zshrc` and `~/.bash_profile`:

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

On a machine without Homebrew the script installs mise with `curl https://mise.run | sh`. That's the vendor's documented method, but it is still piping a remote script into a shell. Swap it for [their apt repo](https://mise.jdx.dev/installing-mise.html) if that bothers you.

## If you found this

It's my config, not a template. `CLAUDE.md` is written in first person about how I want to be worked with, and `bashrc` assumes my toolchain. Fork it and rewrite both rather than copying them and wondering why Claude keeps mentioning mise.

MIT licensed. Take whatever's useful.
