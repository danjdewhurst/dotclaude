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

My global [Claude Code](https://claude.com/claude-code) config, kept in one place so a new machine takes a clone and a script instead of an afternoon of remembering. The same files are linked where Codex and other agents look, so one repo configures all of them. See [Other agents](#other-agents).

`install.sh` symlinks everything here into `$HOME`. Editing a file in place edits the repo, so there is no copy step and nothing to forget to commit.

```text
~/dotclaude/                            ~/
├── CLAUDE.md ─────────────────────────▶ .claude/CLAUDE.md, {.agents,.codex}/AGENTS.md
├── bashrc ────────────────────────────▶ .bashrc
├── skills/
│   ├── <skill>/ ──────────────────────▶ {.claude,.agents,.codex}/skills/<skill>
│   └── NOTICE.md
├── agents.conf
├── install.sh
├── README.md
└── LICENSE
```

| Repo file | What it is |
|---|---|
| `CLAUDE.md` | How I want Claude to work: scope, code style, how to communicate |
| `bashrc` | The shell Claude runs commands in |
| `skills/` | The agent skills, vendored. See [Skills](#skills) |
| `agents.conf` | Which agents the links go to. See [Other agents](#other-agents) |

## Setup on a new machine

Two things have to be there first: git, and a package manager for the rest — [Homebrew](https://brew.sh) on macOS, apt, dnf or pacman on Linux. Without one the script still links everything, but it installs no tools, and on macOS it finds only the preinstalled bash 3.2, warns, and leaves the shell setting unwritten.

```bash
git clone https://github.com/danjdewhurst/dotclaude.git ~/dotclaude
~/dotclaude/install.sh
```

That creates the agent directories `agents.conf` lists if they're missing, moves anything already at those paths to `<name>.bak` (timestamped if a `.bak` is already there), and links everything into place. Then it installs the tools Claude leans on from Bash:

| Tool | What Claude uses it for | macOS | Linux |
|---|---|---|---|
| `git` | Everything. Already there, since you cloned this | Homebrew | apt / dnf / pacman |
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

Left to itself, Claude Code runs its Bash tool in whatever `$SHELL` says, which for me is zsh. That works, but I'd rather the tool that runs commands on my behalf used bash. It's what the commands Claude writes assume, and it keeps its environment separate from the one I've spent years customising for typing.

Switching means bash needs config of its own, and the obvious shortcut is a trap. My first attempt was one line, `source ~/.zshrc` from `~/.bashrc`. That hands zsh syntax to bash, which produces about sixty lines of `autoload: command not found`, prezto refusing to load with `old shell detected`, and mise's hooks failing on `$+functions[...]`. Worse, a stray `echo` in that file printed into the top of every command's output.

Hence a real `bashrc` here rather than a redirect to the zsh one.

`bashrc` is deliberately dull: Homebrew, mise, PATH, nothing interactive. No aliases, no zoxide, no completions. Those belong in `~/.zshrc`, which is not synced, because they only matter when a human is typing.

The last line sources `~/.bashrc.local` if it exists. That is where anything machine-specific goes: a tmux auto-attach, a PATH entry for a tool only one box has, an override of something set above it. It runs last, so it wins. Nothing breaks if the file is absent, and I never commit it here.

> **It is not optional.** Homebrew on Apple Silicon lives at `/opt/homebrew/bin`, which is not on the default PATH. Without `brew shellenv` a fresh machine hands Claude a shell with no `node`, no `php`, no `rg`, and no clue why.

## Why `settings.json` isn't in here

`~/.claude/settings.json` is a real file on each machine, not a symlink out of this repo. What goes in it is machine-specific: MCP servers denied by UUID, notification channel, effort level. Syncing one copy across machines hands every machine another machine's answers.

`install.sh` writes two things into it: `env.CLAUDE_CODE_SHELL`, for the reason in the next section, and a `SessionStart` hook that loads the `unslop` skill's rules into every session, so the writing rules reach each machine even though the file stays local. The merges go through `jq`, so every other key survives, and the first write leaves a `settings.json.dotclaude.bak` alongside. If there is no file yet it writes a minimal one holding just what it owns. If the file is there but the JSON is broken it says so and changes nothing.

It also repairs one legacy case. A machine set up before this split still has `~/.claude/settings.json` symlinked into the repo, pointing at a file git has since deleted. The installer converts that link back into a real file. It takes the repo copy if that is still on disk, and the last commit that carried it if it is not. That machine keeps the settings it was already running instead of a dangling link and Claude Code's defaults.

## Why the bash path is written per machine

Claude Code reads the Bash tool's shell from `env.CLAUDE_CODE_SHELL` in `settings.json`, and only falls back to `$SHELL` and a scan of `/bin`, `/usr/bin`, `/usr/local/bin` and `/opt/homebrew/bin` when that key is missing or does not point at a runnable bash or zsh. So that key is the thing to set. Its value is different on every machine:

| Machine | bash lives at |
|---|---|
| macOS, Apple Silicon | `/opt/homebrew/bin/bash` |
| macOS, Intel | `/usr/local/bin/bash` |
| Linux | `/usr/bin/bash` |
| macOS, preinstalled | `/bin/bash`, still 3.2.57. Avoid |

One synced file cannot hold all four. So `install.sh` finds the newest bash 4+ on the machine and merges the path it found into `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_SHELL": "/opt/homebrew/bin/bash"
  }
}
```

The same path also goes into a marked block in `~/.zshrc` and whichever bash login file already exists, as an alias setting `$SHELL` for that one command. That is the fallback for a machine where the key could not be written, one with no `jq` or a `settings.json` whose JSON is broken. It prefers `~/.profile` or `~/.bash_login` over creating a `~/.bash_profile`, which would shadow them:

```bash
# >>> dotclaude >>>
# Point Claude Code's Bash tool at bash instead of the login shell.
alias claude="SHELL='/opt/homebrew/bin/bash' claude"
# <<< dotclaude <<<
```

Those are the shells you launch `claude` from, never the synced `~/.bashrc`. Re-running rewrites the block where it already sits rather than stacking a second copy or moving it to the end of the file. If the block is already correct it does nothing at all. It writes *through* a symlinked rc file instead of replacing the symlink, which matters if your `~/.zshrc` points into prezto or another dotfiles checkout. If the markers are damaged, the script leaves the file alone and warns.

## Day to day

Edit `~/.claude/CLAUDE.md` as normal, then:

```bash
git -C ~/dotclaude commit -am "tweak the debug-spiral rule"
git -C ~/dotclaude push
```

On the other machine, `git -C ~/dotclaude pull`. Claude reads `CLAUDE.md` at session start, so the next session picks it up with no restart dance.

## Skills

`skills/` holds the agent skills verbatim, and `install.sh` links each one straight into the `skills/` directory of every agent in `agents.conf`: `~/.claude/skills`, where Claude reads them, plus `~/.agents/skills` and `~/.codex/skills` by default. Committing the content means the same bytes on every machine and nothing to install first. This repo used to route the `~/.claude` links *through* `~/.agents/skills` and keep a lock file so the skills CLI could update them, but every skill here has since been modified locally, so a CLI update would stomp those edits. That plumbing stays gone. Every link points straight into the repo, there is no lock file, and updates are manual: diff a skill against its upstream and merge by hand.

`unslop` fires differently from the rest. Rather than waiting to be invoked, a `SessionStart` hook in `settings.json` reads the linked skill and puts its rules in context from the first turn, replies included. `install.sh` writes that hook, since `settings.json` never syncs.

Dropping a skill from `skills/` here removes all of its links on the next `install.sh`. Nothing else in those directories is touched, so skills Codex installed for itself sit untouched next to the linked ones.

Four are in here: `grilling`, `tdd`, `unslop` and `writing-for-agents`. All of them started as other people's work, vendored and then locally modified. [`skills/NOTICE.md`](skills/NOTICE.md) lists each one's upstream and licence. All MIT.

## Other agents

The same config goes where other agents read it, and which agents that is lives in `agents.conf` rather than the script. Each entry is `<dir>:<filename>`: the directory is created, `CLAUDE.md` is linked into it under that filename, and the skills land in its `skills/` subdirectory. The shipped list is Claude Code, the shared `~/.agents` directory, and [Codex](https://developers.openai.com/codex/cli/):

```bash
AGENT_DIRS=(
  "$HOME/.claude:CLAUDE.md"
  "$HOME/.agents:AGENTS.md"
  "$HOME/.codex:AGENTS.md"
)
```

To change the list on one machine, put the same syntax in `~/.dotclaude.local`. The script sources it after `agents.conf`, so it wins, and like `~/.bashrc.local` it never gets committed here. `AGENT_DIRS+=("$HOME/.gemini:GEMINI.md")` adds an agent, redefining the array replaces the list. Removing an entry stops the linking but leaves the links already on disk. Delete those by hand.

One caveat. `CLAUDE.md` is written for Claude Code and names its skills and tools directly, so an agent reading it through `AGENTS.md` will hit instructions it can't act on. That's the trade for one file instead of one per agent, made knowingly.

## Not synced

`projects/`, `settings.json`, and anything else under `~/.claude` this repo doesn't link stay machine-local. So do `~/.zshrc`, `~/.bashrc.local` and `~/.dotclaude.local`.

## Known rough edges

Neither `ast-grep` nor `yq` is packaged for apt, dnf or pacman, so on Linux they come from mise, which carries both. Homebrew has them, so macOS uses that and only falls back to mise if the brew install fails. Debian ships `fd-find` with its binary named `fdfind`, so the script drops an `fd` symlink in `~/.local/bin` to match what Claude expects.

`install.sh` replaces `~/.bashrc` wholesale instead of merging it. On Ubuntu that means losing the distro default's history settings and colour prompt in your own interactive bash sessions. It keeps the original as `~/.bashrc.bak`.

The alias only affects interactive shells, so `claude` launched from a script, a cron job or an editor task never sees it. Those runs rely on the `settings.json` key, which Claude Code reads however it was started.

On a machine without Homebrew the script installs mise with `curl https://mise.run | sh`. That's the vendor's documented method, but it is still piping a remote script into a shell. Swap it for [their apt repo](https://mise.jdx.dev/installing-mise.html) if that bothers you.

## If you found this

It's my config, not a template. `CLAUDE.md` is written in first person about how I want to be worked with, and `bashrc` assumes my toolchain. Fork it and rewrite both rather than copying them and wondering why Claude keeps mentioning mise.

MIT licensed, except the vendored skills. Those belong to their authors under their own MIT terms, listed in [`skills/NOTICE.md`](skills/NOTICE.md). Take whatever's useful.
