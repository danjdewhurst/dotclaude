#!/usr/bin/env bash
# Render AGENTS.src.md once per agent into build/<agent>/<filename>.
#
# A block between <name> and </name>, both on their own lines, is kept only
# when the agent being built is one of the names. Several names in one tag
# (<codex agents>) keep the block for each of them. The name is the agent's
# directory without the dot: ~/.claude is claude, ~/.codex is codex. An unknown
# name, a nested tag or an unclosed one fails the build.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO/AGENTS.src.md"

. "$REPO/agents.conf"
if [ -f "$HOME/.dotclaude.local" ]; then
  . "$HOME/.dotclaude.local"
fi

# agent name for an AGENT_DIRS entry: the directory's basename, dot stripped
agent_of() {
  dir="${1%:*}"
  agent="${dir##*/}"
  printf '%s' "${agent#.}"
}

known=""
for entry in ${AGENT_DIRS[@]+"${AGENT_DIRS[@]}"}; do
  case "$entry" in *:*) ;; *) continue ;; esac
  known="$known $(agent_of "$entry")"
done

render() {
  awk -v agent="$1" -v known="$2" '
    BEGIN { n = split(known, k, " "); for (i = 1; i <= n; i++) ok[k[i]] = 1 }
    function fail(msg) {
      printf "%s:%d: %s\n", FILENAME, FNR, msg > "/dev/stderr"
      failed = 1
      exit 1
    }
    /^<\/[a-z][a-z0-9 -]*>$/ {
      if (open == "") fail("closing tag with nothing open: " $0)
      if (substr($0, 3, length($0) - 3) != open) fail("closing tag " $0 " does not match <" open ">")
      open = ""; skip = 0
      next
    }
    /^<[a-z][a-z0-9 -]*>$/ {
      if (open != "") fail("nested tag " $0 " inside <" open ">")
      open = substr($0, 2, length($0) - 2)
      skip = 1
      m = split(open, names, " ")
      for (i = 1; i <= m; i++) {
        if (!(names[i] in ok)) fail("unknown agent in tag: " names[i])
        if (names[i] == agent) skip = 0
      }
      next
    }
    !skip { print }
    END {
      if (failed) exit 1
      if (open != "") fail("unclosed <" open ">")
    }
  ' "$SRC"
}

for entry in ${AGENT_DIRS[@]+"${AGENT_DIRS[@]}"}; do
  case "$entry" in *:*) ;; *) continue ;; esac
  agent="$(agent_of "$entry")"
  name="${entry##*:}"
  out="$REPO/build/$agent/$name"
  mkdir -p "$(dirname "$out")"
  if ! render "$agent" "$known" > "$out.tmp"; then
    rm -f "$out.tmp"
    exit 1
  fi
  mv "$out.tmp" "$out"
  echo "Built build/$agent/$name"
done
