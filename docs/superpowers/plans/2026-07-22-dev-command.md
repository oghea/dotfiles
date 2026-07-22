# `dev` Command Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A `dev` shell command that opens the dev tab (shell + synced lazygit pane), sharing one layout script with the existing `prefix+g` binding.

**Architecture:** New `scripts/dev-tab-open.sh` owns the layout; `bind g` switches from an inline command chain to `run-shell` calling the script; a new `alias dev` in `zsh/.zsh_aliases` calls the same script.

**Tech Stack:** bash, tmux 3.7b, zsh aliases.

## Global Constraints

- The repo has unrelated uncommitted changes. `zsh/.zsh_aliases` itself has unrelated WIP hunks (an `mp` alias, a `pmon` function) that must NOT be committed — this plan stages the new alias via `git apply --cached` with an exact patch (Step 4), never `git add zsh/.zsh_aliases`, and never `git add -A` / `git add .`.
- All work happens in `~/.dotfiles`.
- Always invoke tmux as `command tmux` in interactive verification shells; inside scripts plain `tmux` is fine.
- Verification runs against the user's live tmux server — use throwaway detached sessions named `sdd-*` and always kill them afterwards.

---

### Task 1: Layout script, rewired binding, `dev` alias

**Files:**
- Create: `scripts/dev-tab-open.sh` (mode 755)
- Modify: `tmux/.config/tmux/tmux.conf` (the `bind g` block)
- Modify: `zsh/.zsh_aliases` (insert alias; commit via index patch only)

**Interfaces:**
- Consumes: `scripts/dev-tab-watch.sh` (existing watcher, unchanged).
- Produces: `scripts/dev-tab-open.sh [dir]` — builds the dev-tab layout in the current tmux session; `dir` defaults to `$PWD`.

- [ ] **Step 1: Write the layout script**

Create `scripts/dev-tab-open.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# dev-tab-open.sh — open the dev tab: shell (left) + synced lazygit
# pane (right, via dev-tab-watch.sh). Shared by the tmux prefix+g
# binding and the `dev` shell alias; tmux resolves the target session
# from TMUX_PANE in both paths.
set -eu

[ -n "${TMUX:-}" ] || { echo "dev-tab-open: run inside tmux" >&2; exit 1; }

dir="${1:-$PWD}"
tmux new-window -c "$dir"
tmux split-window -h -l 40% -c "$dir" "$HOME/.dotfiles/scripts/dev-tab-watch.sh"
tmux select-pane -L
```

Then: `chmod +x scripts/dev-tab-open.sh` and `bash -n scripts/dev-tab-open.sh`.

- [ ] **Step 2: Rewire the tmux binding**

In `tmux/.config/tmux/tmux.conf`, replace:

```tmux
# Dev tab: shell (left, for Claude Code) + synced lazygit pane (right).
# The watcher follows the left pane's directory: lazygit for its repo,
# a placeholder when there is none. It exports LG_CONFIG_FILE itself.
bind g new-window -c "#{pane_current_path}" \; \
  split-window -h -l 40% -c "#{pane_current_path}" '~/.dotfiles/scripts/dev-tab-watch.sh' \; \
  select-pane -L
```

with:

```tmux
# Dev tab: shell (left, for Claude Code) + synced lazygit pane (right).
# The watcher follows the left pane's directory: lazygit for its repo,
# a placeholder when there is none. Layout lives in dev-tab-open.sh,
# shared with the `dev` shell alias.
bind g run-shell "~/.dotfiles/scripts/dev-tab-open.sh '#{pane_current_path}'"
```

- [ ] **Step 3: Add the alias to the working tree**

In `zsh/.zsh_aliases`, insert after the `alias sod=...` line and its following blank line (immediately before the `# Profiles: named tmux session per context...` comment block):

```zsh
# Dev tab: shell + synced lazygit pane (same layout as Ctrl-a g)
alias dev='~/.dotfiles/scripts/dev-tab-open.sh'

```

(Three lines: comment, alias, trailing blank line.)

- [ ] **Step 4: Stage ONLY the alias hunk via index patch**

The file's other working-tree changes (the `mp` alias near the top and the `pmon` function at the bottom) are the user's WIP and must stay uncommitted. The index for this file currently equals HEAD, so apply exactly this patch to the index only:

```bash
cd ~/.dotfiles
git apply --cached <<'EOF'
diff --git a/zsh/.zsh_aliases b/zsh/.zsh_aliases
--- a/zsh/.zsh_aliases
+++ b/zsh/.zsh_aliases
@@ -42,4 +42,7 @@
 alias eod="bash ~/.dotfiles/scripts/workday-end.sh"
 alias sod="bash ~/.dotfiles/scripts/workday-start.sh"
 
+# Dev tab: shell + synced lazygit pane (same layout as Ctrl-a g)
+alias dev='~/.dotfiles/scripts/dev-tab-open.sh'
+
 # Profiles: named tmux session per context (work/personal git identity
EOF
git diff --cached --stat
```

Expected: `zsh/.zsh_aliases | 3 +++`. Then confirm the WIP is still unstaged: `git diff zsh/.zsh_aliases` must still show the `mp` and `pmon` hunks (and NOT the dev alias, which is now identical in index and working tree).

If `git apply --cached` fails, STOP and report BLOCKED with the error — do not fall back to `git add`.

- [ ] **Step 5: Reload tmux config and verify the binding**

Run: `command tmux source-file ~/.config/tmux/tmux.conf && command tmux list-keys | grep 'bind-key.*prefix.*g '`
Expected: the `g` binding shows `run-shell` with `dev-tab-open.sh`.

- [ ] **Step 6: Functional check in a throwaway session**

```bash
command tmux new-session -d -s sdd-cmd -c ~/.dotfiles
# Path 1: direct script call from inside a pane (what the alias does)
command tmux send-keys -t sdd-cmd.1 '~/.dotfiles/scripts/dev-tab-open.sh' Enter
sleep 3
command tmux list-windows -t sdd-cmd -F '#{window_index} #{window_panes}'
# Path 2: the binding's run-shell form
command tmux run-shell -t sdd-cmd:1.1 "~/.dotfiles/scripts/dev-tab-open.sh '#{pane_current_path}'"
sleep 3
command tmux list-windows -t sdd-cmd -F '#{window_index} #{window_panes}'
# Both new windows: 2 panes, left active, watcher alive on the right
command tmux list-panes -t sdd-cmd:2 -F '#{pane_index} #{pane_width} active=#{pane_active}'
command tmux kill-session -t sdd-cmd 2>/dev/null
```

Expected: after Path 1, windows list shows a window 2 with 2 panes (in the sdd-cmd session, NOT in any other session); after Path 2, a window 3 with 2 panes; the pane listing shows pane 1 active and pane 2 at ~40% width. If a new window appears in the wrong session, STOP and report BLOCKED with the output.

Also verify the outside-tmux guard:
`env -u TMUX ~/.dotfiles/scripts/dev-tab-open.sh; echo "exit=$?"`
Expected: `dev-tab-open: run inside tmux` and `exit=1`.

- [ ] **Step 7: Commit**

```bash
cd ~/.dotfiles
git add scripts/dev-tab-open.sh tmux/.config/tmux/tmux.conf
# zsh/.zsh_aliases is already staged from Step 4 — do NOT git add it
git commit -m "tmux: extract dev tab layout into script, add dev alias"
```

Expected in `git show --stat HEAD`: exactly 3 files — `scripts/dev-tab-open.sh`, `tmux/.config/tmux/tmux.conf`, `zsh/.zsh_aliases` (+3 lines only).
