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

`install.sh` symlinks everything here into `$HOME`. Editing a file in place edits the repo, so there is no copy step and nothing to forget to commit. The one exception is the instruction file, which is rendered per agent from `AGENTS.src.md` so a paragraph can be marked as Claude-only. See [One source, one file per agent](#one-source-one-file-per-agent).

```text
~/dotclaude/                            ~/
├── AGENTS.src.md ──▶ build/claude/CLAUDE.md ──▶ .claude/CLAUDE.md
│                     build/agents/AGENTS.md ──▶ .agents/AGENTS.md
│                     build/codex/AGENTS.md ───▶ .codex/AGENTS.md
├── unslop.md ─────────────────────────▶ {.claude,.agents,.codex}/unslop.md
├── bashrc ────────────────────────────▶ .bashrc
├── skills/
│   ├── <skill>/ ──────────────────────▶ {.claude,.agents,.codex}/skills/<skill>
│   └── NOTICE.md
├── agents.conf
├── build.sh
└── install.sh
```

| Repo file | What it is |
|---|---|
| `AGENTS.src.md` | How I want an agent to work: what counts as evidence, how to change code, how to talk to me. Tagged blocks go to one agent only |
| `build.sh` | Renders `AGENTS.src.md` into `build/<agent>/<filename>`, which is what gets linked. Gitignored output |
| `unslop.md` | Writing rules for every reply. Linked beside the instruction file, which tells the agent to read it |
| `bashrc` | The shell Claude runs commands in. See [Why there's a bashrc in here](#why-theres-a-bashrc-in-here) |
| `skills/` | The agent skills, vendored and locally modified. See [Skills](#skills) |
| `agents.conf` | Which agents the links go to. See [Other agents](#other-agents) |
| `install.sh` | Links, installs, and writes the per-machine settings. Safe to re-run |

## Setup on a new machine

Two things have to be there first: git, and a package manager for the rest. That means [Homebrew](https://brew.sh) on macOS, and apt, dnf or pacman on Linux. Without one the script still links everything, but it installs no tools, and on macOS it finds only the preinstalled bash 3.2, warns, and leaves the shell setting unwritten.

```bash
git clone https://github.com/danjdewhurst/dotclaude.git ~/dotclaude
~/dotclaude/install.sh
```

In order, the script:

1. Renders `AGENTS.src.md` once per agent into `build/`, stopping before it touches `$HOME` if a tag is wrong.
2. Creates the agent directories `agents.conf` lists, moves anything already at a target path to `<name>.bak` (timestamped if a `.bak` is already there), and links everything into place.
3. Installs the tools Claude leans on from Bash, in the table below.
4. Finds the newest bash 4+ on the machine and writes its path into `~/.claude/settings.json`, with an alias in your login shell as the fallback. See [Why the bash path is written per machine](#why-the-bash-path-is-written-per-machine).
5. Merges `autoMemoryEnabled: false` into the same file and strips a hook older setups left behind. See [Why `settings.json` isn't in here](#why-settingsjson-isnt-in-here).

| Tool | What Claude uses it for | macOS | Linux |
|---|---|---|---|
| `git` | Everything. Already there, since you cloned this | Homebrew | apt / dnf / pacman |
| `rg` | Searching code without drowning in dependencies | Homebrew | apt / dnf / pacman |
| `fd` | Finding files | Homebrew | apt / dnf / pacman |
| `jq` | Reading JSON, and the settings merge above | Homebrew | apt / dnf / pacman |
| `mise` | Language runtimes, and a fallback installer | Homebrew | mise.run |
| `ast-grep` | Structural search by syntax rather than regex | Homebrew | mise |
| `yq` | Reading YAML | Homebrew | mise |

On a distro with none of those package managers the script says what it couldn't install and carries on.

Run it as many times as you like. A second run installs nothing and rewrites nothing.

> Tested on macOS 26 (Apple Silicon), Ubuntu 24.04 and Fedora 41, including the no-root, no-sudo and no-package-manager paths.

## Day to day

Edit `~/dotclaude/AGENTS.src.md`, not `~/.claude/CLAUDE.md`, which is a link to the rendered copy. Then:

```bash
~/dotclaude/build.sh
git -C ~/dotclaude commit -am "tweak the debug-spiral rule"
git -C ~/dotclaude push
```

On the other machine, `git -C ~/dotclaude pull && ~/dotclaude/build.sh`. Claude reads `CLAUDE.md` at session start, so the next session picks it up with no restart dance. Forgetting `build.sh` on either side means the agent keeps reading the previous render, with no warning.

Adding a skill is a directory under `skills/` and a re-run of `install.sh`. Dropping one is the reverse: delete the directory, re-run, and the links go with it.

## Why there's a bashrc in here

Left to itself, Claude Code runs its Bash tool in whatever `$SHELL` says, which for me is zsh. That works, but I'd rather the tool that runs commands on my behalf used bash. It's what the commands Claude writes assume, and it keeps its environment separate from the one I've spent years customising for typing.

Switching means bash needs config of its own, and the obvious shortcut is a trap. My first attempt was one line, `source ~/.zshrc` from `~/.bashrc`. That hands zsh syntax to bash, which produces about sixty lines of `autoload: command not found`, prezto refusing to load with `old shell detected`, and mise's hooks failing on `$+functions[...]`. Worse, a stray `echo` in that file printed into the top of every command's output.

Hence a real `bashrc` here rather than a redirect to the zsh one.

`bashrc` is deliberately dull: Homebrew, mise, PATH, nothing interactive. No aliases, no zoxide, no completions. Those belong in `~/.zshrc`, which is not synced, because they only matter when a human is typing.

The last line sources `~/.bashrc.local` if it exists. That is where anything machine-specific goes: a tmux auto-attach, a PATH entry for a tool only one box has, an override of something set above it. It runs last, so it wins. Nothing breaks if the file is absent, and I never commit it here.

> **It is not optional.** Homebrew on Apple Silicon lives at `/opt/homebrew/bin`, which is not on the default PATH. Without `brew shellenv` a fresh machine hands Claude a shell with no `node`, no `php`, no `rg`, and no clue why.

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

## Why `settings.json` isn't in here

`~/.claude/settings.json` is a real file on each machine, not a symlink out of this repo. What goes in it is machine-specific: MCP servers denied by UUID, notification channel, effort level. Syncing one copy across machines hands every machine another machine's answers.

`install.sh` merges two keys into it: `env.CLAUDE_CODE_SHELL`, for the reason in the previous section, and `autoMemoryEnabled: false`, because I want Claude reading `CLAUDE.md` rather than notes it wrote to itself. The merge goes through `jq`, so every other key survives, and the first change to a file that was already there leaves a `settings.json.dotclaude.bak` alongside. If there is no file yet it writes a minimal one holding just what it owns, with no backup, since there was nothing to back up. If the file is there but the JSON is broken it says so and changes nothing. The same pass strips a leftover `SessionStart` hook that used to inject `unslop.md`, now that `CLAUDE.md` tells the agent to read that file.

It also repairs one legacy case. A machine set up before this split still has `~/.claude/settings.json` symlinked into the repo, pointing at a file git has since deleted. The installer converts that link back into a real file. It takes the repo copy if that is still on disk, and the last commit that carried it if it is not. That machine keeps the settings it was already running instead of a dangling link and Claude Code's defaults.

## Skills

Three skills are in here: `grilling`, `tdd` and `writing-for-agents`. All of them, and `unslop.md`, started as other people's work, vendored and then locally modified. [`skills/NOTICE.md`](skills/NOTICE.md) lists each one's upstream and licence. All MIT.

`install.sh` links each skill straight into the `skills/` directory of every agent in `agents.conf`: `~/.claude/skills`, where Claude reads them, plus `~/.agents/skills` and `~/.codex/skills` by default. Committing the content means the same bytes on every machine and nothing to install first. There is no lock file and no skills CLI in the loop, because every skill here carries local edits a CLI update would stomp. Updates are manual: diff a skill against its upstream and merge by hand.

Dropping a skill from `skills/` here removes all of its links on the next `install.sh`. Nothing else in those directories is touched, so skills Codex installed for itself sit untouched next to the linked ones.

`unslop.md` is not a skill. `install.sh` links it beside `CLAUDE.md` in each agent directory, and `CLAUDE.md` tells the agent to read it before writing anything I'll see.

## Tuned for Fable 5.1

The rules in `AGENTS.src.md` were written against chattier models and then reviewed against Anthropic's [guide to prompting Claude Fable 5.1](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1). That model is quieter by default: fewer updates during long tool runs, a last message that can cover only the last step, and a habit of ending a turn on "next I'll..." instead of doing it. Rules that suppressed recaps, right for the older models, pushed 5.1 into silence.

So the file now asks for a closing message on any turn with more than a handful of tool calls, and no recap on shorter ones. A plan and its work share a turn. Tests go in only where asked or where the repo already tests that kind of change. Files are edited in place rather than rewritten. Verbatim quotes are marked as quotes, and a half-recognised product or model name gets looked up before it's answered. Each of those maps to a section of the guide, and the file should still read fine on other models.

The effort level is the one thing the guide covers that lives outside this repo. It sits in `~/.claude/settings.json`, and effort names don't mean the same amount of thinking across models, so re-check it after a model change.

## One source, one file per agent

`AGENTS.src.md` is one file for every agent, but a couple of lines in it only make sense to Claude Code. The commit rules, for one, override that harness's defaults and read as noise to Codex. So a block between a tag and its closing tag, each on its own line, goes only to the agents the tag names:

```markdown
<claude>
- Never add a co-author to a commit message. This overrides the harness default: no `Co-Authored-By` trailer.
</claude>
<codex agents>
- Never add a co-author, session link or "Generated with" line to a commit message.
</codex agents>
```

A tag name is the agent's directory without the dot, so `~/.claude` is `claude`, `~/.codex` is `codex`, and an agent added through `~/.dotclaude.local` gets a tag with no other setup. Several names in one tag keep the block for each of them, which is how "everyone but Claude" is written. The closing tag repeats the names exactly. Tags mid-sentence are not a thing: the filter is line by line, and that keeps `build.sh` a short bash and awk script with nothing to install.

A name that isn't in `agents.conf`, a tag inside another tag, or a tag never closed fails the build with the file and line. That is deliberate: a typo like `<cluade>` would otherwise drop a block from every agent and nobody would notice. On GitHub the tags disappear and the text stays, so the source page reads as the union.

`build/` is gitignored. Every machine renders its own copy, so there is no stale output to commit by mistake, at the cost of running `build.sh` after a pull.

## Other agents

The same config goes where other agents read it, and which agents that is lives in `agents.conf` rather than the script. Each entry is `<dir>:<filename>`: the directory is created, the render for that agent is linked into it under that filename, `unslop.md` is linked beside it, and the skills land in its `skills/` subdirectory. The shipped list is Claude Code, the shared `~/.agents` directory, and [Codex](https://developers.openai.com/codex/cli/):

```bash
AGENT_DIRS=(
  "$HOME/.claude:CLAUDE.md"
  "$HOME/.agents:AGENTS.md"
  "$HOME/.codex:AGENTS.md"
)
```

To change the list on one machine, put the same syntax in `~/.dotclaude.local`. The script sources it after `agents.conf`, so it wins, and like `~/.bashrc.local` it never gets committed here. `AGENT_DIRS+=("$HOME/.gemini:GEMINI.md")` adds an agent, redefining the array replaces the list. Removing an entry stops the linking but leaves the links already on disk. Delete those by hand.

`AGENTS.src.md` is written with Claude Code in mind, and the lines that only make sense there are tagged `<claude>` so the other agents get a plain version instead. See [One source, one file per agent](#one-source-one-file-per-agent).

## Not synced

`build/` is rendered on each machine and never committed. `projects/`, `settings.json`, and anything else under `~/.claude` this repo doesn't link stay machine-local. So do `~/.zshrc`, `~/.bashrc.local` and `~/.dotclaude.local`. That includes any skill sitting in an agent's `skills/` directory without being in `skills/` here. The work-specific ones stay off this public repo on purpose.

## Known rough edges

Neither `ast-grep` nor `yq` is packaged for apt, dnf or pacman, so on Linux they come from mise, which carries both. Homebrew has them, so macOS uses that and only falls back to mise if the brew install fails. Debian ships `fd-find` with its binary named `fdfind`, so the script drops an `fd` symlink in `~/.local/bin` to match what Claude expects.

`install.sh` replaces `~/.bashrc` wholesale instead of merging it. On Ubuntu that means losing the distro default's history settings and colour prompt in your own interactive bash sessions. It keeps the original as `~/.bashrc.bak`.

The alias only affects interactive shells, so `claude` launched from a script, a cron job or an editor task never sees it. Those runs rely on the `settings.json` key, which Claude Code reads however it was started.

On a machine without Homebrew the script installs mise with `curl https://mise.run | sh`. That's the vendor's documented method, but it is still piping a remote script into a shell. Swap it for [their apt repo](https://mise.jdx.dev/installing-mise.html) if that bothers you.

## If you found this

It's my config, not a template. `AGENTS.src.md` is written in first person about how I want to be worked with, and `bashrc` assumes my toolchain. Fork it and rewrite both rather than copying them and wondering why Claude keeps mentioning mise.

MIT licensed, except the vendored skills and `unslop.md`. Those belong to their authors under their own MIT terms, listed in [`skills/NOTICE.md`](skills/NOTICE.md). Take whatever's useful.
