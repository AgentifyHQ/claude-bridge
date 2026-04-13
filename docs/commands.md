# Commands Reference

All commands go through `.claude-bridge/bridge.sh`.

## Synchronous (ask and wait)

| Command | Description |
|---------|-------------|
| `bridge.sh ask "prompt"` | Ask remote Claude, get response immediately |
| `bridge.sh ask -c "prompt"` | Follow-up (continues previous session) |

## Async (queue and process)

| Command | Description |
|---------|-------------|
| `bridge.sh send "prompt"` | Queue a new task |
| `bridge.sh follow-up "prompt"` | Queue a follow-up (continues session) |
| `bridge.sh process` | Process all pending tasks |
| `bridge.sh results` | Show all completed results |
| `bridge.sh read <task-id>` | Read a specific result |
| `bridge.sh clear` | Clear all results |

## File transfer

| Command | Description |
|---------|-------------|
| `bridge.sh pull <remote-path> <local-path>` | Download file from remote |
| `bridge.sh push <local-path> <remote-path>` | Upload file to remote |

## Worker management

| Command | Description |
|---------|-------------|
| `bridge.sh worker-start` | Start background worker (polls inbox every 10s) |
| `bridge.sh worker-stop` | Stop background worker |
| `bridge.sh worker-status` | Check worker and queue status |

## General

| Command | Description |
|---------|-------------|
| `bridge.sh ssh "cmd"` | Run any command on remote server |
| `bridge.sh help` | Show help |

## Task JSON format

Tasks in `inbox/`:
```json
{
  "id": "task-1234-5678",
  "prompt": "check disk usage",
  "continue": false,
  "ts": "2026-04-13T15:00:00"
}
```

Results in `outbox/`:
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
