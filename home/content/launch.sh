#!/bin/bash

# 1. Kill any existing stale sessions
tmux kill-session -t openclaw 2>/dev/null

# 2. Start a new detached tmux session
# We use 'op run' to inject the secrets from your .env file
tmux new-session -d -s openclaw "op run --env-file=.env -- openclaw gateway --port 18789"

echo "🚀 OpenClaw is launching in a background tmux session."
echo "Use 'tmux attach -t openclaw' to see the live logs."
