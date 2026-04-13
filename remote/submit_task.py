#!/usr/bin/env python3
"""Submit a task to the bridge inbox. Usage: submit_task.py <prompt> [--continue]"""

import json
import os
import sys
import time
import random
from datetime import datetime
from pathlib import Path

BRIDGE_DIR = Path(os.environ.get("CLAUDE_BRIDGE_DIR", os.path.expanduser("~/claude-bridge")))
INBOX = BRIDGE_DIR / "inbox"


def main():
    if len(sys.argv) < 2:
        print("Usage: submit_task.py <prompt> [--continue]", file=sys.stderr)
        sys.exit(1)

    prompt = sys.argv[1]
    do_continue = "--continue" in sys.argv

    task_id = f"task-{int(time.time())}-{random.randint(1000, 9999)}"

    task = {
        "id": task_id,
        "prompt": prompt,
        "continue": do_continue,
        "ts": datetime.now().isoformat(),
    }

    INBOX.mkdir(parents=True, exist_ok=True)
    task_path = INBOX / f"{task_id}.json"
    with open(task_path, "w") as f:
        json.dump(task, f, indent=2)

    print(task_id)


if __name__ == "__main__":
    main()
