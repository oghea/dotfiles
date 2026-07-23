# Dev Tab Files + Diff View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace lazygit in the dev tab (both `dev` and `Ctrl-a g`) with a read-only fzf "what changed" view — changed-files list + delta diff of the selected file, lazygit-style modal keys, ~2s auto-refresh.

**Architecture:** A new self-contained `scripts/dev-tab-diff.sh` (with `list` / `preview` subcommands it calls back into, plus the fzf UI) is dropped in as the viewer. `scripts/dev-tab-watch.sh`'s hardcoded `lazygit` line is swapped to launch it; the follow-loop is otherwise untouched, so both entry points inherit the new view plus repo-following.

**Tech Stack:** bash/sh, fzf 0.74.1, git, delta, tmux 3.7b.

## Global Constraints

- The repo has unrelated uncommitted changes (`lazygit` config, `nvim/`, `scripts/workday-start.sh`, `zsh/.zsh_aliases`, `markdownlint/`, `nvim …/markdown.lua`) — every commit must `git add` exact paths, never `git add -A` or `git add .`. This feature does NOT touch `zsh/.zsh_aliases`, so no selective staging is needed; just stage the exact files each task changes.
- All work happens in `~/.dotfiles`.
- Inside scripts, plain `tmux` is correct (the zsh alias only affects interactive shells). In interactive verification shells, use `command tmux`.
- Verification uses throwaway detached tmux sessions named `sdd-*`, always killed afterwards.
- delta flags mirror the lazygit pager: `delta --dark --paging=never --line-numbers`.

---

### Task 1: `dev-tab-diff.sh` viewer

**Files:**
- Create: `scripts/dev-tab-diff.sh` (mode 755)

**Interfaces:**
- Consumes: `git`, `delta`, `fzf`, `tmux` (for the refresh ticker); `TMUX_PANE`.
- Produces: `dev-tab-diff.sh <root>` (fzf UI), `dev-tab-diff.sh list <root>`, `dev-tab-diff.sh preview <root> <status> <path>`. Consumed by `dev-tab-watch.sh` in Task 2 as `dev-tab-diff.sh "$root"`.

- [ ] **Step 1: Write the script**

Create `scripts/dev-tab-diff.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# dev-tab-diff.sh — read-only "what changed" viewer for the dev tab.
# Launched by dev-tab-watch.sh with a git repo root. Three modes:
#   dev-tab-diff.sh list <root>               → changed-files list for fzf
#   dev-tab-diff.sh preview <root> <st> <path> → delta diff of one file
#   dev-tab-diff.sh <root>                    → the fzf UI (default)
# The fzf reload/preview binds call back into this same script. Auto-
# refresh is a background ticker that sends ctrl-r to this pane every 2s,
# triggering the same reload as a manual ctrl-r. Read-only: no staging,
# commit, or branch actions — use `lg` (lazygit) for those.
set -u

self="$HOME/.dotfiles/scripts/dev-tab-diff.sh"

case "${1:-}" in
  list)
    root="${2:-}"
    out=$(git -C "$root" status --porcelain=v1 2>/dev/null)
    if [ -z "$out" ]; then
      printf '✓ working tree clean\n'
    else
      # porcelain "XY path" → "XY<TAB>path": fzf field 1=status, 2=path
      printf '%s\n' "$out" | sed 's/^\(..\) /\1\t/'
    fi
    exit 0
    ;;
  preview)
    root="${2:-}"; status="${3:-}"; path="${4:-}"
    [ -n "$path" ] || exit 0          # sentinel line ("working tree clean") has no path
    if [ "$status" = '??' ]; then
      git -C "$root" diff --no-index -- /dev/null "$path" 2>/dev/null
    else
      git -C "$root" diff HEAD -- "$path" 2>/dev/null
    fi | delta --dark --paging=never --line-numbers
    exit 0
    ;;
esac

# --- default: the fzf UI ---
root="${1:-$PWD}"
list="$self list '$root'"

# Auto-refresh: nudge this pane with ctrl-r every 2s (same as manual ^r).
pane="${TMUX_PANE:-}"
ticker=""
if [ -n "$pane" ]; then
  ( while sleep 2; do tmux send-keys -t "$pane" C-r 2>/dev/null || exit 0; done ) &
  ticker=$!
fi

FZF_DEFAULT_COMMAND="$list" fzf \
  --ansi --delimiter='\t' --with-nth=1,2 --style=full \
  --layout=reverse --info=hidden --cycle --pointer=' ' \
  --list-label=' changed ' --border-label=' diff ' --border-label-pos=3 \
  --footer=' j/k file · ^f/^b scroll · ^d/^u half · ^r refresh · q quit ' \
  --preview="$self preview '$root' {1} {2}" \
  --preview-label-pos=3 \
  --bind="focus:transform-preview-label:printf ' %s ' {2}" \
  --bind='j:down,k:up' \
  --bind='ctrl-f:preview-page-down,ctrl-b:preview-page-up' \
  --bind='ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up' \
  --bind="ctrl-r:reload($list)+refresh-preview" \
  --bind='q:abort' \
  --bind='enter:abort'

[ -n "$ticker" ] && kill "$ticker" 2>/dev/null
exit 0
```

Then: `chmod +x scripts/dev-tab-diff.sh`

- [ ] **Step 2: Syntax check**

Run: `bash -n ~/.dotfiles/scripts/dev-tab-diff.sh && echo OK`
Expected: `OK`

- [ ] **Step 3: `list` on a dirty repo**

`~/.dotfiles` currently has uncommitted changes, so it's a good dirty repo.
Run: `~/.dotfiles/scripts/dev-tab-diff.sh list ~/.dotfiles`
Expected: one line per change, each as `<status><TAB><path>`, e.g. a line containing `zsh/.zsh_aliases` and a `??` line for an untracked path like `markdownlint/`. (Pipe to `cat -A` if you want to see the literal tab.)

- [ ] **Step 4: `list` on a clean repo**

```bash
D=$(mktemp -d); git -C "$D" init -q; git -C "$D" commit -q --allow-empty -m init
~/.dotfiles/scripts/dev-tab-diff.sh list "$D"
rm -rf "$D"
```
Expected: exactly `✓ working tree clean`.

- [ ] **Step 5: `preview` for a tracked modified file**

Pick a real modified tracked file from Step 3 (e.g. `zsh/.zsh_aliases`) and its status:
Run: `~/.dotfiles/scripts/dev-tab-diff.sh preview ~/.dotfiles ' M' zsh/.zsh_aliases | sed 's/\x1b\[[0-9;]*m//g' | head`
Expected: delta-rendered diff lines (a file header and +/- lines, line-number gutter), no error. (If `zsh/.zsh_aliases` isn't modified in your tree, substitute any file shown with a modified status in Step 3.)

- [ ] **Step 6: `preview` for an untracked file**

Pick a real untracked file from Step 3 (a `??` line). If `nvim/.config/nvim/lua/plugins/markdown.lua` is untracked, use it:
Run: `~/.dotfiles/scripts/dev-tab-diff.sh preview ~/.dotfiles '??' nvim/.config/nvim/lua/plugins/markdown.lua | sed 's/\x1b\[[0-9;]*m//g' | head`
Expected: delta output showing the file as all-added (a `--no-index` diff), no error. (Substitute any `??` path from Step 3 if that file doesn't exist.)

- [ ] **Step 7: `preview` with empty path (sentinel selected) prints nothing**

Run: `~/.dotfiles/scripts/dev-tab-diff.sh preview ~/.dotfiles '✓ working tree clean' ''; echo "exit=$?"`
Expected: no output, then `exit=0`.

- [ ] **Step 8: Commit**

```bash
cd ~/.dotfiles
git add scripts/dev-tab-diff.sh
git commit -m "dev-tab: add read-only files+diff fzf viewer"
```
Expected: `git show --stat HEAD` lists exactly one file, `scripts/dev-tab-diff.sh`.

---

### Task 2: Swap the watcher's viewer + cheatsheet

**Files:**
- Modify: `scripts/dev-tab-watch.sh` (comment block lines 2–7; remove the `LG_CONFIG_FILE` export line 13; the viewer line 48; the `lg_pid` variable name on lines 49, 51, 60, 61)
- Modify: `CHEATSHEET.md` (the `Ctrl-a g` row)

**Interfaces:**
- Consumes: `scripts/dev-tab-diff.sh` (Task 1).
- Produces: the dev tab's right pane now runs the files+diff viewer for both `dev` and `Ctrl-a g`.

- [ ] **Step 1: Update the header comment**

In `scripts/dev-tab-watch.sh`, replace the comment block (lines 2–7):

```bash
# dev-tab-watch.sh — right-hand pane of the Ctrl-a g dev tab.
# Follows the sibling (left) pane's directory: runs lazygit rooted at
# that repo, restarts it when the sibling moves to a different repo,
# and shows a placeholder instead of lazygit's init prompt when the
# sibling isn't inside a git repo. Exits when the sibling pane closes
# or when lazygit is quit with q.
```

with:

```bash
# dev-tab-watch.sh — right-hand pane of the dev tab (dev / Ctrl-a g).
# Follows the sibling (left) pane's directory: runs the read-only
# files+diff viewer (dev-tab-diff.sh) rooted at that repo, restarts it
# when the sibling moves to a different repo, and shows a placeholder
# when the sibling isn't inside a git repo. Exits when the sibling pane
# closes or when the viewer is quit with q.
```

- [ ] **Step 2: Remove the now-unused LG_CONFIG_FILE export**

In `scripts/dev-tab-watch.sh`, delete line 13 (lazygit is no longer launched here):

```bash
export LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml"
```

(Delete the whole line. The blank line above it, separating the guard from the `poll_sibling` comment, stays.)

- [ ] **Step 3: Swap the viewer and rename `lg_pid` → `viewer_pid`**

In `scripts/dev-tab-watch.sh`, the viewer block currently reads:

```bash
  lazygit --path "$root" &
  lg_pid=$!
  status=user_quit
  while kill -0 "$lg_pid" 2>/dev/null; do
    sleep "$POLL"
    state=$(poll_sibling) || { status=sibling_gone; break; }
    new_root=${state#*$'\t'}
    if [ "$new_root" != "$root" ]; then
      status=moved
      break
    fi
  done
  [ "$status" != user_quit ] && kill "$lg_pid" 2>/dev/null
  wait "$lg_pid" 2>/dev/null
```

Replace it with (viewer line changed; `lg_pid` renamed to `viewer_pid` throughout this block):

```bash
  "$HOME/.dotfiles/scripts/dev-tab-diff.sh" "$root" &
  viewer_pid=$!
  status=user_quit
  while kill -0 "$viewer_pid" 2>/dev/null; do
    sleep "$POLL"
    state=$(poll_sibling) || { status=sibling_gone; break; }
    new_root=${state#*$'\t'}
    if [ "$new_root" != "$root" ]; then
      status=moved
      break
    fi
  done
  [ "$status" != user_quit ] && kill "$viewer_pid" 2>/dev/null
  wait "$viewer_pid" 2>/dev/null
```

- [ ] **Step 4: Syntax check**

Run: `bash -n ~/.dotfiles/scripts/dev-tab-watch.sh && echo OK`
Expected: `OK`

- [ ] **Step 5: Update the cheatsheet row**

In `CHEATSHEET.md`, replace:

```markdown
| `Ctrl-a g` | Dev tab: shell + lazygit pane synced to left pane's repo |
```

with:

```markdown
| `Ctrl-a g` | Dev tab: shell + live read-only files/diff pane (lazygit via `lg`) |
```

- [ ] **Step 6: Functional check — viewer launches, follows, placeholder**

```bash
mkdir -p /private/tmp/sdd-nogit && git init -q /private/tmp/sdd-repo3
command tmux new-session -d -s sdd-diff -c /private/tmp/sdd-nogit
command tmux split-window -h -l 40% -t sdd-diff -c /private/tmp/sdd-nogit '~/.dotfiles/scripts/dev-tab-watch.sh'
sleep 2
echo "--- no-repo placeholder (expect PLACEHOLDER-OK):"
command tmux capture-pane -p -t sdd-diff:1.2 | grep -q 'no git repository' && echo PLACEHOLDER-OK
command tmux send-keys -t sdd-diff:1.1 'cd ~/.dotfiles' Enter
sleep 3
echo "--- viewer process when sibling is in a repo (expect fzf, NOT lazygit):"
command tmux list-panes -t sdd-diff:1 -F '#{pane_index} #{pane_current_command}'
echo "--- pane 2 shows the changed-files UI (expect 'changed' label or a diff/status line):"
command tmux capture-pane -p -t sdd-diff:1.2 | grep -qiE 'changed|working tree clean|\.(ts|lua|sh|md|yml)' && echo VIEWER-OK
command tmux kill-session -t sdd-diff 2>/dev/null
rm -rf /private/tmp/sdd-nogit /private/tmp/sdd-repo3
```
Expected: `PLACEHOLDER-OK`; pane 2's `#{pane_current_command}` is `fzf` (or `dev-tab-diff.sh`/`bash`), NOT `lazygit`; `VIEWER-OK`. Record actual output. If pane 2 shows `lazygit`, the swap didn't take — STOP and report BLOCKED.

- [ ] **Step 7: Commit**

```bash
cd ~/.dotfiles
git add scripts/dev-tab-watch.sh CHEATSHEET.md
git commit -m "dev-tab: swap lazygit for the files+diff viewer"
```
Expected: `git show --stat HEAD` lists exactly two files — `scripts/dev-tab-watch.sh` and `CHEATSHEET.md`.

- [ ] **Step 8: Manual visual check (user-run, not automated)**

Note for the controller: leave this for the user. In a fresh shell inside tmux: run `dev` (and separately press `Ctrl-a g`), and confirm:
- right pane shows the `changed` files list + a `diff` preview panel with the footer legend;
- `j`/`k` move between files and the diff follows;
- `ctrl-f`/`ctrl-b` page the diff, `ctrl-d`/`ctrl-u` half-page;
- editing a file updates the list/diff within ~2s;
- a clean repo shows `✓ working tree clean`;
- `q` quits; lazygit is no longer launched here (`lg` still opens it).
