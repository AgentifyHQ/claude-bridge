# claude-bridge

A bridge for running Claude Code on remote servers via SSH — synchronous or async, with session continuity and file transfer.

## What it does

```
Local Machine                          Remote Server
┌─────────────────┐                    ┌─────────────────┐
│ Claude Code     │   SSH              │ Claude Code     │
│ (local)         │ ────────────────>  │ (remote)        │
│                 │                    │                 │
│ ask ────────────│──> claude -p ─────>│ runs task       │
│   <── stdout ───│<── result ────────<│ reports back    │
│                 │                    │                 │
│ send ───────────│──> inbox/*.json ──>│ process_tasks.py│
│ results <───────│<── outbox/*.json <─│ (async worker)  │
│                 │                    │                 │
│ push/pull ──────│──> scp ──────────> │ file transfer   │
└─────────────────┘                    └─────────────────┘
```

**Features:**
- **Sync mode** (`ask`) — ask remote Claude, get response immediately
- **Async mode** (`send`/`process`) — queue tasks, process later, check results
- **Session continuity** — multi-turn conversations via `--continue`
- **File transfer** — `push`/`pull` files between local and remote
- **Reporting** — remote Claude provides structured reports of what it did
- **Multi-server** — set up bridges to multiple servers, merge configs
- Three interfaces: `bridge.sh` (zero deps), `justfile`, or Claude Code via ssh-mcp

## Project structure

```
claude-bridge/
├── setup.sh                     # One-command setup
├── merge-mcp.sh                 # Merge all server .mcp.json configs
├── README.md
├── remote/                      # Scripts deployed to remote server
│   ├── process_tasks.py         # Async task processor
│   ├── bridge-worker.sh         # Background watcher
│   ├── submit_task.py           # Task submitter
│   ├── bridge-cli.sh            # CLI template
│   └── CLAUDE.md.template       # Agent context + reporting guidelines
└── servers/                     # Generated per-server configs
    └── <server-name>/           # e.g., "my-server", "prod-api"
        ├── bridge.sh            # Zero-dep CLI (bash + ssh only)
        ├── justfile             # For just users
        └── .mcp.json            # For Claude Code ssh-mcp integration
```

## Quick start

```bash
# 1. Setup — installs Claude Code on remote, deploys bridge, generates local config
./setup.sh user@hostname --name my-server

# 2. Authenticate Claude Code on the remote (one-time)
ssh user@hostname
claude  # follow login prompts, then exit

# 3. Ask remote Claude something (synchronous)
./servers/my-server/bridge.sh ask "check disk usage and report"

# 4. Follow-up (continues previous session)
./servers/my-server/bridge.sh ask -c "what about memory?"

# 5. Transfer files
./servers/my-server/bridge.sh pull /var/log/syslog ./syslog.local
./servers/my-server/bridge.sh push ./config.yaml /etc/myapp/config.yaml
```

## Setup options

```
./setup.sh user@host [options]

Options:
  --key PATH       SSH key path (default: ~/.ssh/id_ed25519)
  --port PORT      SSH port (default: 22)
  --name NAME      Server name for config (default: derived from host)
  --bridge-dir DIR Remote bridge directory (default: ~/claude-bridge)
  --workspace DIR  Remote workspace directory (default: ~/claude-workspace)
  --no-install     Skip Claude Code installation on remote
```

## Usage

### bridge.sh (zero dependencies — just bash + ssh)

**Synchronous (ask and wait):**

| Command | Description |
|---------|-------------|
| `./bridge.sh ask "prompt"` | Ask remote Claude, get response immediately |
| `./bridge.sh ask -c "prompt"` | Follow-up (continues previous session) |

**Async (queue and process):**

| Command | Description |
|---------|-------------|
| `./bridge.sh send "prompt"` | Queue a new task |
| `./bridge.sh follow-up "prompt"` | Queue a follow-up (continues session) |
| `./bridge.sh process` | Process all pending tasks |
| `./bridge.sh results` | Show all completed results |
| `./bridge.sh read <task-id>` | Read a specific result |
| `./bridge.sh clear` | Clear all results |

**File transfer:**

| Command | Description |
|---------|-------------|
| `./bridge.sh pull <remote> <local>` | Download file from remote |
| `./bridge.sh push <local> <remote>` | Upload file to remote |

**Worker and server management:**

| Command | Description |
|---------|-------------|
| `./bridge.sh worker-start` | Start background worker |
| `./bridge.sh worker-stop` | Stop background worker |
| `./bridge.sh worker-status` | Check worker and queue status |
| `./bridge.sh ssh "cmd"` | Run any command on remote |

### Claude Code with ssh-mcp

Copy `.mcp.json` to your project root and restart Claude Code. This gives your local Claude direct SSH access to the remote server via MCP tools — including `exec` for commands and `sudo-exec` for elevated operations.

## Multi-server setup

Run setup for each server:

```bash
./setup.sh zhac218@192.168.1.112 --name openclaw
./setup.sh admin@192.168.1.50 --name file-server
./setup.sh pi@192.168.1.100 --name homelab
```

```
servers/
├── openclaw/    { bridge.sh, justfile, .mcp.json }
├── file-server/ { bridge.sh, justfile, .mcp.json }
├── homelab/     { bridge.sh, justfile, .mcp.json }
└── .mcp.json    # merged (generated by merge-mcp.sh)
```

Merge all server configs into one `.mcp.json` for Claude Code:

```bash
./merge-mcp.sh                             # writes to servers/.mcp.json
./merge-mcp.sh /path/to/project/.mcp.json  # or specify output path
```

This gives your local Claude Code access to all servers simultaneously via `ssh-<server-name>` MCP tools.

## Reporting

The remote Claude agent is instructed (via CLAUDE.md) to provide structured reports:

1. **What it did** — commands run, files modified, actions taken
2. **What it found** — results, status, errors, data
3. **What needs attention** — warnings, recommendations, follow-up actions

This means you get actionable output, not just raw command dumps.

## Local cross-folder communication

For local-to-local communication (folder A to folder B on the same machine), you don't need claude-bridge at all. Claude Code has this built in:

**Using the Agent tool:**
```
# In your Claude Code session, launch a subagent in another directory
Agent: "Go to /path/to/other-project and check the test results"
  → with --add-dir or by cd-ing to the target
```

**Using claude -p directly:**
```bash
cd /path/to/folder-b && claude -p "check test results" --add-dir /path/to/folder-a
```

**Using --add-dir in session:**
```bash
claude --add-dir /path/to/folder-b
# Now Claude can read/write both directories
```

The Agent tool spawns a fresh Claude instance as a subprocess — effectively a local bridge without any infrastructure. Use claude-bridge when you need to cross machine boundaries over SSH.

## Customization

### Allowed tools

Set `CLAUDE_BRIDGE_ALLOWED_TOOLS` on the remote to customize what the bridge agent can do:

```bash
export CLAUDE_BRIDGE_ALLOWED_TOOLS="Bash(docker:*) Bash(kubectl:*) Read Grep"
```

### Custom CLAUDE.md

Edit `~/claude-workspace/CLAUDE.md` on the remote to give the bridge agent server-specific context (installed services, project info, etc.).

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_BRIDGE_DIR` | `~/claude-bridge` | Bridge directory |
| `CLAUDE_BRIDGE_WORKSPACE` | `~/claude-workspace` | Working directory |
| `CLAUDE_BRIDGE_BIN` | `~/.local/bin/claude` | Claude binary path |
| `CLAUDE_BRIDGE_SESSION` | `claude-bridge` | Session name |
| `CLAUDE_BRIDGE_ALLOWED_TOOLS` | (see source) | Allowed tools |

## Requirements

**Local:** `bash`, `ssh` with key auth. Optionally `just` or Claude Code.

**Remote:** Python 3.8+, Node.js (for Claude Code install only).

## License

MIT
