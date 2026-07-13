# SketchyBar app bar grouped by workspace

**Date:** 2026-07-13
**Status:** Approved

## Goal

Replace the static workspace indicators (`space.1-5`) in SketchyBar with a live
list of every open window, grouped by AeroSpace workspace, and add keyboard
shortcuts to jump straight to a specific window. Workspaces stay part of the
workflow (hybrid model): `cmd-ctrl-1..5` workspace keys are untouched.

## Architecture

One dynamic updater rebuilds SketchyBar items from live AeroSpace state.
No new daemons — the existing watcher loop is repurposed.

### Data flow

1. `aerospace_watcher.sh` (existing polling loop, ~0.5s interval) captures a
   snapshot: `aerospace list-windows --all --format
   '%{workspace}|%{window-id}|%{app-name}'` plus the focused window id
   (`aerospace list-windows --focused --format '%{window-id}'`).
2. When the snapshot differs from the previous one, it triggers a custom
   SketchyBar event (`aerospace_windows_change`).
3. A new plugin `app_bar.sh` handles the event and rebuilds the
   `appbar.*` items.

If the AeroSpace CLI errors (empty output), the watcher keeps the last good
state instead of blanking the bar.

### Bar layout (replaces `space.1-5`)

- Entries sorted by **workspace asc, then window id asc** — a stable order.
- Each workspace group starts with its kanji marker (一 二 三 四 五), dim by
  default, bright for the focused workspace.
- One icon **per window** (an app with two windows in a workspace shows two
  icons). App name → Nerd Font icon via a lookup map in `app_bar.sh`
  (Ghostty, Helium, Finder, Slack, …); generic window glyph as fallback.
- The focused window's icon gets the highlight treatment.
- Each entry shows a small number label with its global position 1–9 so the
  shortcuts are discoverable; entries past 9 render without a number but stay
  clickable.
- Styling follows the existing Kanagawa Wave theme; items live inside the
  existing `left_group` bracket.

### Interactions

- **Click** an icon → `aerospace focus --window-id <id>` (switches workspace
  automatically).
- **`cmd-alt-1..9`** bound in `aerospace.toml` → `exec-and-forget
  focus_nth.sh N`. The script recomputes the same (workspace, window-id)
  ordering at press time and focuses the Nth window. Bar and keys derive from
  the same sort, so they cannot drift out of sync.
- `cmd-ctrl-1..5` (workspaces), `cmd-1..9` (tmux windows via Ghostty), and
  `alt-1..9` (tmux panes) are all untouched.

## Removed

- `space.1-5` items and the `SPACE_ICONS`/`SPACE_COLORS` loop in `sketchybarrc`
- `aerospace_workspaces.sh` plugin
- `aerospace_updater` item and the `aerospace_workspace_change` event wiring
- `front_app` item (the highlighted icon shows the focused app; name label is
  redundant)
- `rift_workspaces.sh` (unused leftover from a previous setup)

## Kept

Launcher, bluetooth, clock, battery, volume, blur brackets, theme.

## Edge cases

- Floating/unmanaged windows appear in `list-windows` output and are listed
  like any other window.
- Multiple windows of one app in one workspace: one icon each.
- CLI failure: watcher holds last good state (see Data flow).
- More than 9 entries: no number label, click-only.

## Files touched

| File | Change |
|------|--------|
| `sketchybar/.config/sketchybar/sketchybarrc` | remove spaces/front_app/updater sections, add app bar bootstrap |
| `sketchybar/.config/sketchybar/plugins/aerospace_watcher.sh` | watch full window snapshot, not just focused workspace |
| `sketchybar/.config/sketchybar/plugins/app_bar.sh` | new — rebuilds `appbar.*` items |
| `sketchybar/.config/sketchybar/plugins/focus_nth.sh` | new — focuses Nth window for cmd-alt-N |
| `sketchybar/.config/sketchybar/plugins/aerospace_workspaces.sh` | delete |
| `sketchybar/.config/sketchybar/plugins/rift_workspaces.sh` | delete |
| `sketchybar/.config/sketchybar/plugins/front_app.sh` | delete |
| `aerospace/.config/aerospace/aerospace.toml` | add cmd-alt-1..9 bindings |
| `README.md` | update SketchyBar section |

## Success criteria

- Opening/closing/moving a window updates the bar within ~1s.
- Clicking any icon focuses that window and switches workspace.
- `cmd-alt-N` focuses the window whose number badge shows N.
- Focused window and focused workspace are visually distinct at a glance.
- No stale `appbar.*` items linger after windows close.
