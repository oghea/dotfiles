#!/bin/sh
# Tab-bar state helper for the pmon dashboard (see zsh/.zsh_aliases).
# Subcommands:
#   next  MODEFILE        advance mode: logs -> info -> env -> logs
#   label MODEFILE NAME   print " NAME · Logs │ Info │ Env " with the
#                         active tab bold and the others dimmed (ANSI)
cmd="${1:-}"
modefile="${2:-}"
mode=$(cat "$modefile" 2>/dev/null || echo logs)

case "$cmd" in
  next)
    case "$mode" in
      logs) next=info ;;
      info) next=env ;;
      *)    next=logs ;;
    esac
    printf '%s\n' "$next" > "$modefile"
    ;;
  label)
    name="${3:-}"
    out=" $name · "
    for t in logs info env; do
      case "$t" in
        logs) label=Logs ;;
        info) label=Info ;;
        env)  label=Env ;;
      esac
      if [ "$t" = "$mode" ]; then
        out="$out\033[1m$label\033[0m"
      else
        out="$out\033[2m$label\033[0m"
      fi
      [ "$t" != env ] && out="$out │ "
    done
    printf '%b ' "$out"
    ;;
esac
