# Justfile Integration

Add a justfile to your project that wraps `bridge.sh`:

```just
bridge := justfile_directory() / ".claude-bridge/bridge.sh"

# Ask remote Claude (synchronous)
ask prompt:
    {{bridge}} ask "{{prompt}}"

# Follow-up (continues previous session)
follow-up prompt:
    {{bridge}} ask -c "{{prompt}}"

# Queue async task
send prompt:
    {{bridge}} send "{{prompt}}"

# Process async tasks
process:
    {{bridge}} process

# Check results
results:
    {{bridge}} results

# File transfer
pull remote local:
    {{bridge}} pull "{{remote}}" "{{local}}"

push local remote:
    {{bridge}} push "{{local}}" "{{remote}}"

# Remote command
ssh-cmd cmd:
    {{bridge}} ssh "{{cmd}}"
```

Then use: `just ask "check disk usage"`

Requires [just](https://github.com/casey/just) to be installed.
