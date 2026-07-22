#!/usr/bin/env bash
# dev-tab-open.sh — open the dev tab: shell (left) + synced lazygit
# pane (right, via dev-tab-watch.sh). Shared by the tmux prefix+g
# binding (new window) and the `dev` shell alias (--here: split the
# current window in place). tmux resolves the target from TMUX_PANE.
set -eu

here=0
if [ "${1:-}" = "--here" ]; then
  here=1
  shift
fi

[ -n "${TMUX:-}" ] || { echo "dev-tab-open: run inside tmux" >&2; exit 1; }

dir="${1:-$PWD}"
watch="$HOME/.dotfiles/scripts/dev-tab-watch.sh"

if [ "$here" -eq 1 ]; then
  tmux split-window -h -l 40% -c "$dir" "$watch"
else
  tmux new-window -c "$dir"
  tmux split-window -h -l 40% -c "$dir" "$watch"
fi
tmux select-pane -L
