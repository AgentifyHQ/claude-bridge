#!/bin/bash
set -e

# claude-bridge: Set up a Claude Code bridge to a remote server
# Usage: ./setup.sh [user@host] [--key path] [--port 22] [--name my-server]

print_usage() {
    echo "Usage: ./setup.sh user@host [options]"
    echo ""
    echo "Options:"
    echo "  --key PATH       SSH key path (default: ~/.ssh/id_ed25519)"
    echo "  --port PORT      SSH port (default: 22)"
    echo "  --name NAME      Server name for session/config (default: derived from host)"
    echo "  --bridge-dir DIR Remote bridge directory (default: ~/claude-bridge)"
    echo "  --workspace DIR  Remote workspace directory (default: ~/claude-workspace)"
    echo "  --no-install     Skip Claude Code installation on remote"
    echo "  --help           Show this help"
}

# Defaults
SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_PORT=22
BRIDGE_DIR="~/claude-bridge"
WORKSPACE_DIR="~/claude-workspace"
INSTALL_CLAUDE=true
SERVER_NAME=""

# Parse user@host
if [ -z "$1" ] || [[ "$1" == --* ]]; then
    print_usage
    exit 1
fi

TARGET="$1"
shift

SSH_USER="${TARGET%@*}"
SSH_HOST="${TARGET#*@}"

if [ "$SSH_USER" = "$SSH_HOST" ]; then
    echo "Error: Please specify user@host"
    exit 1
fi

# Parse options
while [[ $# -gt 0 ]]; do
    case $1 in
        --key) SSH_KEY="$2"; shift 2 ;;
        --port) SSH_PORT="$2"; shift 2 ;;
        --name) SERVER_NAME="$2"; shift 2 ;;
        --bridge-dir) BRIDGE_DIR="$2"; shift 2 ;;
        --workspace) WORKSPACE_DIR="$2"; shift 2 ;;
        --no-install) INSTALL_CLAUDE=false; shift ;;
        --help) print_usage; exit 0 ;;
        *) echo "Unknown option: $1"; print_usage; exit 1 ;;
    esac
done

# Derive server name if not set
if [ -z "$SERVER_NAME" ]; then
    SERVER_NAME=$(echo "$SSH_HOST" | sed 's/[^a-zA-Z0-9]/-/g')
fi

SSH_CMD="ssh -p $SSH_PORT -i $SSH_KEY $TARGET"

echo "=== claude-bridge setup ==="
echo "  Target: $TARGET"
echo "  SSH Key: $SSH_KEY"
echo "  Port: $SSH_PORT"
echo "  Name: $SERVER_NAME"
echo "  Bridge Dir: $BRIDGE_DIR"
echo "  Workspace: $WORKSPACE_DIR"
echo ""

# Test SSH connection
echo "[1/6] Testing SSH connection..."
$SSH_CMD "hostname" || { echo "SSH connection failed."; exit 1; }

# Install Claude Code on remote
if [ "$INSTALL_CLAUDE" = true ]; then
    echo "[2/6] Installing Claude Code on remote..."
    $SSH_CMD "
        if command -v claude >/dev/null 2>&1 || [ -f ~/.local/bin/claude ]; then
            echo 'Claude Code already installed: '\$(~/.local/bin/claude --version 2>/dev/null || claude --version)
        else
            curl -fsSL https://claude.ai/install.sh | bash
            echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc
            echo 'Installed: '\$(~/.local/bin/claude --version)
        fi
    "
else
    echo "[2/6] Skipping Claude Code installation (--no-install)"
fi

# Resolve remote paths
REMOTE_HOME=$($SSH_CMD "echo \$HOME")
RESOLVED_BRIDGE=$(echo "$BRIDGE_DIR" | sed "s|~|$REMOTE_HOME|")
RESOLVED_WORKSPACE=$(echo "$WORKSPACE_DIR" | sed "s|~|$REMOTE_HOME|")

# Create remote directories
echo "[3/6] Creating remote directories..."
$SSH_CMD "mkdir -p $RESOLVED_BRIDGE/{inbox,outbox} $RESOLVED_WORKSPACE"

# Deploy bridge worker
echo "[4/6] Deploying bridge worker..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
scp -P "$SSH_PORT" -i "$SSH_KEY" \
    "$SCRIPT_DIR/remote/process_tasks.py" \
    "$SCRIPT_DIR/remote/bridge-worker.sh" \
    "$SCRIPT_DIR/remote/submit_task.py" \
    "$TARGET:$RESOLVED_BRIDGE/"

$SSH_CMD "chmod +x $RESOLVED_BRIDGE/bridge-worker.sh $RESOLVED_BRIDGE/process_tasks.py $RESOLVED_BRIDGE/submit_task.py"

# Deploy workspace CLAUDE.md
echo "[5/6] Deploying workspace CLAUDE.md..."
HOSTNAME=$($SSH_CMD "hostname")
sed \
    -e "s|{{HOSTNAME}}|$HOSTNAME|g" \
    -e "s|{{HOST}}|$SSH_HOST|g" \
    -e "s|{{USER}}|$SSH_USER|g" \
    -e "s|{{BRIDGE_DIR}}|$RESOLVED_BRIDGE|g" \
    -e "s|{{WORKSPACE_DIR}}|$RESOLVED_WORKSPACE|g" \
    "$SCRIPT_DIR/remote/CLAUDE.md.template" | \
    $SSH_CMD "cat > $RESOLVED_WORKSPACE/CLAUDE.md"

# Generate local config
echo "[6/6] Generating local configuration..."

FULL_SSH_KEY=$(eval echo "$SSH_KEY")
LOCAL_DIR="$(pwd)/.claude-bridge"
mkdir -p "$LOCAL_DIR"

# Generate .mcp.json
cat > "$LOCAL_DIR/.mcp.json" << MCPEOF
{
  "mcpServers": {
    "ssh-$SERVER_NAME": {
      "command": "npx",
      "args": [
        "-y",
        "ssh-mcp",
        "--",
        "--host=$SSH_HOST",
        "--user=$SSH_USER",
        "--key=$FULL_SSH_KEY",
        "--port=$SSH_PORT",
        "--maxChars=none"
      ]
    }
  }
}
MCPEOF

BRIDGE="$REMOTE_HOME/claude-bridge"

# Generate bridge.sh CLI
sed \
    -e "s|{{TARGET}}|$TARGET|g" \
    -e "s|{{PORT}}|$SSH_PORT|g" \
    -e "s|{{KEY}}|$FULL_SSH_KEY|g" \
    -e "s|{{BRIDGE}}|$BRIDGE|g" \
    "$SCRIPT_DIR/remote/bridge-cli.sh" > "$LOCAL_DIR/bridge.sh"
chmod +x "$LOCAL_DIR/bridge.sh"

# Deploy plugin + skill into .claude-bridge/ so it's self-contained
mkdir -p "$LOCAL_DIR/.claude-plugin"
cp "$SCRIPT_DIR/.claude-plugin/plugin.json" "$LOCAL_DIR/.claude-plugin/"
cp -r "$SCRIPT_DIR/skills" "$LOCAL_DIR/"

# Merge ssh-mcp config into project .mcp.json
MCP_JSON="$(pwd)/.mcp.json"
python3 -c "
import json, os
new_servers = json.load(open('$LOCAL_DIR/.mcp.json'))['mcpServers']
existing = {}
if os.path.exists('$MCP_JSON'):
    with open('$MCP_JSON') as f:
        existing = json.load(f)
servers = existing.get('mcpServers', {})
servers.update(new_servers)
existing['mcpServers'] = servers
with open('$MCP_JSON', 'w') as f:
    json.dump(existing, f, indent=2)
"

# Merge pluginDirs into .claude/settings.json
CLAUDE_SETTINGS="$(pwd)/.claude/settings.json"
mkdir -p "$(pwd)/.claude"
python3 -c "
import json, os
existing = {}
if os.path.exists('$CLAUDE_SETTINGS'):
    with open('$CLAUDE_SETTINGS') as f:
        existing = json.load(f)
dirs = existing.get('pluginDirs', [])
if '.claude-bridge' not in dirs:
    dirs.append('.claude-bridge')
existing['pluginDirs'] = dirs
with open('$CLAUDE_SETTINGS', 'w') as f:
    json.dump(existing, f, indent=2)
"

echo ""
echo "=== Setup complete ==="
echo ""
echo "Generated:"
echo "  .claude-bridge/    — bridge CLI, skill, and plugin"
echo "  .mcp.json          — ssh-mcp config for Claude Code"
echo "  .claude/settings.json — plugin registered"
echo ""
echo "Quick start:"
echo "  .claude-bridge/bridge.sh ask 'hello'"
echo "  .claude-bridge/bridge.sh ask -c 'follow-up question'"
echo "  .claude-bridge/bridge.sh send 'async task'"
echo "  .claude-bridge/bridge.sh process"
echo "  .claude-bridge/bridge.sh results"
echo ""
echo "NOTE: SSH into $TARGET and run 'claude' to authenticate if not already done."
echo "      Restart Claude Code to load the skill and MCP server."
