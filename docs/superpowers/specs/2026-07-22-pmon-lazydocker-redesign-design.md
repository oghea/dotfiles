# pmon Lazydocker-Style Redesign — Design

**Date:** 2026-07-22
**Status:** Approved

## Goal

Make the `pmon` pm2 dashboard look and feel like lazydocker: bordered
panels (`fzf --style=full`), a tab bar on the preview panel cycling
`Logs · Info · Env`, and a footer bar carrying the keybindings. Keep the
existing data flow (list generator → fzf → preview) and the current
live-log behavior.

## Context

- `pmon` is a zsh function in `zsh/.zsh_aliases` (currently uncommitted
  WIP, alongside an unrelated `mp` alias — neither is committed yet).
- It shells out to `scripts/pm2-fzf-list.sh`, which emits one
  tab-separated line per pm2 process:
  `name ⇥ colored-stats ⇥ out-log-path ⇥ err-log-path`.
- Today the preview only tails logs. There is no tab switching, no
  footer, and the keybindings live cramped in the top border label.
- fzf is 0.74.1 — new enough for `--style=full`, `--footer`, and the
  per-component border flags.
- pm2's `pm2 jlist` JSON is the single data source: top-level `monit`
  (`memory`, `cpu`) and `pm_id`/`name`, and `pm2_env` (`status`,
  `pm_uptime`, `restart_time`, `exec_mode`, `pm_exec_path`, `pm_cwd`,
  `node_version`, and a real `env` dict). Verified present on this
  machine.

## Components

### 1. `scripts/pm2-fzf-list.sh` — unchanged

Keeps emitting `name ⇥ colored-stats ⇥ out-log ⇥ err-log`. No edits.

### 2. `scripts/pm2-fzf-preview.sh MODE NAME OUT ERR` — new

Single entry point for all three tabs. Dispatches on `MODE`:

- **`logs`** — `tail -q -n 300 -f "$OUT" "$ERR" | tspin`. Identical to
  today's preview (live, tailspin-colored, follows).
- **`info`** — runs `pm2 jlist`, filters to the process named `NAME` in
  python, prints an aligned key/value block:
  `status, uptime, pid, restarts, cpu, memory, exec mode, script
  (basename of pm_exec_path), cwd, node`. Uptime formatted like the list
  generator (`Nd`/`Nh`/`Nm`). One-shot (prints and exits).
- **`env`** — same `pm2 jlist`, prints `pm2_env.env` as sorted
  `KEY  value` lines. One-shot.

Unknown `MODE` defaults to `logs`. A `NAME` not found in jlist prints a
short `no such process` line (info/env) rather than erroring.

### 3. `pmon()` in `zsh/.zsh_aliases` — rewritten

- `--style=full` → bordered input / list / preview panels.
- List border label `Processes`; top prompt stays `pm2 ❯`.
- `--footer` with the keybinding legend:
  `↑↓ move · ⇥ next tab · ^x restart · ^r refresh · / filter · q quit`.
  (Removes the keybinding text from the old top border label.)
- **Mode state file:** `mode=$(mktemp)`, seeded with `logs`; `rm -f
  "$mode"` after fzf returns (so no temp files leak).
- **Preview command:** `pm2-fzf-preview.sh "$(cat "$mode")" {1} {3} {4}`.
- **Preview label = tab bar:** rendered from the mode file via a
  `transform-preview-label`, showing `Logs │ Info │ Env` with the active
  tab highlighted (bright) and the others dimmed, prefixed by the process
  name — e.g. ` auth-service · Logs │ Info │ Env `.
- **`Tab` binding:** advance the mode file (`logs`→`info`→`env`→`logs`),
  then `refresh-preview` and re-render the preview label. The advance may
  be an inline `execute-silent` one-liner or a tiny helper — an
  implementation choice, not a spec requirement.
- **Preview window:** keeps `follow,wrap` and the computed right-hand
  width (`COLUMNS - 44`, falling back to `60%` when narrow), as today.
- **Unchanged binds:** `ctrl-r` reloads the list, `ctrl-x` restarts the
  highlighted process then reloads, `enter` quits (abort). `--ansi`,
  `--delimiter='\t'`, `--with-nth=1,2`, `--tabstop=24`, `--cycle`,
  `--ellipsis='…'`, `--pointer=' '` carry over.

## Data flow

```
pm2-fzf-list.sh ──lines──▶ fzf list (name+stats shown; log paths hidden)
                                │ selection = {1}=name {3}=out {4}=err
      mode file (logs/info/env) │
                                ▼
              pm2-fzf-preview.sh MODE {1} {3} {4}
                 ├─ logs: tail -f OUT ERR | tspin
                 ├─ info: pm2 jlist → filter NAME → key/values
                 └─ env:  pm2 jlist → filter NAME → sorted env
```

## Error handling

- **Stopped process:** logs tab shows existing file contents (or empty,
  no live stream); info tab still renders and its `status` reflects the
  stopped state.
- **Empty `pm2 jlist`:** list is empty, nothing to select — same as
  today.
- **`tspin` / `pm2` missing:** out of scope; both are assumed installed
  (as they are today). No new dependencies are introduced.

## Testing

Interactive fzf can't be asserted headlessly, so verification targets the
preview script, which holds all the new logic:

- `bash -n` on both the new preview script and the rewritten function
  source.
- `pm2-fzf-preview.sh info <real-process-name>` → prints the aligned
  key/value block with a plausible status/uptime.
- `pm2-fzf-preview.sh env <real-process-name>` → prints sorted `KEY
  value` lines.
- `pm2-fzf-preview.sh logs <name> <out> <err>` → streams tailspin output
  (kill after a moment; it follows).
- `pm2-fzf-preview.sh info __nonexistent__` → `no such process`, exit
  clean.
- Manual visual check by the user: run `pmon`, press `Tab` through
  Logs → Info → Env, confirm the tab bar highlights and the footer reads
  correctly.

## Out of scope (YAGNI)

- No `Metrics` tab (pm2 `axm_monitor` exists but the numbers are a static
  snapshot of limited use here).
- No auto-refresh of list stats — `ctrl-r` stays the manual refresh.
- No multi-panel left column (Images/Volumes/etc.) — fzf has a single
  list, and pm2 has one resource type.
