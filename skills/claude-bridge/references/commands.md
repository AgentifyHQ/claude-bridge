# Commands Reference

All commands go through `.claude-bridge/bridge.sh`.

## Synchronous

| Command | Description |
|---------|-------------|
| `bridge.sh ask "prompt"` | Ask remote Claude, get response immediately |
| `bridge.sh ask -c "prompt"` | Follow-up (continues previous session) |

## Async

| Command | Description |
|---------|-------------|
| `bridge.sh send "prompt"` | Queue a new task |
| `bridge.sh follow-up "prompt"` | Queue a follow-up (continues session) |
| `bridge.sh process` | Process all pending tasks |
| `bridge.sh results` | Show all completed results |
| `bridge.sh read <task-id>` | Read a specific result |
| `bridge.sh clear` | Clear all results |

## File Transfer

| Command | Description |
|---------|-------------|
| `bridge.sh pull <remote-path> <local-path>` | Download file from remote |
| `bridge.sh push <local-path> <remote-path>` | Upload file to remote |

## Worker Management

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

## Task JSON Format

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

## How Sync Mode Works

```
bridge.sh ask "prompt"
  -> ssh user@host "claude -p 'prompt' --allowedTools '...' -n claude-bridge"
  -> remote Claude runs, output streams to stdout
  -> result printed locally
```

## How Async Mode Works

```
bridge.sh send "prompt"
  -> ssh: python3 submit_task.py "prompt"
  -> task JSON written to inbox/

bridge.sh process
  -> ssh: python3 process_tasks.py
  -> reads inbox, runs claude -p for each task
  -> writes results to outbox, removes from inbox

bridge.sh results
  -> ssh: cat outbox/*.json
```
