# Claude Code Integration

Setup generates a `.mcp.json` for [ssh-mcp](https://github.com/tufantunc/ssh-mcp), which gives your local Claude Code instance direct SSH access to the remote server.

## Setup

```bash
cp .claude-bridge/.mcp.json .
```

Then restart Claude Code (or reload MCP servers) to load it.

## What it provides

Two MCP tools become available:

- `exec` — run a command on the remote server
- `sudo-exec` — run a command with sudo on the remote server

Your local Claude can use these directly in conversation to inspect, manage, and operate the remote server without going through bridge.sh.

## When to use this vs bridge.sh

- **ssh-mcp** — when you're in an interactive Claude Code session and want Claude to directly run commands on the remote. Best for exploration, debugging, and ad-hoc tasks.
- **bridge.sh** — when you want the remote Claude to think autonomously about a task and report back. Best for complex tasks that benefit from the remote agent's CLAUDE.md context and reporting format.

Both can coexist — ssh-mcp for direct commands, bridge.sh for delegated tasks.
