# Customization

## Server config file

Each server has a config at `.claude-bridge/servers/<name>.conf`:

```bash
SSH_TARGET="user@hostname"
SSH_PORT="22"
SSH_KEY="/path/to/key"
BRIDGE="/home/user/claude-bridge"
EXTRA_TOOLS="Bash(mycli:*) Bash(kubectl:*)"    # optional
SKIP_PERMISSIONS="true"                         # optional
```

### EXTRA_TOOLS

Add server-specific CLI tools the remote Claude is allowed to use:

```bash
EXTRA_TOOLS="Bash(kubectl:*) Bash(helm:*)"
```

### SKIP_PERMISSIONS

Set to `"true"` to pass `--dangerously-skip-permissions` to the remote Claude:

```bash
SKIP_PERMISSIONS="true"
```

## Server context

Edit `~/claude-workspace/CLAUDE.md` on the remote to give the bridge agent context about what's installed.

## Environment variables (on remote)

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_BRIDGE_DIR` | `~/claude-bridge` | Bridge directory |
| `CLAUDE_BRIDGE_WORKSPACE` | `~/claude-workspace` | Working directory |
| `CLAUDE_BRIDGE_BIN` | `~/.local/bin/claude` | Claude binary path |
| `CLAUDE_BRIDGE_SESSION` | `claude-bridge` | Session name for continuity |
| `CLAUDE_BRIDGE_ALLOWED_TOOLS` | (see source) | Override allowed tools for async mode |

## Multi-server

Run `setup.sh` multiple times with different `--name` values. Each server gets its own `.conf` file. Use `bridge.sh <server> <command>` to target a specific server, or `bridge.sh default <server>` to change the default.
