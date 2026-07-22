#!/usr/bin/env bash
# dev-tab-watch.sh — right-hand pane of the Ctrl-a g dev tab.
# Follows the sibling (left) pane's directory: runs lazygit rooted at
# that repo, restarts it when the sibling moves to a different repo,
# and shows a placeholder instead of lazygit's init prompt when the
# sibling isn't inside a git repo. Exits when the sibling pane closes
# or when lazygit is quit with q.
set -u

POLL=1
SELF="${TMUX_PANE:-}"
[ -n "$SELF" ] || { echo "dev-tab-watch: must run inside tmux" >&2; exit 1; }
export LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml"

# Prints "<dir>\t<root>" for the sibling pane; root is empty when the
# directory is not inside a git repo. Returns 1 when the sibling pane
# is gone.
poll_sibling() {
  local sib dir root
  sib=$(tmux list-panes -F '#{pane_id}' | grep -vx "$SELF" | head -n1) || true
  [ -n "$sib" ] || return 1
  dir=$(tmux display-message -p -t "$sib" '#{pane_current_path}' 2>/dev/null) || return 1
  root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)
  printf '%s\t%s' "$dir" "$root"
}

show_placeholder() {
  clear
  printf '\n\n   no git repository\n\n   %s\n\n   waiting — cd into a repo in the left pane…\n' "$1"
}

shown_dir=""
while :; do
  state=$(poll_sibling) || exit 0
  dir=${state%%$'\t'*}
  root=${state#*$'\t'}

  if [ -z "$root" ]; then
    if [ "$dir" != "$shown_dir" ]; then
      show_placeholder "$dir"
      shown_dir=$dir
    fi
    sleep "$POLL"
    continue
  fi
  shown_dir=""

  lazygit --path "$root" &
  lg_pid=$!
  status=user_quit
  while kill -0 "$lg_pid" 2>/dev/null; do
    sleep "$POLL"
    state=$(poll_sibling) || { status=sibling_gone; break; }
    new_root=${state#*$'\t'}
    if [ "$new_root" != "$root" ]; then
      status=moved
      break
    fi
  done
  [ "$status" != user_quit ] && kill "$lg_pid" 2>/dev/null
  wait "$lg_pid" 2>/dev/null
  tput rmcup 2>/dev/null || true
  [ "$status" = moved ] || exit 0
done
