# Claude Code + Live Diff Tab — Design

**Date:** 2026-07-22
**Status:** Approved

## Goal

A tmux keybind that opens a "dev tab": a new tmux window with two panes —
left for running Claude Code (or any shell work), right showing a live,
syntax-highlighted view of the repo's git state via lazygit + delta. The
diff pane auto-refreshes as Claude Code edits files and doubles as the
place to stage/commit when the work is done.

## Context

- Ghostty is a thin layer over tmux (Cmd+1–9 → tmux windows), so a
  "special ghostty tab" is a tmux window.
- lazygit is already installed; it gets added to
  `@resurrect-processes` so the layout survives tmux restarts.
- `~/.gitconfig` is intentionally outside the dotfiles repo
  (work/personal identity split) and must not be touched.
- `lazygit/.config/lazygit/` exists in the repo but is empty (defaults).

## Components

### 1. git-delta (Brewfile)

Install `git-delta` via Homebrew and add it to `Brewfile` so the
personal machine picks it up too.

### 2. lazygit config with delta pager

New file: `lazygit/.config/lazygit/config.yml`

- `git.paging.colorArg: always`
- `git.paging.pager: delta --dark --paging=never`
- Delta options: line numbers on, unified view (no side-by-side — the
  pane is only ~40% of the screen wide).

Delta is configured **only inside lazygit**, not in `~/.gitconfig`:
keeps the setup fully inside the dotfiles repo and leaves plain
`git diff` untouched.

### 3. tmux keybind `prefix+g`

In `tmux/.config/tmux/tmux.conf` (Splits/Windows area):

- New window in `#{pane_current_path}`.
- Horizontal split: left pane ~60% (shell, for `claude`), right pane
  ~40% running the dev-tab watcher (component 5).
- Focus lands on the left pane.

### 5. Dev-tab watcher (`scripts/dev-tab-watch.sh`)

Added after first live use: launching lazygit directly meant a non-repo
directory triggered lazygit's "create a new git repository?" prompt, and
the right pane never followed the left pane's `cd`. The right pane now
runs a watcher script instead of bare lazygit:

- Polls its sibling (left) pane's current path once a second via tmux,
  resolving it to a git repo root.
- Repo found → runs lazygit rooted there. When the sibling moves to a
  *different* repo root (including leaving git entirely), the current
  lazygit is killed and the view restarts for the new location.
  `cd` within the same repo causes no restart.
- No repo → a quiet "no git repository — <path>" placeholder instead of
  lazygit's init prompt; the watcher keeps polling so lazygit appears
  the moment the sibling enters a repo.
- Sibling pane closed → watcher exits (pane closes).
- Quitting lazygit with `q` closes the pane, as before.
- Known trade-off: restart-based sync resets lazygit UI state (scroll,
  selection) when hopping repos — lazygit has no remote "change repo"
  command.

`@resurrect-processes` matches the watcher script (`~dev-tab-watch.sh`)
so restored panes come back with sync intact; the script self-discovers
its sibling, so it survives pane-ID changes across restores.

### 4. CHEATSHEET.md

Add a row documenting `prefix+g` → "dev tab: shell + lazygit diff".

## Error handling

- If delta is not installed, lazygit falls back with a pager error only
  inside diff views; installing via Brewfile prevents this on both
  machines.
- The keybind uses `new-window`/`split-window` primitives only — no
  failure modes beyond tmux itself.
- The watcher exits cleanly when run outside tmux or when its sibling
  pane disappears; a non-repo directory is a placeholder state, never an
  error.

## Testing

- Reload tmux config (`prefix+r`), press `prefix+g` in a repo, verify:
  new window, 60/40 split, lazygit right, focus left.
- Edit a tracked file; verify lazygit refreshes and the diff renders
  through delta (line numbers, syntax colors).
- `brew bundle check` passes with the new Brewfile entry.
