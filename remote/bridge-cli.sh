#!/bin/bash
# Claude Bridge CLI — multi-server SSH bridge for Claude Code
# Usage: ./bridge.sh [server] <command> [args]

BRIDGE_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVERS_DIR="$BRIDGE_DIR/servers"

# --- Server resolution ---

load_server() {
    local name="$1"
    local conf="$SERVERS_DIR/$name.conf"
    if [ ! -f "$conf" ]; then
        echo "Unknown server: $name"
        echo "Available servers:"
        list_servers
        exit 1
    fi
    source "$conf"
    SSH="ssh -p $SSH_PORT -i $SSH_KEY $SSH_TARGET"
}

list_servers() {
    for f in "$SERVERS_DIR"/*.conf 2>/dev/null; do
        [ -f "$f" ] || continue
        local name=$(basename "$f" .conf)
        source "$f"
        echo "  $name  ($SSH_TARGET)"
    done
}

get_default_server() {
    local confs=("$SERVERS_DIR"/*.conf)
    if [ ${#confs[@]} -eq 0 ] || [ ! -f "${confs[0]}" ]; then
        echo ""
        return
    fi
    if [ ${#confs[@]} -eq 1 ]; then
        basename "${confs[0]}" .conf
        return
    fi
    # Multiple servers — check for default marker
    if [ -f "$SERVERS_DIR/.default" ]; then
        cat "$SERVERS_DIR/.default"
        return
    fi
    echo ""
}

# --- Usage ---

usage() {
    local default=$(get_default_server)
    cat << EOF
Claude Bridge CLI

Usage: ./bridge.sh [server] <command> [args]

Servers:
EOF
    list_servers
    if [ -n "$default" ]; then
        echo ""
        echo "Default server: $default"
    fi
    cat << 'EOF'

Commands:
  ask <prompt>           Ask remote Claude and wait for response (synchronous)
  ask -c <prompt>        Ask with session continuity (follow-up)
  send <prompt>          Queue a task (async, needs process/worker)
  follow-up <prompt>     Queue a follow-up task (async, continues session)
  process                Process all pending tasks once
  results                Show all completed results
  read <task-id>         Read a specific result
  clear                  Clear all results
  pull <remote> <local>  Download file from remote server
  push <local> <remote>  Upload file to remote server
  worker-start           Start background worker
  worker-stop            Stop background worker
  worker-status          Check worker and queue status
  ssh <cmd>              Run any command on remote
  servers                List available servers
  default <server>       Set default server
  help                   Show this help
EOF
}

# --- Resolve server from args ---

COMMANDS="ask|send|follow-up|followup|process|results|read|clear|pull|push|worker-start|worker-stop|worker-status|ssh|servers|default|help"
SERVER=""
CMD=""

if [ $# -eq 0 ]; then
    usage
    exit 0
fi

# Check if first arg is a command or a server name
if echo "$1" | grep -qE "^($COMMANDS)$" || [[ "$1" == --* ]] || [[ "$1" == -* ]]; then
    # First arg is a command — use default server
    SERVER=$(get_default_server)
    CMD="$1"
else
    # First arg is a server name
    SERVER="$1"
    shift
    CMD="${1:-help}"
fi

# Commands that don't need a server
case "$CMD" in
    servers)
        echo "Available servers:"
        list_servers
        default=$(get_default_server)
        [ -n "$default" ] && echo "" && echo "Default: $default"
        exit 0
        ;;
    default)
        [ -z "$2" ] && echo "Usage: ./bridge.sh default <server>" && exit 1
        if [ ! -f "$SERVERS_DIR/$2.conf" ]; then
            echo "Unknown server: $2"
            list_servers
            exit 1
        fi
        echo "$2" > "$SERVERS_DIR/.default"
        echo "Default server set to: $2"
        exit 0
        ;;
    help|--help|-h)
        usage
        exit 0
        ;;
esac

# All other commands need a server
if [ -z "$SERVER" ]; then
    echo "Error: Multiple servers configured. Specify which one:"
    list_servers
    echo ""
    echo "Usage: ./bridge.sh <server> <command> [args]"
    echo "  Or set a default: ./bridge.sh default <server>"
    exit 1
fi

load_server "$SERVER"

# --- Commands ---

case "$CMD" in
    ask)
        shift
        CONTINUE_FLAG=""
        if [ "$1" = "-c" ]; then
            CONTINUE_FLAG="--continue"
            shift
        fi
        [ -z "$1" ] && echo "Usage: ./bridge.sh [$SERVER] ask [-c] <prompt>" && exit 1
        ALLOWED_TOOLS="Bash(ls:*) Bash(cat:*) Bash(df:*) Bash(ps:*) Bash(docker:*) Bash(systemctl:*) Bash(uname:*) Bash(hostname:*) Bash(uptime:*) Bash(free:*) Bash(head:*) Bash(tail:*) Bash(wc:*) Bash(grep:*) Bash(find:*) Read Write Edit Glob Grep"
        $SSH "export PATH=\$HOME/.local/bin:\$HOME/.npm-global/bin:\$PATH && cd \$HOME/claude-workspace && claude -p '$1' --allowedTools '$ALLOWED_TOOLS' -n claude-bridge $CONTINUE_FLAG"
        ;;
    send)
        [ -z "$2" ] && echo "Usage: ./bridge.sh [$SERVER] send <prompt>" && exit 1
        $SSH "python3 $BRIDGE/submit_task.py '$2'"
        ;;
    follow-up|followup)
        [ -z "$2" ] && echo "Usage: ./bridge.sh [$SERVER] follow-up <prompt>" && exit 1
        $SSH "python3 $BRIDGE/submit_task.py '$2' --continue"
        ;;
    process)
        $SSH "export PATH=\$HOME/.local/bin:\$HOME/.npm-global/bin:\$PATH && python3 $BRIDGE/process_tasks.py"
        ;;
    results)
        $SSH "for f in $BRIDGE/outbox/*.json; do [ -f \"\$f\" ] && echo \"=== \$(basename \$f) ===\" && cat \"\$f\" && echo; done 2>/dev/null || echo 'No results yet.'"
        ;;
    read)
        [ -z "$2" ] && echo "Usage: ./bridge.sh [$SERVER] read <task-id>" && exit 1
        $SSH "cat $BRIDGE/outbox/$2.json 2>/dev/null || echo 'Result not found: $2'"
        ;;
    clear)
        $SSH "rm -f $BRIDGE/outbox/*.json && echo 'Outbox cleared.'"
        ;;
    pull)
        [ -z "$2" ] || [ -z "$3" ] && echo "Usage: ./bridge.sh [$SERVER] pull <remote-path> <local-path>" && exit 1
        scp -P "$SSH_PORT" -i "$SSH_KEY" "$SSH_TARGET:$2" "$3"
        ;;
    push)
        [ -z "$2" ] || [ -z "$3" ] && echo "Usage: ./bridge.sh [$SERVER] push <local-path> <remote-path>" && exit 1
        scp -P "$SSH_PORT" -i "$SSH_KEY" "$2" "$SSH_TARGET:$3"
        ;;
    worker-start)
        $SSH "nohup $BRIDGE/bridge-worker.sh --watch > $BRIDGE/worker.log 2>&1 &"
        echo "Worker started on $SERVER. Check logs: ./bridge.sh $SERVER ssh 'tail -f $BRIDGE/worker.log'"
        ;;
    worker-stop)
        $SSH "pkill -f 'bridge-worker.sh --watch' && echo 'Worker stopped.' || echo 'No worker running.'"
        ;;
    worker-status)
        $SSH "pgrep -f bridge-worker.sh > /dev/null && echo 'Worker: RUNNING' || echo 'Worker: STOPPED'; echo \"Pending: \$(ls $BRIDGE/inbox/*.json 2>/dev/null | wc -l)\"; echo \"Completed: \$(ls $BRIDGE/outbox/*.json 2>/dev/null | wc -l)\""
        ;;
    ssh)
        [ -z "$2" ] && echo "Usage: ./bridge.sh [$SERVER] ssh <command>" && exit 1
        $SSH "$2"
        ;;
    *)
        echo "Unknown command: $CMD"
        usage
        exit 1
        ;;
esac
