#!/usr/bin/env bash

FOCUSED="$(aerospace list-workspaces --focused 2>/dev/null)"

for i in {1..5}; do
  if [ "$i" = "$FOCUSED" ]; then
    sketchybar --set "space.$i" icon.highlight=on
  else
    sketchybar --set "space.$i" icon.highlight=off
  fi
done
