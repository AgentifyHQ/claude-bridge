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
LOCAL_DIR="$SCRIPT_DIR/servers/$SERVER_NAME"
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

# Generate justfile — hardcode values to avoid just/bash interpolation conflicts
SSH="ssh -p $SSH_PORT -i $SSH_KEY $TARGET"
BRIDGE="$REMOTE_HOME/claude-bridge"
cat > "$LOCAL_DIR/justfile" << JUSTEOF
# Claude Bridge: $SERVER_NAME ($TARGET)

# Run a command on the remote server
ssh-cmd cmd:
    $SSH "{{cmd}}"

# Send a new task (fresh session)
send-task prompt:
    $SSH "python3 $BRIDGE/submit_task.py '{{prompt}}'"

# Send a follow-up (continues previous session)
follow-up prompt:
    $SSH "python3 $BRIDGE/submit_task.py '{{prompt}}' --continue"

# Check for completed results
check-results:
    $SSH "for f in $BRIDGE/outbox/*.json; do [ -f \"\\\$f\" ] && echo \"=== \\\$(basename \\\$f) ===\" && cat \"\\\$f\" && echo; done 2>/dev/null || echo 'No results yet.'"

# Read a specific result
read-result id:
    $SSH "cat $BRIDGE/outbox/{{id}}.json 2>/dev/null || echo 'Result not found: {{id}}'"

# Clear results
clear-results:
    $SSH "rm -f $BRIDGE/outbox/*.json && echo 'Outbox cleared.'"

# Process pending tasks once
process-once:
    $SSH "export PATH=\\\$HOME/.local/bin:\\\$HOME/.npm-global/bin:\\\$PATH && python3 $BRIDGE/process_tasks.py"

# Start background worker
start-worker-bg:
    $SSH "nohup $BRIDGE/bridge-worker.sh --watch > $BRIDGE/worker.log 2>&1 &"
    echo "Worker started. Logs: just ssh-cmd 'tail -f $BRIDGE/worker.log'"

# Stop background worker
stop-worker:
    $SSH "pkill -f 'bridge-worker.sh --watch' && echo 'Worker stopped.' || echo 'No worker running.'"

# Worker status
worker-status:
    $SSH "pgrep -f bridge-worker.sh > /dev/null && echo 'Worker: RUNNING' || echo 'Worker: STOPPED'; echo 'Pending:' \\\$(ls $BRIDGE/inbox/*.json 2>/dev/null | wc -l); echo 'Completed:' \\\$(ls $BRIDGE/outbox/*.json 2>/dev/null | wc -l)"
JUSTEOF

# Generate bridge.sh CLI — zero-dependency alternative to justfile
sed \
    -e "s|{{TARGET}}|$TARGET|g" \
    -e "s|{{PORT}}|$SSH_PORT|g" \
    -e "s|{{KEY}}|$FULL_SSH_KEY|g" \
    -e "s|{{BRIDGE}}|$BRIDGE|g" \
    "$SCRIPT_DIR/remote/bridge-cli.sh" > "$LOCAL_DIR/bridge.sh"
chmod +x "$LOCAL_DIR/bridge.sh"

echo ""
echo "=== Setup complete ==="
echo ""
echo "Generated files:"
echo "  $LOCAL_DIR/bridge.sh    — CLI (no dependencies, just bash+ssh)"
echo "  $LOCAL_DIR/justfile     — justfile (if you have just installed)"
echo "  $LOCAL_DIR/.mcp.json    — ssh-mcp config (for Claude Code integration)"
echo ""
echo "Quick start (no dependencies):"
echo "  $LOCAL_DIR/bridge.sh send 'hello'"
echo "  $LOCAL_DIR/bridge.sh process"
echo "  $LOCAL_DIR/bridge.sh results"
echo ""
echo "With just:"
echo "  just -f $LOCAL_DIR/justfile send-task 'hello'"
echo ""
echo "With Claude Code:"
echo "  cp $LOCAL_DIR/.mcp.json /path/to/project/"
echo "  # Restart Claude Code to load ssh-mcp"
echo ""
echo "NOTE: SSH into $TARGET and run 'claude' to authenticate if not already done."
