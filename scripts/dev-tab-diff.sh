#!/usr/bin/env bash
# dev-tab-diff.sh — read-only "what changed" viewer for the dev tab.
# Launched by dev-tab-watch.sh with a git repo root. Three modes:
#   dev-tab-diff.sh list <root>               → changed-files list for fzf
#   dev-tab-diff.sh preview <root> <st> <path> → delta diff of one file
#   dev-tab-diff.sh <root>                    → the fzf UI (default)
# The fzf reload/preview binds call back into this same script. Auto-
# refresh is a background ticker that sends ctrl-r to this pane every 2s,
# triggering the same reload as a manual ctrl-r. Read-only: no staging,
# commit, or branch actions — use `lg` (lazygit) for those.
set -u

self="$HOME/.dotfiles/scripts/dev-tab-diff.sh"

case "${1:-}" in
  list)
    root="${2:-}"
    out=$(git -C "$root" status --porcelain=v1 2>/dev/null)
    if [ -z "$out" ]; then
      printf '✓ working tree clean\n'
    else
      # porcelain "XY path" → "XY<TAB>path": fzf field 1=status, 2=path
      printf '%s\n' "$out" | sed 's/^\(..\) /\1\t/'
    fi
    exit 0
    ;;
  preview)
    root="${2:-}"; status="${3:-}"; path="${4:-}"
    [ -n "$path" ] || exit 0          # sentinel line ("working tree clean") has no path
    if [ "$status" = '??' ]; then
      git -C "$root" diff --no-index -- /dev/null "$path" 2>/dev/null
    else
      git -C "$root" diff HEAD -- "$path" 2>/dev/null
    fi | delta --dark --paging=never --line-numbers
    exit 0
    ;;
esac

# --- default: the fzf UI ---
root="${1:-$PWD}"
list="$self list '$root'"

# Auto-refresh: nudge this pane with ctrl-r every 2s (same as manual ^r).
pane="${TMUX_PANE:-}"
ticker=""
if [ -n "$pane" ]; then
  ( while sleep 2; do tmux send-keys -t "$pane" C-r 2>/dev/null || exit 0; done ) &
  ticker=$!
fi

FZF_DEFAULT_COMMAND="$list" fzf \
  --ansi --delimiter='\t' --with-nth=1,2 --style=full \
  --layout=reverse --info=hidden --cycle --pointer=' ' \
  --list-label=' changed ' --border-label=' diff ' --border-label-pos=3 \
  --footer=' j/k file · ^f/^b scroll · ^d/^u half · ^r refresh · q quit ' \
  --preview="$self preview '$root' {1} {2}" \
  --preview-label-pos=3 \
  --bind="focus:transform-preview-label:printf ' %s ' {2}" \
  --bind='j:down,k:up' \
  --bind='ctrl-f:preview-page-down,ctrl-b:preview-page-up' \
  --bind='ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up' \
  --bind="ctrl-r:reload($list)+refresh-preview" \
  --bind='q:abort' \
  --bind='enter:abort'

[ -n "$ticker" ] && kill "$ticker" 2>/dev/null
exit 0
