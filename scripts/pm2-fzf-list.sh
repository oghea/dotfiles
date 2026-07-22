#!/bin/sh
# List generator for the pmon dashboard (see zsh/.zsh_aliases).
# Emits one tab-separated line per pm2 process:
#   name <TAB> colored-stats <TAB> out-log-path <TAB> err-log-path
# Fields 3+4 are the exact current log paths from `pm2 jlist` — never glob
# ~/.pm2/logs, it picks up stale files from old pm2 process ids.
pm2 jlist 2>/dev/null | python3 -c '
import json, sys, time
now = time.time() * 1000
for p in json.load(sys.stdin):
    e = p["pm2_env"]
    if e.get("axm_options", {}).get("isModule"):
        continue  # hide pm2 modules (pm2-logrotate)
    s = e["status"]
    m = p.get("monit") or {}
    if s == "online":
        secs = int((now - e.get("pm_uptime", now)) / 1000)
        d, h, mi = secs // 86400, secs % 86400 // 3600, secs % 3600 // 60
        up = "%dd" % d if d else "%dh" % h if h else "%dm" % mi
        cols = "\033[32m●\033[0m \033[2m%4dM %s%-2d %4s\033[0m" % (
            round((m.get("memory") or 0) / 1048576), "↺",
            e.get("restart_time", 0), up)
    else:
        cols = "\033[31m● %s\033[0m" % s
    print("\t".join([p["name"], cols,
                     e.get("pm_out_log_path", ""), e.get("pm_err_log_path", "")]))
'
