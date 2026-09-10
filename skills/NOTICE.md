# Third-party skills

Every skill here is Lauren Tan's, from the `pstack` plugin in
[cursor/plugins](https://github.com/cursor/plugins/tree/main/pstack/skills).
Upstream is the place to file issues or send fixes. This file and
`pstack.patch` are my own.

## What was copied

Upstream commit `7366ac128bdf95f45e6734f412b49a4031800169` (2026-09-09).
The tree hash is the id git gives each skill's directory at that commit. If
it is unchanged at a newer upstream commit, the skill has no update.

| Directory | Upstream path | Tree hash at `7366ac1` |
| --- | --- | --- |
| `how` | `pstack/skills/how` | `ec7ec1c4ce1a4194695b6759a54e8a218b0f3936` |
| `tdd` | `pstack/skills/tdd` | `29dae88022641063ca2f568ec5be46c108210848` |
| `teach` | `pstack/skills/teach` | `3ee517292dae0476dc516f9f3805c08fb943c6ff` |
| `technical-writing` | `pstack/skills/technical-writing` | `e91d48c91a740d16d25ea5f2fbbad14bcf5d5332` |
| `unslop` | `pstack/skills/unslop` | `e19dcc9c531f4609df38bc86c62cf0e8b6d8f444` |
| `why` | `pstack/skills/why` | `7cae2f31c55827495b38ba185c5bd901b3a85fa2` |

## Local changes

`pstack` targets Cursor. `how` and `why` spawn subagents, and the parameters
they pass are Cursor's, so those two are edited to use Claude Code's Agent
tool instead. `tdd`, `teach`, `technical-writing` and `unslop` are byte for
byte upstream.

- `subagent_type` `generalPurpose` becomes `general-purpose`, or `Explore`
  for the `how` explorers. Claude Code has no `readonly` flag; `Explore` is
  its read-only agent, but it reads excerpts, so the explainer and synthesizer
  stay on `general-purpose` and rely on their prompt to stay read-only.
- Cursor model names (`grok-4.6-fast-xhigh`, `claude-fable-5-1-thinking-max`)
  become `sonnet` for the cheap parallel workers and "omit, so it inherits the
  session's model" for the explainer and synthesizer.
- `why` discovered MCP servers by reading Cursor's `mcps/` directory. It now
  reads the session's `mcp__<server>__<tool>` tool list and server
  instructions.
- Upstream's warnings against Cursor's Ask mode become notes that `Explore`
  has no MCP access.

The exact diff is `pstack.patch`, written so it applies to a fresh upstream
copy of the six directories with `patch -p1`.

## Updating

```bash
git clone -q --depth 1 --filter=blob:none --sparse https://github.com/cursor/plugins.git /tmp/plugins
git -C /tmp/plugins sparse-checkout set pstack
git -C /tmp/plugins rev-parse HEAD                      # new upstream commit
for s in how tdd teach technical-writing unslop why; do  # compare tree hashes to the table above
  echo "$s $(git -C /tmp/plugins rev-parse HEAD:pstack/skills/$s)"
done
```

For each skill whose tree hash moved: copy the upstream directory over the
local one, run `patch -p1 < pstack.patch` from `skills/` and fix any rejects
by hand, then update the commit and tree hashes in the table. Regenerate the
patch with the labels `patch -p1` expects:

```bash
diff -u --label upstream/how/SKILL.md --label local/how/SKILL.md /tmp/plugins/pstack/skills/how/SKILL.md how/SKILL.md > pstack.patch
diff -u --label upstream/why/SKILL.md --label local/why/SKILL.md /tmp/plugins/pstack/skills/why/SKILL.md why/SKILL.md >> pstack.patch
```

## Licence

`cursor/plugins` has no repository-level licence. The subtree these skills come
from carries its own, `pstack/LICENSE`, which is MIT and reproduced below.

MIT License

Copyright (c) 2026 Lauren Tan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
