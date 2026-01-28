# moonbead

Minimal single-machine issue tracker for AI agents, backed by JSONL.

## Install (macOS)

```bash
./scripts/install-macos.sh
```

Requires MoonBit CLI (moon). Installs `moonbead` to `/opt/homebrew/bin`,
`/usr/local/bin`, or `~/.local/bin` depending on what is writable.

## Install (Linux)

```bash
./scripts/install-linux.sh
```

Requires MoonBit CLI (moon). Installs `moonbead` to `/usr/local/bin` or
`~/.local/bin` depending on what is writable.

## Initialize

```bash
moonbead init
```

Creates `.beads/issues.jsonl` and adds a Moonbead section to `AGENTS.md`
if missing.
