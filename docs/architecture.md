# Architecture

## Overview

claude-bridge connects a local Claude Code instance to a remote one over SSH. It has two modes:

**Sync mode** (`ask`) — runs `claude -p` on the remote server via SSH and streams the result back to stdout. Simple, immediate, one command.

**Async mode** (`send`/`process`) — writes task JSON files to a remote inbox, a worker processes them with `claude -p`, and results appear in an outbox. Good for background processing and task queues.

## Components

### Local (your machine)

```
.claude-bridge/
├── bridge.sh           # CLI entry point, routes commands to servers
├── servers/
│   ├── myserver.conf   # SSH_TARGET, SSH_KEY, EXTRA_TOOLS, SKIP_PERMISSIONS
│   └── .default        # default server name
├── .claude-plugin/     # plugin metadata
└── skills/             # Claude Code skill

justfile                # optional convenience wrapper (auto-generated)
.mcp.json               # ssh-mcp config for Claude Code (auto-merged)
.claude/settings.json   # plugin registration (auto-merged)
```

`bridge.sh` reads server config from `.conf` files and uses `ssh` for commands and `scp` for file transfer. No dependencies beyond bash and ssh.

### Remote (the server)

```
~/claude-bridge/
├── inbox/            # async task queue (JSON files)
├── outbox/           # async results (JSON files)
├── process_tasks.py  # reads inbox, runs claude -p, writes to outbox
├── bridge-worker.sh  # loops process_tasks.py every N seconds
└── submit_task.py    # creates task JSON files in inbox

~/claude-workspace/
└── CLAUDE.md         # agent context, reporting instructions
```

## Sync flow

```
bridge.sh [server] ask "prompt"
  → loads servers/<server>.conf (SSH_TARGET, EXTRA_TOOLS, SKIP_PERMISSIONS)
  → ssh user@host "claude -p 'prompt' --allowedTools '...' -n claude-bridge [--dangerously-skip-permissions]"
  → remote Claude runs, output goes to stdout
  → result printed locally
```

## Async flow

```
bridge.sh [server] send "prompt"
  → ssh user@host "python3 submit_task.py 'prompt'"
  → task-123.json written to inbox/

bridge.sh [server] process (or background worker)
  → ssh user@host "python3 process_tasks.py"
  → reads inbox/task-123.json
  → runs: claude -p "prompt" --allowedTools "..." -n claude-bridge
  → writes outbox/task-123.json
  → deletes inbox/task-123.json

bridge.sh [server] results
  → ssh user@host "cat outbox/*.json"
  → results printed locally
```

## Session continuity

Both modes support `--continue` which tells `claude -p` to resume the most recent session in the working directory. This gives the remote Claude memory of previous interactions.

- Sync: `bridge.sh ask -c "follow-up question"`
- Async: `bridge.sh follow-up "follow-up question"` (sets `"continue": true` in the task JSON)

Sessions are named (`-n claude-bridge`) and scoped to `~/claude-workspace/`.

## Security

- SSH key auth only (no passwords in config)
- Allowed tools are explicitly listed per server (no blanket shell access)
- `EXTRA_TOOLS` and `SKIP_PERMISSIONS` are per-server opt-in via `.conf` files
- Remote Claude runs in `~/claude-workspace/` with restricted tool permissions
- CLAUDE.md instructs the agent not to modify system config or delete files outside the bridge directory
- Generated config (`.claude-bridge/`) should be gitignored as it contains SSH connection details
