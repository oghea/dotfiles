#!/bin/sh
# Clean up clipboard text from TUIs like Claude Code:
#   1. Strip trailing whitespace per line (background-padding cells).
#   2. Dedent: remove the common leading whitespace shared by the body of
#      the selection, preserving relative indent inside code blocks.
#
# The first non-empty line is excluded from the indent calculation because
# mouse selections frequently start mid-line, so its leading whitespace
# isn't representative of the message-card padding.
exec awk '
{
  sub(/[ \t]+$/, "")
  lines[NR] = $0
  if (length($0) > 0) {
    match($0, /^[ \t]*/)
    line_indent[NR] = RLENGTH
    indents[++idx] = RLENGTH
  } else {
    line_indent[NR] = 0
  }
}
END {
  if (idx == 0) {
    common = 0
  } else if (idx == 1) {
    common = indents[1]
  } else {
    common = indents[2]
    for (i = 3; i <= idx; i++) {
      if (indents[i] < common) common = indents[i]
    }
  }
  for (i = 1; i <= NR; i++) {
    line = lines[i]
    strip = (line_indent[i] < common) ? line_indent[i] : common
    if (strip > 0) line = substr(line, strip + 1)
    print line
  }
}
' | pbcopy
