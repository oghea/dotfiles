#!/usr/bin/env bash
# Preview renderer for the pmon dashboard (see zsh/.zsh_aliases).
# Usage: pm2-fzf-preview.sh MODE NAME OUT-LOG ERR-LOG
#   logs → live tail of the two log files, tailspin-colored (follows)
#   info → aligned key/value snapshot from `pm2 jlist`
#   env  → the process environment, sorted "KEY  value"
set -u

mode="${1:-logs}"
name="${2:-}"
out="${3:-}"
err="${4:-}"

case "$mode" in
  info|env)
    pm2 jlist 2>/dev/null | MODE="$mode" NAME="$name" python3 -c '
import json, os, sys, time
mode = os.environ["MODE"]
name = os.environ["NAME"]
procs = json.load(sys.stdin) or []
p = next((x for x in procs if x.get("name") == name), None)
if p is None:
    print("no such process")
    sys.exit(0)
e = p["pm2_env"]
if mode == "info":
    now = time.time() * 1000
    secs = max(0, int((now - e.get("pm_uptime", now)) / 1000))
    d, h, mi = secs // 86400, secs % 86400 // 3600, secs % 3600 // 60
    up = ("%dd" % d) if d else (("%dh" % h) if h else ("%dm" % mi))
    m = p.get("monit") or {}
    rows = [
        ("status",    e.get("status", "?")),
        ("uptime",    up if e.get("status") == "online" else "-"),
        ("pid",       p.get("pid", "-")),
        ("restarts",  e.get("restart_time", 0)),
        ("cpu",       "%s%%" % (m.get("cpu", 0))),
        ("memory",    "%d MB" % round((m.get("memory") or 0) / 1048576)),
        ("exec mode", e.get("exec_mode", "-")),
        ("script",    os.path.basename(e.get("pm_exec_path") or "-")),
        ("cwd",       e.get("pm_cwd", "-")),
        ("node",      e.get("node_version", "-")),
    ]
    for k, v in rows:
        print("  \033[2m%-10s\033[0m %s" % (k, v))
else:
    env = e.get("env") or {}
    for k in sorted(env):
        print("  \033[2m%s\033[0m %s" % (k, env[k]))
'
    ;;
  *)
    # logs (default): live, tailspin-colored; empty/missing paths tolerated
    tail -q -n 300 -f "$out" "$err" 2>/dev/null | tspin
    ;;
esac
