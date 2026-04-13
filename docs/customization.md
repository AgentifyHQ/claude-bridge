# Customization

After running `setup.sh`, customize the bridge for your server.

## Add server-specific tools

By default, the remote Claude can run basic system commands (`ls`, `cat`, `df`, `ps`, `docker`, etc.) and use `Read`, `Write`, `Edit`, `Glob`, `Grep`.

To add server-specific tools, edit `.claude-bridge/bridge.sh` and prepend to the `ALLOWED_TOOLS` line:

```bash
ALLOWED_TOOLS="Bash(mycli:*) Bash(kubectl:*) Bash(ls:*) ..."
```

For async mode, also update `~/claude-bridge/process_tasks.py` on the remote server.

## Add server context

Edit `~/claude-workspace/CLAUDE.md` on the remote to give the bridge agent context about what's on the server. For example:

```markdown
## Server-specific tools

This server runs a Kubernetes cluster. Available CLIs:

    kubectl get pods
    helm list
    k9s
```

This helps the remote Claude know what tools are available and how to use them.

## Environment variables

Set these on the remote server to override defaults:

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

You can customize the reporting format by editing `~/claude-workspace/CLAUDE.md` on the remote.
