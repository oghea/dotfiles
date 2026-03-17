#!/usr/bin/env bash
set -euo pipefail

echo "==> Saving tmux sessions..."
~/.config/tmux/plugins/tmux-resurrect/scripts/save.sh

echo "==> Stopping pm2 processes..."
pm2 stop all 2>/dev/null || true

echo "==> Stopping Docker containers..."
docker stop $(docker ps -q) 2>/dev/null || true

echo "==> Done. You can close your terminal."
