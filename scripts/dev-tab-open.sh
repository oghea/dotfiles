#!/usr/bin/env bash
# dev-tab-open.sh — open the dev tab: shell (left) + synced lazygit
# pane (right, via dev-tab-watch.sh). Shared by the tmux prefix+g
# binding and the `dev` shell alias; tmux resolves the target session
# from TMUX_PANE in both paths.
set -eu

[ -n "${TMUX:-}" ] || { echo "dev-tab-open: run inside tmux" >&2; exit 1; }

dir="${1:-$PWD}"
tmux new-window -c "$dir"
tmux split-window -h -l 40% -c "$dir" "$HOME/.dotfiles/scripts/dev-tab-watch.sh"
tmux select-pane -L
