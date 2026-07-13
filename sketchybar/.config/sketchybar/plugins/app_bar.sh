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
    DataGrip)                                     echo "󰆼" ;;
    Docker|"Docker Desktop")                      echo "󰡨" ;;
    Figma)                                        echo "󰻿" ;;
    "System Settings")                            echo "󰒓" ;;
    Messages|WhatsApp|Telegram)                   echo "󰍦" ;;
    zoom.us)                                      echo "󰍫" ;;
    *)                                            echo "󰣆" ;;
  esac
}

windows="$(list_windows_sorted)"
if [ -z "$windows" ]; then
  # Distinguish a genuine "no windows open" state (CLI alive: the focused
  # workspace still resolves) from a CLI hiccup (aerospace restarting):
  # clear the bar in the first case, hold last good state in the second.
  [ -n "$(focused_workspace)" ] && "$SKETCHYBAR" --remove '/appbar\..*/'
  exit 0
fi

focused_id="$(focused_window_id)"
focused_ws="$(focused_workspace)"

args=(--remove '/appbar\..*/')
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
done <<< "$windows"

# Items append at the end of the bar's left side, which is exactly where
# they belong — nothing sits to their right since the launcher was removed.
"$SKETCHYBAR" "${args[@]}"
