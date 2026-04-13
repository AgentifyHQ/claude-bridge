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
# This creates .claude-bridge/, .mcp.json, and registers the skill automatically

# 3. Authenticate Claude Code on the remote (one-time)
ssh user@hostname
claude  # follow login prompts, then exit

# 4. Restart Claude Code, then use it
.claude-bridge/bridge.sh ask "check disk usage and report"
.claude-bridge/bridge.sh ask -c "what about memory?"       # follow-up
.claude-bridge/bridge.sh send "long running task"           # async
.claude-bridge/bridge.sh process                            # process async
.claude-bridge/bridge.sh results                            # check results
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
├── .claude-bridge/       # gitignore this
│   ├── bridge.sh         # CLI — all commands go through here
│   ├── .mcp.json         # ssh-mcp config for Claude Code
│   ├── .claude-plugin/   # plugin metadata
│   └── skills/           # Claude Code skill
└── .mcp.json             # copy from .claude-bridge/ for Claude Code
```

**On the remote server:**
```
~/claude-bridge/          # bridge infrastructure (inbox, outbox, workers)
~/claude-workspace/       # remote Claude's working directory + CLAUDE.md
```

## Requirements

**Local:** `bash`, `ssh` with key auth.

**Remote:** Python 3.8+, Node.js (for Claude Code install only).

## Claude Code Skill

Setup automatically installs a Claude Code skill into `.claude-bridge/`, copies `.mcp.json` to your project root, and registers the plugin in `.claude/settings.json`. After restarting Claude Code, your agent will automatically know how to use the bridge when you mention remote servers.

Everything is self-contained in your project — no global install needed.

## Documentation

- [Commands Reference](docs/commands.md) — full list of bridge.sh commands
- [Justfile Integration](docs/justfile.md) — wrapping bridge.sh with just
- [Claude Code Integration](docs/claude-code.md) — using ssh-mcp for direct access
- [Customization](docs/customization.md) — server-specific tools, CLAUDE.md, environment variables
- [Multi-server Setup](docs/multi-server.md) — bridging to multiple servers
- [Local Communication](docs/local.md) — cross-folder without SSH (built-in Claude Code)
- [Architecture](docs/architecture.md) — how the bridge works under the hood

## License

MIT
