# Commands Reference

## bridge.sh

All commands go through `.claude-bridge/bridge.sh`. For multi-server setups, specify the server name before the command: `bridge.sh <server> <command>`. If only one server is configured, the server name is optional.

### Synchronous (ask and wait)

| Command | Description |
|---------|-------------|
| `bridge.sh ask "prompt"` | Ask remote Claude, get response immediately |
| `bridge.sh ask -c "prompt"` | Follow-up (continues previous session) |
| `bridge.sh myserver ask "prompt"` | Ask a specific server |

### Async (queue and process)

| Command | Description |
|---------|-------------|
| `bridge.sh send "prompt"` | Queue a new task |
| `bridge.sh follow-up "prompt"` | Queue a follow-up (continues session) |
| `bridge.sh process` | Process all pending tasks |
| `bridge.sh results` | Show all completed results |
| `bridge.sh read <task-id>` | Read a specific result |
| `bridge.sh clear` | Clear all results |

### File transfer

| Command | Description |
|---------|-------------|
| `bridge.sh pull <remote-path> <local-path>` | Download file from remote |
| `bridge.sh push <local-path> <remote-path>` | Upload file to remote |

### Worker management

| Command | Description |
|---------|-------------|
| `bridge.sh worker-start` | Start background worker (polls inbox every 10s) |
| `bridge.sh worker-stop` | Stop background worker |
| `bridge.sh worker-status` | Check worker and queue status |

### Server management

| Command | Description |
|---------|-------------|
| `bridge.sh servers` | List all configured servers |
| `bridge.sh default <server>` | Set the default server |

### General

| Command | Description |
|---------|-------------|
| `bridge.sh ssh "cmd"` | Run any command on remote server |
| `bridge.sh help` | Show help |

## justfile

Setup generates `justfile.claude-bridge` which wraps bridge.sh. To use it, rename to `justfile` or merge into your existing one. Requires [just](https://github.com/casey/just).

| Command | Description |
|---------|-------------|
| `just ask "prompt"` | Ask remote Claude (sync) |
| `just follow-up "prompt"` | Follow-up (continues session) |
| `just send "prompt"` | Queue async task |
| `just send-follow-up "prompt"` | Queue async follow-up |
| `just process` | Process async tasks |
| `just results` | Show results |
| `just read <id>` | Read specific result |
| `just clear` | Clear results |
| `just pull <remote> <local>` | Download file |
| `just push <local> <remote>` | Upload file |
| `just worker-start` | Start background worker |
| `just worker-stop` | Stop worker |
| `just worker-status` | Worker status |
| `just servers` | List servers |
| `just default <server>` | Set default server |
| `just ssh-cmd "cmd"` | Run remote command |

If you use a different task runner (make, task, etc.), the generated justfile can serve as a reference for wrapping bridge.sh in your preferred tool.

## Task JSON format

Tasks in remote `~/claude-bridge/inbox/`:
```json
{
  "id": "task-1234-5678",
  "prompt": "check disk usage",
  "continue": false,
  "ts": "2026-04-13T15:00:00"
}
```

Results in remote `~/claude-bridge/outbox/`:
```json
{
  "id": "task-1234-5678",
  "prompt": "check disk usage",
  "continue": false,
  "result": "Disk usage on /: 47% (22GB/48GB used)...",
  "exit_code": 0,
  "ts": "2026-04-13T15:00:12"
}
```

Set `"continue": true` to resume the previous Claude session for multi-turn conversations.
