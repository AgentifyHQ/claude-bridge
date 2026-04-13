# Multi-server Setup

## Adding servers

Run `setup.sh` multiple times from the same project folder with different `--name` values:

```bash
cd ~/my-project
/path/to/claude-bridge/setup.sh admin@10.0.1.50 --name file-server
/path/to/claude-bridge/setup.sh deploy@prod.example.com --name prod --port 2222
/path/to/claude-bridge/setup.sh pi@192.168.1.100 --name homelab
```

Each run:
- Adds a server config to `.claude-bridge/servers/<name>.conf`
- Merges the ssh-mcp entry into `.mcp.json`
- Sets the first server as default

## Using multiple servers

```bash
# Use default server (first one added, or set with `default`)
bridge.sh ask "check status"

# Use a specific server
bridge.sh prod ask "check deployments"
bridge.sh homelab ssh "df -h"
bridge.sh file-server pull /data/report.csv ./

# List all servers
bridge.sh servers

# Change default
bridge.sh default prod
```

With justfile:
```bash
# justfile commands use the default server
just ask "check status"

# For a specific server, use bridge.sh directly
.claude-bridge/bridge.sh prod ask "check deployments"
```

## What gets created

```
.claude-bridge/
├── bridge.sh               # single CLI for all servers
├── servers/
│   ├── file-server.conf    # SSH_TARGET, SSH_KEY, EXTRA_TOOLS, etc.
│   ├── prod.conf
│   ├── homelab.conf
│   └── .default            # contains "file-server"
```

## Claude Code with multiple servers

Each `setup.sh` run merges a new MCP server entry into `.mcp.json`. After adding all servers, Claude Code has access to all of them simultaneously:

- `mcp__ssh-file-server__exec` — run commands on file-server
- `mcp__ssh-prod__exec` — run commands on prod
- `mcp__ssh-homelab__exec` — run commands on homelab

## Per-server customization

Each server can have its own `EXTRA_TOOLS` and `SKIP_PERMISSIONS` in its `.conf` file. See [Customization](customization.md) for details.
