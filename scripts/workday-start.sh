#!/usr/bin/env bash
set -euo pipefail

echo "==> Starting Colima (Docker)..."
colima start

echo "==> Waiting for Docker daemon..."
until docker info &>/dev/null; do sleep 1; done

echo "==> Starting previously stopped containers..."
docker start $(docker ps -aq --filter "status=exited") 2>/dev/null || true

echo "==> Starting pm2 processes..."
cd ~/Documents/repo/pm2 && pm2 start ecosystem.config.js

echo "==> Done!"
