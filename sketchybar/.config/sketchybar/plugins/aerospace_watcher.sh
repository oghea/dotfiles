#!/usr/bin/env bash
# Watches AeroSpace window/focus state and triggers the sketchybar
# aerospace_windows_change event when anything changes. Started by
# aerospace's after-startup-command.

# Kill any previous instance of this watcher. Match by process name rather
# than a /tmp lockfile — macOS purges /tmp after ~3 days, which let stale
# watchers pile up across AeroSpace restarts. The pattern requires a bash
# interpreter before the script path so editors/pagers with the file open
# (vim, tail -f, …) are never matched.
for pid in $(pgrep -f "bash .*/aerospace_watcher.sh"); do
  [ "$pid" != "$$" ] && kill "$pid" 2>/dev/null
done

source "$(dirname "$0")/lib.sh"

PREV=""
while true; do
  WINDOWS="$(list_windows_sorted)"
  WS="$(focused_workspace)"
  SNAP="$WINDOWS
$(focused_window_id)
$WS"
  # WS non-empty = aerospace CLI is alive, even with zero windows open.
  # A dead/errored CLI (empty WS) holds the last good state instead.
  if [ -n "$WS" ] && [ "$SNAP" != "$PREV" ]; then
    /opt/homebrew/bin/sketchybar --trigger aerospace_windows_change
    PREV="$SNAP"
  fi
  sleep 0.5
done
