#!/usr/bin/env bash
set -eu

echo "Testing GitHub SSH..."

until ssh -o BatchMode=yes -T git@github.com 2>/dev/null; do
  echo "Waiting for GitHub authentication..."
  sleep 2
done
