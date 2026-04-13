# Claude Code Integration

Setup automatically merges an [ssh-mcp](https://github.com/tufantunc/ssh-mcp) entry into your project's `.mcp.json` and installs a Claude Code skill to `~/.claude/skills/claude-bridge/`. After restarting Claude Code, everything is ready.

## What it provides

### MCP tools (ssh-mcp)

Two MCP tools per server become available:

- `mcp__ssh-<name>__exec` — run a command on the remote server
- `mcp__ssh-<name>__sudo-exec` — run a command with sudo on the remote server

Your local Claude can use these directly in conversation to inspect, manage, and operate the remote server.

### Skill

The Claude Code skill teaches your agent how to use bridge.sh. When you mention remote servers, Claude will automatically know how to run bridge commands.

## When to use ssh-mcp vs bridge.sh

- **ssh-mcp** — when you're in an interactive Claude Code session and want Claude to directly run commands on the remote. Best for exploration, debugging, and ad-hoc tasks.
- **bridge.sh** — when you want the remote Claude to think autonomously about a task and report back. Best for complex tasks that benefit from the remote agent's CLAUDE.md context and reporting format.

Both can coexist — ssh-mcp for direct commands, bridge.sh for delegated tasks.
