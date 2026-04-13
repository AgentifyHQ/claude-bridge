# Multi-server Setup

## One server per project

The simplest approach — run setup from different project folders:

```bash
cd ~/project-a
~/claude-bridge/setup.sh admin@10.0.1.50

cd ~/project-b
~/claude-bridge/setup.sh deploy@prod.example.com --port 2222

cd ~/homelab
~/claude-bridge/setup.sh pi@192.168.1.100
```

Each project gets its own `.claude-bridge/` with config for its server.

## Multiple servers in one project

Run setup multiple times from the same folder. Each run overwrites `.claude-bridge/`, so if you need multiple servers in one project:

1. Run setup for the first server
2. Rename `.claude-bridge/` to `.claude-bridge-<name>/`
3. Run setup for the next server
4. Repeat

Or manually duplicate and edit the generated `bridge.sh` files.

## Claude Code with multiple servers

To give Claude Code access to multiple servers, merge the `.mcp.json` entries manually:

```json
{
  "mcpServers": {
    "ssh-server-a": {
      "command": "npx",
      "args": ["-y", "ssh-mcp", "--", "--host=10.0.1.50", "--user=admin", "--key=~/.ssh/id_ed25519"]
    },
    "ssh-server-b": {
      "command": "npx",
      "args": ["-y", "ssh-mcp", "--", "--host=prod.example.com", "--user=deploy", "--key=~/.ssh/id_ed25519"]
    }
  }
}
```

Each server gets its own namespaced MCP tools (e.g., `mcp__ssh-server-a__exec`, `mcp__ssh-server-b__exec`), so Claude can talk to all of them in one session.
