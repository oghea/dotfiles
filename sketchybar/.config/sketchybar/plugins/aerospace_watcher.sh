#!/usr/bin/env bash

# Kill any previous instance of this watcher
LOCKFILE="/tmp/aerospace_watcher.pid"
if [ -f "$LOCKFILE" ]; then
  kill "$(cat "$LOCKFILE")" 2>/dev/null
fi
echo $$ > "$LOCKFILE"

PREV=""
while true; do
  CURRENT="$(/opt/homebrew/bin/aerospace list-workspaces --focused 2>/dev/null)"
  if [ -n "$CURRENT" ] && [ "$CURRENT" != "$PREV" ]; then
    /opt/homebrew/bin/sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE="$CURRENT"
    PREV="$CURRENT"
  fi
  sleep 0.2
done
