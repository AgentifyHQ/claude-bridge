# Customization

After running `setup.sh`, customize the bridge for your server.

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

Add server-specific CLI tools the remote Claude is allowed to use. These are prepended to the default allowed tools.

```bash
# Example: server running Kubernetes
EXTRA_TOOLS="Bash(kubectl:*) Bash(helm:*)"

# Example: server running a custom CLI
EXTRA_TOOLS="Bash(mycli:*)"
```

### SKIP_PERMISSIONS

Set to `"true"` to pass `--dangerously-skip-permissions` to the remote Claude. This prevents permission prompts that would block non-interactive execution.

```bash
SKIP_PERMISSIONS="true"
```

## Add server context

Edit `~/claude-workspace/CLAUDE.md` on the remote to give the bridge agent context about what's installed:

```markdown
## Server-specific tools

This server runs a Kubernetes cluster. Available CLIs:

    kubectl get pods
    helm list
    docker ps
```

This helps the remote Claude know what tools are available without being told each time.

## Environment variables (on remote)

Set these on the remote server (e.g., in `~/.bashrc`) to override defaults:

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_BRIDGE_DIR` | `~/claude-bridge` | Bridge directory |
| `CLAUDE_BRIDGE_WORKSPACE` | `~/claude-workspace` | Working directory |
| `CLAUDE_BRIDGE_BIN` | `~/.local/bin/claude` | Claude binary path |
| `CLAUDE_BRIDGE_SESSION` | `claude-bridge` | Session name for continuity |
| `CLAUDE_BRIDGE_ALLOWED_TOOLS` | (see source) | Override allowed tools for async mode |

## Reporting

The remote agent is instructed (via CLAUDE.md) to provide structured reports:

1. **What it did** — commands run, files modified, actions taken
2. **What it found** — results, status, errors, data
3. **What needs attention** — warnings, recommendations, follow-up actions

Customize the reporting format by editing `~/claude-workspace/CLAUDE.md` on the remote.
