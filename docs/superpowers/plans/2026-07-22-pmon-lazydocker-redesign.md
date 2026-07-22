# pmon Lazydocker-Style Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the `pmon` pm2 dashboard a lazydocker look — bordered panels (`fzf --style=full`), a `Logs · Info · Env` tab bar on the preview, and a footer keybinding bar.

**Architecture:** Keep the existing list generator. Add a preview renderer (`pm2-fzf-preview.sh`) that produces the three tabs' content, and a tiny tab-state helper (`pm2-fzf-tab.sh`). Rewrite `pmon()` to use `--style=full`, a `--footer`, a per-instance mode file, and Tab-to-cycle bindings.

**Tech Stack:** bash/sh, python3 (already used by the list generator), fzf 0.74.1, pm2, tspin.

## Global Constraints

- `zsh/.zsh_aliases` contains the user's unrelated uncommitted WIP: `alias mp="cd ~/Documents/marta-platform/"` at line 8. It must NOT be committed. The `pmon` function (also currently uncommitted) IS in scope for this feature. Staging uses the exact `git apply --cached --reverse` recipe in Task 2 — never `git add -A`, never `git add .`, never plain `git add zsh/.zsh_aliases` as the final staged state.
- All work happens in `~/.dotfiles`.
- No new dependencies: `pm2`, `python3`, `tspin`, `fzf` are all already installed and used.
- The list generator `scripts/pm2-fzf-list.sh` is unchanged by this plan.

---

### Task 1: Preview renderer script

**Files:**
- Create: `scripts/pm2-fzf-preview.sh` (mode 755)

**Interfaces:**
- Consumes: `pm2 jlist` JSON, `tspin`.
- Produces: `pm2-fzf-preview.sh MODE NAME OUT ERR` — `MODE` ∈ {logs, info, env}; `logs` streams `tail -f OUT ERR | tspin`; `info`/`env` render from `pm2 jlist` filtered to `NAME`. Unknown MODE → logs. Consumed by `pmon()` in Task 2.

- [ ] **Step 1: Write the script**

Create `scripts/pm2-fzf-preview.sh` with exactly this content:

```bash
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
```

Then: `chmod +x scripts/pm2-fzf-preview.sh`

- [ ] **Step 2: Syntax check**

Run: `bash -n ~/.dotfiles/scripts/pm2-fzf-preview.sh && echo OK`
Expected: `OK`

- [ ] **Step 3: Pick a live process name for the checks**

Run: `NAME=$(pm2 jlist 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(p["name"] for p in d if not p["pm2_env"].get("axm_options",{}).get("isModule")))'); echo "$NAME"`
Expected: a real process name (e.g. `auth-service`). If empty, pm2 has no processes — start some (`pm2 list`) before continuing, or report BLOCKED.

- [ ] **Step 4: Verify the `info` tab renders**

Run: `~/.dotfiles/scripts/pm2-fzf-preview.sh info "$NAME" | sed 's/\x1b\[[0-9;]*m//g'`
Expected: ten lines, `status … node …`, e.g.:
```
  status     online
  uptime     3h
  pid        58860
  restarts   2
  cpu        0.1%
  memory     62 MB
  exec mode  fork
  script     main.js
  cwd        /Users/.../auth-service
  node       20.11.0
```
(Exact values differ; the point is ten labelled rows with plausible data.)

- [ ] **Step 5: Verify the `env` tab renders**

Run: `~/.dotfiles/scripts/pm2-fzf-preview.sh env "$NAME" | sed 's/\x1b\[[0-9;]*m//g' | head -5`
Expected: sorted `KEY  value` lines (keys in ascending order, e.g. `AI_AGENT`, `ANDROID_HOME`, …).

- [ ] **Step 6: Verify the not-found path**

Run: `~/.dotfiles/scripts/pm2-fzf-preview.sh info __nope__; echo "exit=$?"`
Expected: `no such process` then `exit=0`.

- [ ] **Step 7: Verify the `logs` tab streams**

Run: `timeout 2 ~/.dotfiles/scripts/pm2-fzf-preview.sh logs "$NAME" "$(pm2 jlist | python3 -c "import json,sys;print(next(p[\"pm2_env\"][\"pm_out_log_path\"] for p in json.load(sys.stdin) if p[\"name\"]==\"$NAME\"))")" /dev/null 2>/dev/null; echo "exit=$?"`
Note: macOS has no `timeout`; if the command errors with `timeout: command not found`, instead run the script in the background and kill it:
`~/.dotfiles/scripts/pm2-fzf-preview.sh logs "$NAME" /dev/null /dev/null & P=$!; sleep 2; kill $P 2>/dev/null; echo "ran"`
Expected: it runs and follows without erroring (output may be empty for `/dev/null`); it does not exit on its own — that confirms the follow behavior. Record which variant you used.

- [ ] **Step 8: Commit**

```bash
cd ~/.dotfiles
git add scripts/pm2-fzf-preview.sh
git commit -m "pmon: add preview renderer with logs/info/env tabs"
```

Expected: `git show --stat HEAD` lists exactly one file, `scripts/pm2-fzf-preview.sh`.

---

### Task 2: Tab helper + `pmon()` rewrite

**Files:**
- Create: `scripts/pm2-fzf-tab.sh` (mode 755)
- Modify: `zsh/.zsh_aliases` (replace the `pmon` function + its comment, lines 67–91 of the working tree)

**Interfaces:**
- Consumes: `scripts/pm2-fzf-preview.sh` (Task 1), `scripts/pm2-fzf-list.sh` (existing).
- Produces: `pm2-fzf-tab.sh next MODEFILE` (advance mode) and `pm2-fzf-tab.sh label MODEFILE NAME` (print the tab bar); the rewritten `pmon` shell function.

- [ ] **Step 1: Write the tab helper**

Create `scripts/pm2-fzf-tab.sh` with exactly this content:

```sh
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
```

Then: `chmod +x scripts/pm2-fzf-tab.sh` and `sh -n scripts/pm2-fzf-tab.sh && echo OK` (expect `OK`).

- [ ] **Step 2: Verify the tab helper**

```bash
M=$(mktemp); printf 'logs\n' > "$M"
~/.dotfiles/scripts/pm2-fzf-tab.sh label "$M" auth-service | sed 's/\x1b\[[0-9;]*m//g'; echo
~/.dotfiles/scripts/pm2-fzf-tab.sh next "$M"; cat "$M"
~/.dotfiles/scripts/pm2-fzf-tab.sh next "$M"; cat "$M"
~/.dotfiles/scripts/pm2-fzf-tab.sh next "$M"; cat "$M"
rm -f "$M"
```
Expected: label line ` auth-service · Logs │ Info │ Env ` (escapes stripped), then `info`, `env`, `logs` (the cycle wraps).

- [ ] **Step 3: Rewrite the `pmon` function in the working tree**

In `zsh/.zsh_aliases`, replace this exact block (the comment on lines 67–70 and the function on lines 71–91):

```zsh
# pm2 monit replacement — lazydocker-style TUI: pm2 process list with live
# mem/restarts/uptime (left) + live-following tailspin-colored logs of the
# highlighted process (right). ctrl-j/k or arrows to swap process,
# ctrl-x = restart highlighted process, ctrl-r = refresh stats, esc = quit.
pmon() {
  # List generator lives in its own script: fzf --bind cannot carry a
  # multiline command (reload came back empty), and a script keeps the
  # binds one-liners.
  local gen="$HOME/.dotfiles/scripts/pm2-fzf-list.sh"
  # Fixed-width list (~44 cols is what the rows need), logs get the rest —
  # percentages waste space on wide terminals. Recomputed per launch.
  local pw=$(( COLUMNS - 44 ))
  (( pw < 50 )) && pw='60%'
  FZF_DEFAULT_COMMAND="$gen" fzf --ansi --delimiter='\t' --tabstop=24 \
    --with-nth=1,2 --pointer=' ' --color='gutter:-1' \
    --layout=reverse --info=hidden --cycle --prompt='pm2 ❯ ' --ellipsis='…' \
    --border=rounded --border-label=' pm2 · ctrl-x: restart · ctrl-r: refresh ' \
    --border-label-pos=3 \
    --preview-window="right,${pw},follow,wrap,border-left" \
    --bind='focus:transform-preview-label:echo " {1} "' \
    --preview='tail -q -n 300 -f {3} {4} | tspin' \
    --bind="ctrl-r:reload:$gen" \
    --bind="ctrl-x:reload:pm2 restart {1} >/dev/null 2>&1; $gen" \
    --bind='enter:abort'
}
```

with exactly this block:

```zsh
# pm2 monit replacement — lazydocker-style TUI. Left: process list with
# live mem/restarts/uptime. Right: a tabbed preview (Logs · Info · Env)
# for the highlighted process. Tab cycles tabs, ctrl-x restarts, ctrl-r
# refreshes the list, q quits. Rendering scripts live in ~/.dotfiles/scripts.
pmon() {
  local gen="$HOME/.dotfiles/scripts/pm2-fzf-list.sh"
  local prev="$HOME/.dotfiles/scripts/pm2-fzf-preview.sh"
  local tab="$HOME/.dotfiles/scripts/pm2-fzf-tab.sh"
  # Fixed-width list (~44 cols is what the rows need), preview gets the
  # rest; percentages waste space on wide terminals. Recomputed per launch.
  local pw=$(( COLUMNS - 44 ))
  (( pw < 50 )) && pw='60%'
  # Per-instance tab state; removed when fzf exits.
  local mode
  mode=$(mktemp) || return 1
  printf 'logs\n' > "$mode"
  FZF_DEFAULT_COMMAND="$gen" fzf --ansi --delimiter='\t' --tabstop=24 \
    --with-nth=1,2 --pointer=' ' --color='gutter:-1' \
    --style=full --layout=reverse --info=hidden --cycle \
    --prompt='pm2 ❯ ' --ellipsis='…' \
    --list-label=' Processes ' --border-label=' pm2 ' --border-label-pos=3 \
    --footer=' ↑↓ move · ⇥ next tab · ^x restart · ^r refresh · / filter · q quit ' \
    --preview-window="right,${pw},follow,wrap" \
    --preview="$prev \"\$(cat $mode)\" {1} {3} {4}" \
    --preview-label-pos=3 \
    --bind="focus:transform-preview-label:$tab label $mode {1}" \
    --bind="tab:execute-silent($tab next $mode)+refresh-preview+transform-preview-label($tab label $mode {1})" \
    --bind="ctrl-r:reload:$gen" \
    --bind="ctrl-x:reload:pm2 restart {1} >/dev/null 2>&1; $gen" \
    --bind='enter:abort'
  rm -f "$mode"
}
```

- [ ] **Step 4: Stage the two scripts and the pmon change, keeping `mp` unstaged**

The working tree's `zsh/.zsh_aliases` now has two independent uncommitted changes: the `mp` alias (line 8, must stay uncommitted) and the `pmon` rewrite (in scope). Stage everything, then reverse out just the `mp` addition from the index:

```bash
cd ~/.dotfiles
git add scripts/pm2-fzf-tab.sh zsh/.zsh_aliases
git apply --cached --reverse <<'EOF'
diff --git a/zsh/.zsh_aliases b/zsh/.zsh_aliases
--- a/zsh/.zsh_aliases
+++ b/zsh/.zsh_aliases
@@ -6,3 +6,4 @@
 # Folder shortcuts
 alias repo="cd ~/Documents/repo"
+alias mp="cd ~/Documents/marta-platform/"
 
EOF
```

If `git apply --cached --reverse` fails, STOP and report BLOCKED with the error — do not fall back to a plain `git add`.

- [ ] **Step 5: Verify staging is correct**

```bash
cd ~/.dotfiles
git diff --cached --stat
echo "--- mp must NOT be staged (expect empty):"
git diff --cached zsh/.zsh_aliases | grep 'marta-platform' || echo "(clean — mp not staged)"
echo "--- mp must still be in the working tree (expect the line):"
git diff zsh/.zsh_aliases | grep 'marta-platform'
```
Expected: staged stat shows `scripts/pm2-fzf-tab.sh` and `zsh/.zsh_aliases`; the first grep prints `(clean — mp not staged)`; the second grep prints the `+alias mp=...` line (still an unstaged working-tree change).

- [ ] **Step 6: Reload the function and smoke-test non-interactively**

```bash
source ~/.dotfiles/zsh/.zsh_aliases 2>/dev/null
type pmon | head -1
zsh -n ~/.dotfiles/zsh/.zsh_aliases && echo "SYNTAX OK"
```
Expected: `pmon is a shell function` (or similar) and `SYNTAX OK`.

- [ ] **Step 7: Commit**

```bash
cd ~/.dotfiles
git commit -m "pmon: lazydocker-style tabs, footer, and bordered panels"
```
Expected: `git show --stat HEAD` lists exactly two files — `scripts/pm2-fzf-tab.sh` and `zsh/.zsh_aliases` — and the `zsh/.zsh_aliases` hunk contains the pmon rewrite but NOT the `mp` alias.

- [ ] **Step 8: Manual visual check (user-run, not automated)**

Note for the controller: this is the one check that needs a human at the terminal — leave it for the user. In a fresh shell inside tmux: run `pmon`, and confirm:
- bordered panels with a `Processes` list label and a `pm2` outer label;
- a footer bar reading `↑↓ move · ⇥ next tab · ^x restart · ^r refresh · / filter · q quit`;
- the preview label shows ` <name> · Logs │ Info │ Env ` with the active tab **bold/bright** and the others dimmed — NOT literal `\033[` escape codes (if escapes render literally, that's a real defect in `pm2-fzf-tab.sh`'s label output to fix);
- pressing `Tab` cycles Logs → Info → Env, the preview content changes accordingly, and the highlighted tab moves;
- `ctrl-x` restarts the highlighted process, `ctrl-r` refreshes, `q` quits.
