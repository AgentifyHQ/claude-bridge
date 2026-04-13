---
name: Claude Bridge
description: This skill should be used when the user asks to "connect to a remote server", "set up a bridge", "ask the remote server", "send a task to remote", "run claude on remote", "check bridge results", "transfer files to server", "set up claude-bridge", "talk to remote claude", "delegate to remote", "bridge status", "remote claude task", or mentions remote server communication, cross-machine Claude Code coordination, or SSH-based agent delegation.
version: 0.1.0
---

# Claude Bridge

Communicate with Claude Code instances running on remote servers via SSH. Supports synchronous questions, async task queues, multi-turn sessions, and file transfer.

## Detecting an Existing Bridge

Before setting up a new bridge, check if one already exists in the project:

1. Look for `.claude-bridge/bridge.sh` in the project directory
2. If found, the bridge is already configured — skip to "Using the Bridge"
3. If not found, proceed with "Setting Up a New Bridge"

## Setting Up a New Bridge

### Prerequisites

- SSH key-based auth to the remote server (no password prompts)
- Python 3.8+ and Node.js on the remote server
- The `claude-bridge` tool cloned or accessible locally

### Setup Command

Run from the **project folder** where the bridge should live:

```bash
/path/to/claude-bridge/setup.sh user@hostname [options]
```

Options:
- `--key PATH` — SSH key (default: `~/.ssh/id_ed25519`)
- `--port PORT` — SSH port (default: 22)
- `--name NAME` — server name for config
- `--no-install` — skip Claude Code installation on remote

This creates `.claude-bridge/` in the current directory with `bridge.sh` and `.mcp.json`, and installs processing scripts on the remote server.

### Post-Setup

1. Copy `.mcp.json` for Claude Code integration: `cp .claude-bridge/.mcp.json .`
2. Authenticate Claude Code on the remote (one-time): `ssh user@host` then run `claude`
3. Customize allowed tools and remote agent context — see `references/customization.md` for details

## Using the Bridge

All commands go through `.claude-bridge/bridge.sh`. Execute via Bash tool. See `references/commands.md` for the full command reference and JSON task format.

### Sync Mode (ask and wait)

For immediate responses from the remote Claude:

```bash
.claude-bridge/bridge.sh ask "check disk usage and report"
```

For follow-up questions that continue the previous session:

```bash
.claude-bridge/bridge.sh ask -c "what about memory usage?"
```

### Async Mode (queue and process)

For background or batched tasks. Additional async commands (`follow-up`, `clear`) documented in `references/commands.md`.

```bash
# Queue a task
.claude-bridge/bridge.sh send "run full diagnostic"

# Queue a follow-up (continues previous session)
.claude-bridge/bridge.sh follow-up "now check the logs"

# Process all pending tasks
.claude-bridge/bridge.sh process

# Check results
.claude-bridge/bridge.sh results

# Read specific result
.claude-bridge/bridge.sh read <task-id>

# Clear all results
.claude-bridge/bridge.sh clear
```

### File Transfer

```bash
# Download from remote
.claude-bridge/bridge.sh pull /remote/path ./local/path

# Upload to remote
.claude-bridge/bridge.sh push ./local/path /remote/path
```

### Worker Management

For continuous async processing:

```bash
.claude-bridge/bridge.sh worker-start    # start background worker
.claude-bridge/bridge.sh worker-stop     # stop it
.claude-bridge/bridge.sh worker-status   # check status
```

### Direct SSH

Run any command on the remote server:

```bash
.claude-bridge/bridge.sh ssh "any shell command"
```

## When to Use Each Mode

| Scenario | Mode | Command |
|----------|------|---------|
| Quick question about server state | Sync | `ask "..."` |
| Multi-step investigation | Sync + follow-up | `ask "..."` then `ask -c "..."` |
| Long-running task | Async | `send "..."` + `process` |
| Batch multiple tasks | Async | multiple `send` + `process` |
| Download logs or configs | File transfer | `pull` |
| Deploy a config file | File transfer | `push` |
| Run a specific command | Direct SSH | `ssh "..."` |

## Reporting

The remote Claude agent provides structured reports with:
1. **What it did** — commands run, files modified
2. **What it found** — results, status, data
3. **What needs attention** — warnings, recommendations

## Additional Resources

### Reference Files

- **`references/commands.md`** — full command reference with JSON task format
- **`references/customization.md`** — server-specific tools, CLAUDE.md, environment variables
