#!/usr/bin/env bash
# Focus the Nth window in the app bar's canonical ordering.
# Bound to cmd-alt-1..9 in aerospace.toml.
source "$(dirname "$0")/lib.sh"

n="${1:?usage: focus_nth.sh <1-9>}"
id="$(list_windows_sorted | sed -n "${n}p" | cut -d'|' -f2)"
[ -n "$id" ] && exec "$AEROSPACE" focus --window-id "$id"
