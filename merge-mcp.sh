#!/bin/bash
# Merge all server .mcp.json files into a single combined .mcp.json
# Usage: ./merge-mcp.sh [output-path]
#   output-path defaults to ./servers/.mcp.json

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT="${1:-$SCRIPT_DIR/servers/.mcp.json}"

# Collect all server .mcp.json files
FILES=$(find "$SCRIPT_DIR/servers" -mindepth 2 -name ".mcp.json" 2>/dev/null)

if [ -z "$FILES" ]; then
    echo "No server configs found in $SCRIPT_DIR/servers/"
    exit 1
fi

# Merge using python
python3 -c "
import json, glob, os

servers_dir = '$SCRIPT_DIR/servers'
merged = {'mcpServers': {}}

for mcp_file in sorted(glob.glob(os.path.join(servers_dir, '*', '.mcp.json'))):
    with open(mcp_file) as f:
        data = json.load(f)
    merged['mcpServers'].update(data.get('mcpServers', {}))

with open('$OUTPUT', 'w') as f:
    json.dump(merged, f, indent=2)

names = list(merged['mcpServers'].keys())
print('Merged ' + str(len(names)) + ' server(s): ' + ', '.join(names))
print('Written to: $OUTPUT')
"
