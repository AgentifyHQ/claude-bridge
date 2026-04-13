# Customization

## Adding Server-Specific Tools

By default, the remote Claude can run basic system commands (`ls`, `cat`, `df`, `ps`, `docker`, `systemctl`, etc.) and use `Read`, `Write`, `Edit`, `Glob`, `Grep`.

To add server-specific tools:

### For sync mode (bridge.sh ask)

Edit `.claude-bridge/bridge.sh` and prepend to the `ALLOWED_TOOLS` line:

```bash
ALLOWED_TOOLS="Bash(mycli:*) Bash(kubectl:*) Bash(ls:*) ..."
```

### For async mode (bridge.sh send/process)

Edit `~/claude-bridge/process_tasks.py` on the remote server. Find the `DEFAULT_ALLOWED_TOOLS` list and add entries:

```python
DEFAULT_ALLOWED_TOOLS = " ".join([
    "Bash(mycli:*)", "Bash(kubectl:*)",  # add here
    "Bash(ls:*)", "Bash(cat:*)", ...
])
```

## Customizing Remote Agent Context

Edit `~/claude-workspace/CLAUDE.md` on the remote server to give the bridge agent context about what's installed and how to use it:

```markdown
## Server-specific tools

This server runs a Kubernetes cluster. Available CLIs:

    kubectl get pods
    helm list
    docker ps
```

This helps the remote Claude know what tools are available without being told each time.

## Environment Variables

Set these on the remote server (e.g., in `~/.bashrc`) to override defaults:

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_BRIDGE_DIR` | `~/claude-bridge` | Bridge directory |
| `CLAUDE_BRIDGE_WORKSPACE` | `~/claude-workspace` | Working directory |
| `CLAUDE_BRIDGE_BIN` | `~/.local/bin/claude` | Claude binary path |
| `CLAUDE_BRIDGE_SESSION` | `claude-bridge` | Session name for continuity |
| `CLAUDE_BRIDGE_ALLOWED_TOOLS` | (see source) | Override allowed tools for async mode |

## Remote Directory Layout

```
~/claude-bridge/          # bridge infrastructure
├── inbox/                # async task queue
├── outbox/               # async results
├── process_tasks.py      # task processor
├── bridge-worker.sh      # background watcher
└── submit_task.py        # task submitter

~/claude-workspace/       # remote Claude's working directory
└── CLAUDE.md             # agent context + reporting guidelines
```

## Reporting Format

The remote agent is instructed to provide structured reports:

1. **What it did** — commands run, files modified, actions taken
2. **What it found** — results, status, errors, data
3. **What needs attention** — warnings, recommendations, follow-up actions

Customize by editing `~/claude-workspace/CLAUDE.md` on the remote.

## Multi-Server in One Project

Each `setup.sh` run overwrites `.claude-bridge/`. For multiple servers in one project, rename after each setup:

```bash
# Setup server A
setup.sh admin@server-a
mv .claude-bridge .claude-bridge-server-a

# Setup server B
setup.sh deploy@server-b
mv .claude-bridge .claude-bridge-server-b
```

For Claude Code ssh-mcp access to multiple servers, merge `.mcp.json` entries manually into a single file with different server names.
