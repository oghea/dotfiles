# SketchyBar App Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace SketchyBar's static workspace indicators with a live per-window app bar grouped by AeroSpace workspace, with click-to-focus and cmd-alt-1..9 jump keys.

**Architecture:** A polling watcher (existing pattern) detects AeroSpace window/focus changes and fires a custom SketchyBar event; a plugin rebuilds `appbar.*` items from `aerospace list-windows`. A shared helper defines the canonical window ordering so the bar and the jump keys can never disagree.

**Tech Stack:** bash, SketchyBar 2.x, AeroSpace 0.21.x CLI, JetBrainsMono Nerd Font.

**Spec:** `docs/superpowers/specs/2026-07-13-sketchybar-app-bar-design.md`

## Global Constraints

- Repo is `~/.dotfiles`; configs are stowed symlinks, so edits under `~/.dotfiles/sketchybar/.config/sketchybar/` are live at `~/.config/sketchybar/` immediately. Same for aerospace.
- Absolute binary paths in scripts run by aerospace/sketchybar: `/opt/homebrew/bin/aerospace`, `/opt/homebrew/bin/sketchybar` (their env has no brew PATH).
- Kanagawa palette values must match `sketchybarrc`: FG_PRIMARY `dcd7ba`, FG_DIM `727169`, BG_OVERLAY `363646`, workspace colors `7e9cd8 957fb8 d27e99 7fb4ca 98bb6c dca561 c34043` (repeating).
- Do NOT touch: `cmd-ctrl-1..5` (workspaces), `cmd-1..9` (Ghostty→tmux windows), `alt-1..9` (tmux panes).
- Workspaces are named `1`–`5` (numeric) in aerospace.toml.
- No test framework: every task verifies via live commands with stated expected output.
- Commit after every task with the trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: Shared ordering helper + focus_nth.sh

**Files:**
- Create: `sketchybar/.config/sketchybar/plugins/lib.sh`
- Create: `sketchybar/.config/sketchybar/plugins/focus_nth.sh`

**Interfaces:**
- Produces: `list_windows_sorted` (stdout lines `workspace|window-id|app-name`, sorted by workspace then window id), `focused_window_id` (stdout: id or empty), `focused_workspace` (stdout: name). `focus_nth.sh <n>` focuses the nth line's window. Tasks 2 and 4 source `lib.sh` from the same directory.

- [ ] **Step 1: Write `plugins/lib.sh`**

```bash
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
```

- [ ] **Step 2: Write `plugins/focus_nth.sh`**

```bash
#!/usr/bin/env bash
# Focus the Nth window in the app bar's canonical ordering.
# Bound to cmd-alt-1..9 in aerospace.toml.
source "$(dirname "$0")/lib.sh"

n="${1:?usage: focus_nth.sh <1-9>}"
id="$(list_windows_sorted | sed -n "${n}p" | cut -d'|' -f2)"
[ -n "$id" ] && exec "$AEROSPACE" focus --window-id "$id"
```

- [ ] **Step 3: Make executable and verify failure mode first**

Run: `chmod +x ~/.config/sketchybar/plugins/lib.sh ~/.config/sketchybar/plugins/focus_nth.sh && bash ~/.config/sketchybar/plugins/focus_nth.sh`
Expected: exits non-zero with `usage: focus_nth.sh <1-9>` (missing-arg guard works).

- [ ] **Step 4: Verify ordering and focusing**

Run: `bash -c 'source ~/.config/sketchybar/plugins/lib.sh; list_windows_sorted'`
Expected: one line per open window, e.g. `1|48864|Ghostty`, sorted by workspace.

Run: `bash ~/.config/sketchybar/plugins/focus_nth.sh 1 && sleep 1 && /opt/homebrew/bin/aerospace list-windows --focused --format '%{window-id}|%{app-name}'`
Expected: prints the same window id as line 1 of `list_windows_sorted`.

- [ ] **Step 5: Commit**

```bash
git add sketchybar/.config/sketchybar/plugins/lib.sh sketchybar/.config/sketchybar/plugins/focus_nth.sh
git commit -m "sketchybar: shared window ordering + focus_nth for app jump keys"
```

---

### Task 2: app_bar.sh renderer

**Files:**
- Create: `sketchybar/.config/sketchybar/plugins/app_bar.sh`

**Interfaces:**
- Consumes: `lib.sh` → `list_windows_sorted`, `focused_window_id`, `focused_workspace` (Task 1).
- Produces: idempotent rebuild of all `appbar.ws.<n>` / `appbar.win.<id>` items, positioned before the `launcher` item. Task 3 wires it to the `aerospace_windows_change` event; Task 4's watcher triggers that event.

- [ ] **Step 1: Write `plugins/app_bar.sh`**

```bash
#!/usr/bin/env bash
# Rebuild the appbar.* items: one dim kanji marker per workspace (bright for
# the focused workspace), one icon per window (highlighted when focused),
# numbered 1-9 to match the cmd-alt-N jump keys. Triggered via the
# aerospace_windows_change event; safe to run directly for an initial paint.
source "$(dirname "$0")/lib.sh"

SKETCHYBAR=/opt/homebrew/bin/sketchybar

# Kanagawa palette (kept in sync with sketchybarrc)
FG_PRIMARY="dcd7ba"
FG_DIM="727169"
BG_OVERLAY="363646"
WS_COLORS=("7e9cd8" "957fb8" "d27e99" "7fb4ca" "98bb6c" "dca561" "c34043")
WS_ICONS=("一" "二" "三" "四" "五" "六" "七" "八" "九")

app_icon() {
  case "$1" in
    Ghostty|Terminal|iTerm2|kitty)                echo "󰆍" ;;
    Helium|Safari|"Google Chrome"|Firefox|Arc)    echo "󰖟" ;;
    Finder)                                       echo "󰀶" ;;
    Slack)                                        echo "󰒱" ;;
    Discord)                                      echo "󰙯" ;;
    Spotify)                                      echo "󰓇" ;;
    Mail)                                         echo "󰇮" ;;
    Calendar)                                     echo "󰃭" ;;
    Notes)                                        echo "󱞎" ;;
    Obsidian)                                     echo "󰠮" ;;
    "Visual Studio Code"|Code|Cursor)             echo "󰨞" ;;
    Docker|"Docker Desktop")                      echo "󰡨" ;;
    Figma)                                        echo "󰻿" ;;
    "System Settings")                            echo "󰒓" ;;
    Messages|WhatsApp|Telegram)                   echo "󰍦" ;;
    zoom.us)                                      echo "󰍫" ;;
    *)                                            echo "󰣆" ;;
  esac
}

windows="$(list_windows_sorted)"
# CLI hiccup (e.g. aerospace restarting): keep the last good bar state.
[ -z "$windows" ] && exit 0

focused_id="$(focused_window_id)"
focused_ws="$(focused_workspace)"

args=(--remove '/appbar\..*/')
order=()   # item names in visual order, for --move at the end
pos=0
prev_ws=""

while IFS='|' read -r ws id app; do
  if [ "$ws" != "$prev_ws" ]; then
    # Workspace marker. Workspaces are named 1-5; fall back to the raw
    # name as the icon if a non-numeric workspace ever appears.
    if [[ "$ws" =~ ^[0-9]+$ ]]; then
      marker="${WS_ICONS[$(( (ws - 1) % 9 ))]}"
    else
      marker="$ws"
    fi
    marker_color="$FG_DIM"
    [ "$ws" = "$focused_ws" ] && marker_color="$FG_PRIMARY"
    name="appbar.ws.$ws"
    args+=(--add item "$name" left
           --set "$name"
             icon="$marker" "icon.color=0xff$marker_color"
             icon.font.size=13.0 icon.padding_left=8 icon.padding_right=2
             label.drawing=off background.drawing=off)
    order+=("$name")
    prev_ws="$ws"
  fi

  pos=$((pos + 1))
  name="appbar.win.$id"

  if [[ "$ws" =~ ^[0-9]+$ ]]; then
    color="${WS_COLORS[$(( (ws - 1) % 7 ))]}"
  else
    color="${WS_COLORS[0]}"
  fi

  item=(--add item "$name" left
        --set "$name"
          icon="$(app_icon "$app")" icon.font.size=15.0
          icon.padding_left=6 icon.padding_right=2
          label.font.size=9.0 "label.color=0xff$FG_DIM"
          label.padding_left=0 label.padding_right=5
          background.corner_radius=8 background.height=24
          background.border_width=0 background.shadow.drawing=off
          "click_script=$AEROSPACE focus --window-id $id")

  if [ "$pos" -le 9 ]; then
    item+=("label=$pos" label.drawing=on)
  else
    item+=(label.drawing=off)
  fi

  if [ "$id" = "$focused_id" ]; then
    item+=("icon.color=0xff$FG_PRIMARY" background.drawing=on
           "background.color=0xd0$BG_OVERLAY")
  else
    item+=("icon.color=0xb0$color" background.drawing=off)
  fi

  args+=("${item[@]}")
  order+=("$name")
done <<< "$windows"

# Place entries where the old workspace indicators lived: in creation order,
# each moved before the launcher (A before launcher, then B before launcher
# yields A B launcher).
for name in "${order[@]}"; do
  args+=(--move "$name" before launcher)
done

"$SKETCHYBAR" "${args[@]}"
```

- [ ] **Step 2: Run against the live bar and verify items exist**

Run: `chmod +x ~/.config/sketchybar/plugins/app_bar.sh && bash ~/.config/sketchybar/plugins/app_bar.sh && sketchybar --query bar | python3 -c "import json,sys; print([i for i in json.load(sys.stdin)['items'] if i.startswith('appbar.')])"`
Expected: a non-empty list with one `appbar.ws.<n>` per occupied workspace and one `appbar.win.<id>` per window, ordered ws-marker-then-windows. (Old `space.*` items still present at this stage — removed in Task 3.)

- [ ] **Step 3: Verify idempotency (no duplicate items)**

Run: `bash ~/.config/sketchybar/plugins/app_bar.sh && sketchybar --query bar | python3 -c "import json,sys; l=[i for i in json.load(sys.stdin)['items'] if i.startswith('appbar.')]; assert len(l)==len(set(l)); print('ok', len(l))"`
Expected: `ok <count>` with the same count as Step 2.

- [ ] **Step 4: Verify click focuses (pick any appbar.win id)**

Run: `sketchybar --query appbar.win.<id-from-step-2>` and confirm `click_script` contains `focus --window-id <id>`. Then run that click_script command directly; the window should focus (check `aerospace list-windows --focused`).

- [ ] **Step 5: Commit**

```bash
git add sketchybar/.config/sketchybar/plugins/app_bar.sh
git commit -m "sketchybar: app_bar renderer — windows grouped by workspace"
```

---

### Task 3: Wire into sketchybarrc, remove old workspace/front_app items

**Files:**
- Modify: `sketchybar/.config/sketchybar/sketchybarrc`

**Interfaces:**
- Consumes: `app_bar.sh` (Task 2).
- Produces: `aerospace_windows_change` event registered; `appbar_updater` hidden item subscribed to it running `app_bar.sh`; initial paint on bar load. Task 4's watcher triggers this event.

- [ ] **Step 1: Update the left bracket regex** (line ~88)

Replace:
```bash
sketchybar --add bracket left_group '/portal/' '/cosmic_sep/' '/space\..*/' '/front_app/' '/launcher/' '/launch\..*/' '/bluetooth/' \
```
with:
```bash
sketchybar --add bracket left_group '/portal/' '/cosmic_sep/' '/appbar\..*/' '/launcher/' '/launch\..*/' '/bluetooth/' \
```

- [ ] **Step 2: Replace the workspaces section** (the `#  Workspaces (AeroSpace)` block: `--add event aerospace_workspace_change`, `SPACE_ICONS`/`SPACE_COLORS`, the `space.$sid` loop, and the `aerospace_updater` item) with:

```bash
############################
#  App bar (AeroSpace)     #
############################

# Windows grouped by workspace; rebuilt by app_bar.sh whenever
# aerospace_watcher.sh detects a window/focus change.
sketchybar --add event aerospace_windows_change

sketchybar --add item appbar_updater left \
           --set appbar_updater drawing=off \
                                script="$PLUGIN_DIR/app_bar.sh" \
           --subscribe appbar_updater aerospace_windows_change
```

- [ ] **Step 3: Delete the `front_app` item block** (the `--add item front_app left ... --subscribe front_app front_app_switched` command).

- [ ] **Step 4: Add initial paint before the final `sketchybar --update`**

```bash
echo "🌊 Kanagawa Wave theme loaded - muted elegance"
"$PLUGIN_DIR/app_bar.sh" &
sketchybar --update
```

- [ ] **Step 5: Reload and verify**

Run: `sketchybar --reload && sleep 2 && sketchybar --query bar | python3 -c "import json,sys; items=json.load(sys.stdin)['items']; print('stale:', [i for i in items if i.startswith(('space.','front_app'))]); print('appbar:', len([i for i in items if i.startswith('appbar.')]))"`
Expected: `stale: []` and `appbar: <n>` > 0. Visually: kanji markers + app icons render inside the left blur bracket, before the launcher icon.

- [ ] **Step 6: Commit**

```bash
git add sketchybar/.config/sketchybar/sketchybarrc
git commit -m "sketchybar: replace workspace indicators and front_app with app bar"
```

---

### Task 4: Rewrite the watcher for window-level snapshots

**Files:**
- Modify: `sketchybar/.config/sketchybar/plugins/aerospace_watcher.sh` (full rewrite below)

**Interfaces:**
- Consumes: `lib.sh` (Task 1); `aerospace_windows_change` event (Task 3).
- Produces: fires the event whenever the (windows, focused window, focused workspace) snapshot changes.

- [ ] **Step 1: Replace file contents with**

```bash
#!/usr/bin/env bash
# Watches AeroSpace window/focus state and triggers the sketchybar
# aerospace_windows_change event when anything changes. Started by
# aerospace's after-startup-command.

# Kill any previous instance of this watcher. Match by process name rather
# than a /tmp lockfile — macOS purges /tmp after ~3 days, which let stale
# watchers pile up across AeroSpace restarts.
for pid in $(pgrep -f "aerospace_watcher.sh"); do
  [ "$pid" != "$$" ] && kill "$pid" 2>/dev/null
done

source "$(dirname "$0")/lib.sh"

PREV=""
while true; do
  SNAP="$(list_windows_sorted)
$(focused_window_id)
$(focused_workspace)"
  # Empty window list = CLI hiccup (aerospace restarting); hold last state.
  if [ -n "$(list_windows_sorted)" ] && [ "$SNAP" != "$PREV" ]; then
    /opt/homebrew/bin/sketchybar --trigger aerospace_windows_change
    PREV="$SNAP"
  fi
  sleep 0.5
done
```

Note: capture `list_windows_sorted` once into a variable instead of calling it twice — write it as:

```bash
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
```
(Use this second version verbatim for the loop. The `-n "$WS"` guard — not
`-n "$WINDOWS"` — matters: a genuinely empty window list must still trigger
the event so app_bar.sh can clear stale items.)

- [ ] **Step 2: Restart the watcher**

Run: `bash ~/.config/sketchybar/plugins/aerospace_watcher.sh >/dev/null 2>&1 & sleep 1 && pgrep -fc aerospace_watcher.sh`
Expected: `1` (new instance killed any old one).

- [ ] **Step 3: End-to-end test — window open/close updates the bar**

Run: `open -a "System Settings" && sleep 2 && sketchybar --query bar | python3 -c "import json,sys; print([i for i in json.load(sys.stdin)['items'] if i.startswith('appbar.win.')])"`
Expected: one more `appbar.win.*` than before. Then quit System Settings (`osascript -e 'quit app "System Settings"'`), sleep 2, re-query: the item is gone.

- [ ] **Step 4: End-to-end test — focus change re-highlights**

Run: `aerospace workspace 2 && sleep 1 && sketchybar --query appbar.ws.2 | python3 -c "import json,sys; print(json.load(sys.stdin)['icon']['color'])"`
Expected: `0xffdcd7ba` (bright = focused). Switch back with `aerospace workspace 1` and confirm `appbar.ws.1` is now bright and `appbar.ws.2` is `0xff727169`.

- [ ] **Step 5: Commit**

```bash
git add sketchybar/.config/sketchybar/plugins/aerospace_watcher.sh
git commit -m "sketchybar: watcher tracks full window snapshot, pgrep dedup"
```

---

### Task 5: cmd-alt-1..9 bindings in aerospace.toml

**Files:**
- Modify: `aerospace/.config/aerospace/aerospace.toml` (inside `[mode.main.binding]`, after the `cmd-ctrl-shift-5` line)

**Interfaces:**
- Consumes: `focus_nth.sh` (Task 1).

- [ ] **Step 1: Add bindings**

```toml
# Jump to the Nth window shown in the sketchybar app bar
cmd-alt-1 = 'exec-and-forget /Users/prayogaantarasputra/.config/sketchybar/plugins/focus_nth.sh 1'
cmd-alt-2 = 'exec-and-forget /Users/prayogaantarasputra/.config/sketchybar/plugins/focus_nth.sh 2'
cmd-alt-3 = 'exec-and-forget /Users/prayogaantarasputra/.config/sketchybar/plugins/focus_nth.sh 3'
cmd-alt-4 = 'exec-and-forget /Users/prayogaantarasputra/.config/sketchybar/plugins/focus_nth.sh 4'
cmd-alt-5 = 'exec-and-forget /Users/prayogaantarasputra/.config/sketchybar/plugins/focus_nth.sh 5'
cmd-alt-6 = 'exec-and-forget /Users/prayogaantarasputra/.config/sketchybar/plugins/focus_nth.sh 6'
cmd-alt-7 = 'exec-and-forget /Users/prayogaantarasputra/.config/sketchybar/plugins/focus_nth.sh 7'
cmd-alt-8 = 'exec-and-forget /Users/prayogaantarasputra/.config/sketchybar/plugins/focus_nth.sh 8'
cmd-alt-9 = 'exec-and-forget /Users/prayogaantarasputra/.config/sketchybar/plugins/focus_nth.sh 9'
```

- [ ] **Step 2: Reload and verify config parses**

Run: `aerospace reload-config && echo OK`
Expected: `OK` with no config-error output (aerospace prints errors to a dialog/stderr on bad config).

- [ ] **Step 3: Manual key check (user-visible)**

Press `cmd-alt-2`: focus should jump to the window whose badge shows 2 (workspace switches if needed). This is the one step needing a human keypress; note it in the final report.

- [ ] **Step 4: Commit**

```bash
git add aerospace/.config/aerospace/aerospace.toml
git commit -m "aerospace: cmd-alt-1..9 jump to Nth app bar window"
```

---

### Task 6: Cleanup dead plugins + README

**Files:**
- Delete: `sketchybar/.config/sketchybar/plugins/aerospace_workspaces.sh`
- Delete: `sketchybar/.config/sketchybar/plugins/front_app.sh`
- Delete: `sketchybar/.config/sketchybar/plugins/rift_workspaces.sh`
- Modify: `README.md` SketchyBar section

- [ ] **Step 1: Delete dead plugins**

```bash
git rm sketchybar/.config/sketchybar/plugins/aerospace_workspaces.sh \
       sketchybar/.config/sketchybar/plugins/front_app.sh \
       sketchybar/.config/sketchybar/plugins/rift_workspaces.sh
```

- [ ] **Step 2: Verify nothing references them**

Run: `grep -rn "aerospace_workspaces\|front_app\|rift_workspaces" sketchybar/ aerospace/ README.md || echo clean`
Expected: only README hits (fixed next step) or `clean`.

- [ ] **Step 3: Update README SketchyBar section**

Replace the `- **Left:** workspace indicator (Rift), active app, quick launcher, Bluetooth` line with:
```markdown
- **Left:** app bar — open windows grouped by AeroSpace workspace (click or `cmd-alt-1..9` to focus), quick launcher, Bluetooth
```

- [ ] **Step 4: Final smoke test**

Run: `sketchybar --reload && sleep 2 && sketchybar --query bar | python3 -c "import json,sys; items=json.load(sys.stdin)['items']; print('appbar items:', len([i for i in items if i.startswith('appbar.')]))"`
Expected: `appbar items: <n>` > 0, bar renders correctly.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "sketchybar: remove workspace-indicator plugins superseded by app bar"
```
