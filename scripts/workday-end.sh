#!/usr/bin/env bash
set -euo pipefail

echo "==> Stopping pm2 processes..."
pm2 delete all 2>/dev/null || true
pm2 kill 2>/dev/null || true

echo "==> Stopping Docker containers..."
if docker info >/dev/null 2>&1; then
  ids=$(docker ps -q)
  [ -n "$ids" ] && docker stop $ids || true
fi

echo "==> Stopping Colima..."
colima stop 2>/dev/null || true

echo "==> Quitting apps (gracefully)..."
osascript <<'EOF' 2>/dev/null || true
tell application "System Events"
  set keepApps to {"Finder", "ghostty"}
  repeat with p in (every process whose background only is false)
    set pname to name of p
    if keepApps does not contain pname then
      try
        tell application pname to quit
      end try
    end if
  end repeat
end tell
EOF

echo "==> Done. Killing tmux server (this closes the terminal)..."
tmux kill-server 2>/dev/null || true
