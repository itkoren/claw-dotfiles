#!/usr/bin/env bash
set -eu

AGENT_DIR="$HOME/.config/op"
AGENT_SOCK="$AGENT_DIR/agent.sock"

mkdir -p "$AGENT_DIR"

if [ ! -S "$AGENT_SOCK" ]; then
  echo "Starting 1Password SSH agent..."
  op ssh-agent --socket "$AGENT_SOCK" &
fi
