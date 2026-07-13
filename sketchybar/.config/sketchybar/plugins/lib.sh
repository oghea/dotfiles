#!/usr/bin/env bash
# Shared helpers for the aerospace-driven app bar. The sort order defined
# here is the single source of truth for both the bar layout (app_bar.sh)
# and the cmd-alt-N jump keys (focus_nth.sh).

AEROSPACE=/opt/homebrew/bin/aerospace

# Lines: workspace|window-id|app-name, sorted by (workspace, window-id).
list_windows_sorted() {
  "$AEROSPACE" list-windows --all \
    --format '%{workspace}|%{window-id}|%{app-name}' 2>/dev/null \
    | sort -t'|' -k1,1 -k2,2n
}

focused_window_id() {
  "$AEROSPACE" list-windows --focused --format '%{window-id}' 2>/dev/null
}

focused_workspace() {
  "$AEROSPACE" list-workspaces --focused 2>/dev/null
}
