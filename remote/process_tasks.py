#!/usr/bin/env python3
"""Bridge task processor: reads tasks from inbox/, runs Claude Code, writes results to outbox/."""

import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

# Configuration — override via environment variables
BRIDGE_DIR = Path(os.environ.get("CLAUDE_BRIDGE_DIR", os.path.expanduser("~/claude-bridge")))
WORKSPACE = Path(os.environ.get("CLAUDE_BRIDGE_WORKSPACE", os.path.expanduser("~/claude-workspace")))
CLAUDE_BIN = os.environ.get("CLAUDE_BRIDGE_BIN", os.path.expanduser("~/.local/bin/claude"))
SESSION_NAME = os.environ.get("CLAUDE_BRIDGE_SESSION", "claude-bridge")

INBOX = BRIDGE_DIR / "inbox"
OUTBOX = BRIDGE_DIR / "outbox"

# Default allowed tools — customize per server by setting CLAUDE_BRIDGE_ALLOWED_TOOLS
DEFAULT_ALLOWED_TOOLS = " ".join([
    "Bash(ls:*)", "Bash(cat:*)", "Bash(df:*)", "Bash(ps:*)",
    "Bash(docker:*)", "Bash(systemctl:*)", "Bash(uname:*)",
    "Bash(hostname:*)", "Bash(uptime:*)", "Bash(free:*)",
    "Bash(head:*)", "Bash(tail:*)", "Bash(wc:*)",
    "Bash(grep:*)", "Bash(find:*)",
    "Read", "Write", "Edit", "Glob", "Grep",
])
ALLOWED_TOOLS = os.environ.get("CLAUDE_BRIDGE_ALLOWED_TOOLS", DEFAULT_ALLOWED_TOOLS)


def process_task(task_path: Path) -> None:
    """Process a single task file."""
    with open(task_path) as f:
        task = json.load(f)

    task_id = task["id"]
    prompt = task["prompt"]
    do_continue = task.get("continue", False)
    extra_tools = task.get("extra_tools", "")

    print(f"[{datetime.now().isoformat()}] Processing: {task_id} (continue={do_continue})")

    # Build command
    tools = f"{ALLOWED_TOOLS} {extra_tools}".strip()
    cmd = [
        CLAUDE_BIN, "-p", prompt,
        "--allowedTools", tools,
        "-n", SESSION_NAME,
    ]
    if do_continue:
        cmd.append("--continue")

    # Run Claude
    env = os.environ.copy()
    env["PATH"] = f"{Path.home() / '.local/bin'}:{Path.home() / '.npm-global/bin'}:{env.get('PATH', '')}"

    proc = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        cwd=str(WORKSPACE),
        env=env,
    )

    result_text = proc.stdout.strip()
    if proc.stderr.strip():
        result_text += f"\n\n[stderr]\n{proc.stderr.strip()}"

    # Write result
    result = {
        "id": task_id,
        "prompt": prompt,
        "continue": do_continue,
        "result": result_text,
        "exit_code": proc.returncode,
        "ts": datetime.now().isoformat(),
    }

    out_path = OUTBOX / f"{task_id}.json"
    with open(out_path, "w") as f:
        json.dump(result, f, indent=2)

    # Remove processed task
    task_path.unlink()
    print(f"[{datetime.now().isoformat()}] Completed: {task_id} -> {out_path}")


def main():
    """Process all pending tasks in inbox."""
    if not INBOX.exists():
        print(f"Inbox not found: {INBOX}")
        return

    tasks = sorted(INBOX.glob("*.json"))
    if not tasks:
        print("No pending tasks.")
        return

    for task_path in tasks:
        try:
            process_task(task_path)
        except Exception as e:
            print(f"[{datetime.now().isoformat()}] Error processing {task_path.name}: {e}")
            # Move failed task to outbox with error
            try:
                with open(task_path) as f:
                    task = json.load(f)
                error_result = {
                    "id": task.get("id", task_path.stem),
                    "prompt": task.get("prompt", ""),
                    "result": f"Error: {e}",
                    "exit_code": -1,
                    "ts": datetime.now().isoformat(),
                }
                with open(OUTBOX / f"{task_path.stem}.json", "w") as f:
                    json.dump(error_result, f, indent=2)
                task_path.unlink()
            except Exception:
                pass


if __name__ == "__main__":
    main()
