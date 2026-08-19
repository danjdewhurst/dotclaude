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

Everything here is symlinked out of this repo into `$HOME`. Editing in place edits the repo, so there is no copy step and nothing to forget to commit.

```text
~/dotclaude/                            ~/
├── CLAUDE.md ─────────────────────────▶ .claude/CLAUDE.md
├── bashrc ────────────────────────────▶ .bashrc
├── skills/
│   ├── <skill>/ ──────────────────────▶ .agents/skills/<skill> ──▶ .claude/skills/<skill>
│   └── NOTICE.md
├── skill-lock.json ───────────────────▶ .agents/.skill-lock.json
├── install.sh
├── README.md
└── LICENSE
```

| Repo file | What it is |
|---|---|
| `CLAUDE.md` | How I want Claude to work: scope, code style, how to communicate |
| `bashrc` | The shell Claude runs commands in |
| `skills/` | The agent skills, vendored — see [Skills](#skills) |
| `skill-lock.json` | Where each skill came from, for `skills update` |

## Setup on a new machine

```bash
git clone git@github.com:danjdewhurst/dotclaude.git ~/dotclaude
~/dotclaude/install.sh
```

That creates `~/.claude` and `~/.agents` if they're missing, moves anything already at those paths to `<name>.bak` (timestamped if a `.bak` is already there), and links everything into place. Then it installs the tools Claude leans on from Bash:

| Tool | What Claude uses it for | macOS | Linux |
|---|---|---|---|
| `git` | Everything | Homebrew | apt / dnf / pacman |
| `rg` | Searching code without drowning in dependencies | Homebrew | apt / dnf / pacman |
| `fd` | Finding files | Homebrew | apt / dnf / pacman |
| `jq` | Reading JSON | Homebrew | apt / dnf / pacman |
| `mise` | Language runtimes, and a fallback installer | Homebrew | mise.run |
| `ast-grep` | Structural search by syntax rather than regex | Homebrew | mise |
| `yq` | Reading YAML | Homebrew | mise |

Linux support covers apt, dnf and pacman. On anything else the script says what it couldn't install and carries on.

Run it as many times as you like. A second run installs nothing and rewrites nothing.

> Tested on macOS 26 (Apple Silicon), Ubuntu 24.04 and Fedora 41, including the no-root, no-sudo and no-package-manager paths.

## Why there's a bashrc in here

Claude Code runs its Bash tool in whatever your `$SHELL` says, which for me is zsh. That works, but I'd rather the tool that runs commands on my behalf used bash: it's what the commands Claude writes assume, and it keeps its environment separate from the one I've spent years customising for typing.

Switching means bash needs config of its own, and the obvious shortcut is a trap. My first attempt was one line, `source ~/.zshrc` from `~/.bashrc`, which hands zsh syntax to bash and produces about sixty lines of `autoload: command not found`, prezto refusing to load with `old shell detected`, and mise's hooks failing on `$+functions[...]`. Worse, a stray `echo` in that file printed into the top of every command's output.

Hence a real `bashrc` here rather than a redirect to the zsh one.

`bashrc` is deliberately dull: Homebrew, mise, PATH, nothing interactive. No aliases, no zoxide, no completions. Those belong in `~/.zshrc`, which is not synced, because they only matter when a human is typing.

The last line sources `~/.bashrc.local` if it exists. That is where anything machine-specific goes: a tmux auto-attach, a PATH entry for a tool only one box has, an override of something set above it. It is sourced last, so it wins. Nothing breaks if the file is absent, and it is never committed here.

> **It is not optional.** Homebrew on Apple Silicon lives at `/opt/homebrew/bin`, which is not on the default PATH. Without `brew shellenv` a fresh machine hands Claude a shell with no `node`, no `php`, no `rg`, and no clue why.

## Why `settings.json` isn't in here

`~/.claude/settings.json` is a real file on each machine, not a symlink out of this repo. What goes in it is machine-specific — MCP servers denied by UUID, notification channel, effort level — and syncing one copy across machines means every one of them gets another machine's answers. `install.sh` leaves an existing one alone, with one exception. A machine set up before this split still has `~/.claude/settings.json` symlinked into the repo, pointing at a file git has since deleted, so the installer converts that link back into a real file — taking the repo copy if it is still on disk, and the last commit that carried it if it is not. That machine keeps the settings it was already running instead of a dangling link and Claude Code's defaults.

## Why the bash path isn't in there either

Claude Code takes the shell from `$SHELL`, so pointing it at bash is a matter of setting that variable when you launch it. The path, though, is different on every machine:

| Machine | bash lives at |
|---|---|
| macOS, Apple Silicon | `/opt/homebrew/bin/bash` |
| macOS, Intel | `/usr/local/bin/bash` |
| Linux | `/usr/bin/bash` |
| macOS, preinstalled | `/bin/bash` — still 3.2.57, avoid |

One synced file cannot hold all four. So `install.sh` finds the newest bash 4+ on the machine and writes a marked block into `~/.zshrc` and whichever bash login file already exists, preferring `~/.profile` or `~/.bash_login` over creating a `~/.bash_profile` that would shadow them:

```bash
# >>> dotclaude >>>
# Point Claude Code's Bash tool at bash instead of the login shell.
alias claude="SHELL='/opt/homebrew/bin/bash' claude"
# <<< dotclaude <<<
```

Those are the shells you launch `claude` from, never the synced `~/.bashrc`. Re-running replaces the block rather than stacking a second copy, and it writes *through* a symlinked rc file instead of replacing the symlink, which matters if your `~/.zshrc` points into prezto or another dotfiles checkout. If the markers are damaged, the file is left alone with a warning rather than rewritten.

## Day to day

Edit `~/.claude/CLAUDE.md` as normal, then:

```bash
git -C ~/dotclaude commit -am "tweak the debug-spiral rule"
git -C ~/dotclaude push
```

On the other machine, `git -C ~/dotclaude pull`. Claude reads `CLAUDE.md` at session start, so the next session picks it up with no restart dance.

## Skills

`skills/` holds the agent skills verbatim, and `install.sh` links each one into `~/.agents/skills` (the skills CLI's canonical directory), then into `~/.claude/skills` where Claude reads them. `skill-lock.json` records where each came from and is linked to `~/.agents/.skill-lock.json`, so `skills list` and `skills update` keep working.

Committing the content rather than replaying `skills add` on each machine means the same bytes everywhere, no GitHub round trip on setup, and no dependency on the CLI being installed. The trade is that an upstream skill only moves when you run `skills update` — which writes through the symlink and shows up here as a diff to review.

`skills add -g` still works as normal; new skills land as real directories in `~/.agents/skills` and stay machine-local until you copy them into `skills/` here.

Seven are in here: `better-writing`, `blast-radius`, `deslop`, `grilling`, `how`, `tdd` and `unslop`. All of them are other people's work, vendored unmodified. [`skills/NOTICE.md`](skills/NOTICE.md) lists each one's upstream and licence — all MIT.

## Not synced

`projects/` and everything else under `~/.claude` stay machine-local. So do `~/.zshrc` and `~/.bashrc.local`.

## Known rough edges

Neither `ast-grep` nor `yq` is packaged for apt, dnf or pacman, so on Linux they come from mise, which carries both in its registry. Homebrew has them, so macOS uses that and only falls back to mise if the brew install fails. Debian ships `fd-find` with its binary named `fdfind`, so the script drops an `fd` symlink in `~/.local/bin` to match what Claude expects.

`~/.bashrc` is replaced wholesale, not merged. On Ubuntu that means losing the distro default's history settings and colour prompt in your own interactive bash sessions. The original is kept as `~/.bashrc.bak`.

The alias only affects interactive shells, so `claude` launched from a script, a cron job or an editor task still uses your login shell.

On a machine without Homebrew the script installs mise with `curl https://mise.run | sh`. That's the vendor's documented method, but it is still piping a remote script into a shell. Swap it for [their apt repo](https://mise.jdx.dev/installing-mise.html) if that bothers you.

## If you found this

It's my config, not a template. `CLAUDE.md` is written in first person about how I want to be worked with, and `bashrc` assumes my toolchain. Fork it and rewrite both rather than copying them and wondering why Claude keeps mentioning mise.

MIT licensed, except the vendored skills — those belong to their authors under their own MIT terms, listed in [`skills/NOTICE.md`](skills/NOTICE.md). Take whatever's useful.
