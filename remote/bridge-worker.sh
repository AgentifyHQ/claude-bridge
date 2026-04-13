#!/bin/bash
# Bridge Worker: watches inbox and processes tasks via Claude Code
# Usage: ./bridge-worker.sh [--once] [--watch] [--interval N]
#   --once:     process all pending tasks and exit
#   --watch:    loop continuously (default)
#   --interval: seconds between polls (default: 10)

export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INTERVAL=10

# Parse args
MODE="watch"
while [[ $# -gt 0 ]]; do
    case $1 in
        --once) MODE="once"; shift ;;
        --watch) MODE="watch"; shift ;;
        --interval) INTERVAL="$2"; shift 2 ;;
        *) shift ;;
    esac
done

case "$MODE" in
    once)
        python3 "$SCRIPT_DIR/process_tasks.py"
        ;;
    watch)
        echo "[$(date -Iseconds)] Bridge worker started (interval=${INTERVAL}s)"
        while true; do
            python3 "$SCRIPT_DIR/process_tasks.py"
            sleep "$INTERVAL"
        done
        ;;
esac
