#!/usr/bin/env bash
set -eu

PUB="$HOME/.ssh/id_ed25519.pub"

if [ ! -f "$PUB" ]; then
  exit 0
fi

TITLE="$(hostname)-dotfiles"

# Fetch GitHub token from 1Password
GH_TOKEN=$(op read "op://Claw/Github Access Token/credential")

curl -s \
  -H "Authorization: token $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/user/keys \
  -d "{\"title\":\"$TITLE\",\"key\":\"$(cat $PUB)\"}" \
  >/dev/null
