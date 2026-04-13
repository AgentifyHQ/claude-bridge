# Local Cross-Folder Communication

For local-to-local communication (folder A to folder B on the same machine), you don't need claude-bridge. Claude Code has this built in.

## Using the Agent tool

In your Claude Code session, launch a subagent that works in another directory:

```
Agent: "Go to /path/to/other-project and check the test results"
```

The Agent tool spawns a fresh Claude instance as a subprocess — effectively a local bridge without any infrastructure.

## Using claude -p

Run Claude non-interactively against another directory:

```bash
cd /path/to/folder-b && claude -p "check test results"
```

Add access to multiple directories:

```bash
claude -p "compare configs" --add-dir /path/to/folder-a --add-dir /path/to/folder-b
```

## Using --add-dir in an interactive session

```bash
claude --add-dir /path/to/folder-b
# Now Claude can read/write both the current directory and folder-b
```

## When to use claude-bridge instead

Use claude-bridge when you need to cross machine boundaries over SSH. For anything on the same machine, the built-in tools above are simpler and faster.
