# claude-bridge

Run Claude Code on remote servers via SSH — ask questions, queue tasks, transfer files, with multi-turn session continuity.

```
Local Machine                          Remote Server
┌─────────────────┐                    ┌─────────────────┐
│ Claude Code     │   SSH              │ Claude Code     │
│ (local)         │ ────────────────>  │ (remote)        │
│                 │                    │                 │
│ ask ────────────│──> claude -p ─────>│ runs task       │
│   <── stdout ───│<── result ────────<│ reports back    │
│                 │                    │                 │
│ send ───────────│──> inbox/*.json ──>│ (async worker)  │
│ results <───────│<── outbox/*.json <─│                 │
│                 │                    │                 │
│ push/pull ──────│──> scp ──────────> │ file transfer   │
└─────────────────┘                    └─────────────────┘
```

## Quick start

```bash
# 1. Clone claude-bridge anywhere you like
git clone https://github.com/AgentifyHQ/claude-bridge.git /path/to/claude-bridge

# 2. Go to your project and run setup
cd ~/my-project
/path/to/claude-bridge/setup.sh user@hostname

# 3. Authenticate Claude Code on the remote (one-time)
ssh user@hostname
claude  # follow login prompts, then exit

# 4. Restart Claude Code, then use it
.claude-bridge/bridge.sh ask "check disk usage and report"
.claude-bridge/bridge.sh ask -c "what about memory?"       # follow-up

# Or with just (rename justfile.claude-bridge to justfile)
just ask "check disk usage and report"
just follow-up "what about memory?"
```

## Setup options

```
/path/to/claude-bridge/setup.sh user@host [options]

  --key PATH       SSH key path (default: ~/.ssh/id_ed25519)
  --port PORT      SSH port (default: 22)
  --name NAME      Server name (default: derived from host)
  --bridge-dir DIR Remote bridge directory (default: ~/claude-bridge)
  --workspace DIR  Remote workspace directory (default: ~/claude-workspace)
  --no-install     Skip Claude Code installation on remote
```

## What gets created

**In your project folder:**
```
your-project/
├── .claude-bridge/         # gitignore this
│   ├── bridge.sh           # CLI — all commands go through here
│   └── servers/            # per-server config files
│       ├── my-server.conf  # SSH target, key, extra tools, etc.
│       └── .default        # default server name
├── .mcp.json               # ssh-mcp config (merged)
└── justfile.claude-bridge  # optional, rename to justfile or merge into yours
```

**In your home directory:**
```
~/.claude/skills/claude-bridge/   # skill (teaches Claude how to use bridge)
├── SKILL.md
└── references/
```

**On the remote server:**
```
~/claude-bridge/            # bridge infrastructure (inbox, outbox, workers)
~/claude-workspace/         # remote Claude's working directory + CLAUDE.md
```

## Requirements

**Local:** `bash`, `ssh` with key auth. Optionally [just](https://github.com/casey/just) for the justfile.

**Remote:** Python 3.8+, Node.js (for Claude Code install only).

## What setup does automatically

- Installs Claude Code on the remote server (if not present)
- Deploys bridge scripts (task processor, worker, submitter) to the remote
- Creates `.claude-bridge/` with bridge CLI and server config
- Merges ssh-mcp entry into `.mcp.json` (preserves existing MCP servers)
- Installs Claude Code skill to `~/.claude/skills/claude-bridge/` (teaches Claude how to use the bridge)
- Creates `justfile.claude-bridge` (rename to `justfile` or merge into yours)
- Supports multiple servers — run setup again with a different `--name`

## Documentation

- [Commands Reference](docs/commands.md) — full list of bridge.sh and justfile commands
- [Multi-server Setup](docs/multi-server.md) — bridging to multiple servers
- [Customization](docs/customization.md) — server-specific tools, permissions, CLAUDE.md
- [Claude Code Integration](docs/claude-code.md) — using ssh-mcp for direct access
- [Architecture](docs/architecture.md) — how the bridge works under the hood
- [Local Communication](docs/local.md) — cross-folder without SSH (built-in Claude Code)

## License

MIT
