# Dev Tab Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The `prefix+g` dev tab's right pane follows the left pane's directory — lazygit for whatever repo the left pane is in, a "no git repository" placeholder otherwise — instead of launching lazygit once in a fixed directory.

**Architecture:** A watcher script (`scripts/dev-tab-watch.sh`) runs in the right pane. It polls the sibling pane's `#{pane_current_path}` once a second, resolves it to a git toplevel, and runs lazygit rooted there — killing and relaunching it when the resolved root changes. The tmux binding launches the script instead of bare lazygit.

**Tech Stack:** bash, tmux 3.7b, lazygit (with the existing delta config from `~/.config/lazygit/config.yml`).

## Global Constraints

- The repo has unrelated uncommitted changes (`nvim/`, `scripts/workday-start.sh`, `zsh/.zsh_aliases`, `markdownlint/`) — every commit must `git add` exact paths, never `git add -A` or `git add .`.
- All work happens in `~/.dotfiles`.
- Always invoke tmux as `command tmux` in interactive verification shells (a zsh plugin aliases bare `tmux`); inside scripts plain `tmux` is fine (aliases don't apply).
- Verification runs against the user's live tmux server — use throwaway detached sessions named `sdd-*` and always kill them afterwards.

---

### Task 1: Watcher script + rewire binding

**Files:**
- Create: `scripts/dev-tab-watch.sh` (mode 755)
- Modify: `tmux/.config/tmux/tmux.conf` (the `bind g` block and the `@resurrect-processes` line)
- Modify: `CHEATSHEET.md` (the `Ctrl-a g` row)

**Interfaces:**
- Consumes: `~/.config/lazygit/config.yml` (existing stowed delta config), `TMUX_PANE` (set by tmux in every pane).
- Produces: `scripts/dev-tab-watch.sh`, self-contained, no arguments — it discovers its sibling pane itself.

- [ ] **Step 1: Write the script**

Create `scripts/dev-tab-watch.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# dev-tab-watch.sh — right-hand pane of the Ctrl-a g dev tab.
# Follows the sibling (left) pane's directory: runs lazygit rooted at
# that repo, restarts it when the sibling moves to a different repo,
# and shows a placeholder instead of lazygit's init prompt when the
# sibling isn't inside a git repo. Exits when the sibling pane closes
# or when lazygit is quit with q.
set -u

POLL=1
SELF="${TMUX_PANE:-}"
[ -n "$SELF" ] || { echo "dev-tab-watch: must run inside tmux" >&2; exit 1; }
export LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml"

# Prints "<dir>\t<root>" for the sibling pane; root is empty when the
# directory is not inside a git repo. Returns 1 when the sibling pane
# is gone.
poll_sibling() {
  local sib dir root
  sib=$(tmux list-panes -t "$SELF" -F '#{pane_id}' | grep -vx "$SELF" | head -n1) || true
  [ -n "$sib" ] || return 1
  dir=$(tmux display-message -p -t "$sib" '#{pane_current_path}' 2>/dev/null) || return 1
  root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)
  printf '%s\t%s' "$dir" "$root"
}

show_placeholder() {
  clear
  printf '\n\n   no git repository\n\n   %s\n\n   waiting — cd into a repo in the left pane…\n' "$1"
}

shown_dir=""
while :; do
  state=$(poll_sibling) || exit 0
  dir=${state%%$'\t'*}
  root=${state#*$'\t'}

  if [ -z "$root" ]; then
    if [ "$dir" != "$shown_dir" ]; then
      show_placeholder "$dir"
      shown_dir=$dir
    fi
    sleep "$POLL"
    continue
  fi
  shown_dir=""

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
  tput rmcup 2>/dev/null || true
  [ "$status" = moved ] || exit 0
done
```

Then: `chmod +x scripts/dev-tab-watch.sh`

- [ ] **Step 2: Syntax-check the script**

Run: `bash -n ~/.dotfiles/scripts/dev-tab-watch.sh && echo OK`
Expected: `OK`

- [ ] **Step 3: Rewire the tmux binding**

In `tmux/.config/tmux/tmux.conf`, replace:

```tmux
# Dev tab: shell (left, for Claude Code) + lazygit diff watcher (right).
# LG_CONFIG_FILE is set inline because tmux runs pane commands in a
# non-interactive shell, which doesn't source .zsh_exports.
bind g new-window -c "#{pane_current_path}" \; \
  split-window -h -l 40% -c "#{pane_current_path}" 'LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml" lazygit' \; \
  select-pane -L
```

with:

```tmux
# Dev tab: shell (left, for Claude Code) + synced lazygit pane (right).
# The watcher follows the left pane's directory: lazygit for its repo,
# a placeholder when there is none. It exports LG_CONFIG_FILE itself.
bind g new-window -c "#{pane_current_path}" \; \
  split-window -h -l 40% -c "#{pane_current_path}" '~/.dotfiles/scripts/dev-tab-watch.sh' \; \
  select-pane -L
```

- [ ] **Step 4: Update resurrect processes**

In the same file, change:

```tmux
set -g @resurrect-processes 'btop lazydocker lazygit'
```

to:

```tmux
set -g @resurrect-processes 'btop lazydocker lazygit "~dev-tab-watch.sh"'
```

(Restore is best-effort: depending on which process resurrect captures, a restored pane may come back as bare lazygit instead of the watcher — acceptable degradation.)

- [ ] **Step 5: Update the cheatsheet row**

In `CHEATSHEET.md`, change:

```markdown
| `Ctrl-a g` | Dev tab: shell + lazygit diff pane |
```

to:

```markdown
| `Ctrl-a g` | Dev tab: shell + lazygit pane synced to left pane's repo |
```

- [ ] **Step 6: Reload tmux config and verify the binding**

Run: `command tmux source-file ~/.config/tmux/tmux.conf && command tmux list-keys | grep 'bind-key.*prefix.*g '`
Expected: the `g` binding now shows `dev-tab-watch.sh` instead of `lazygit`.

- [ ] **Step 7: Functional check in a throwaway session**

```bash
mkdir -p /private/tmp/sdd-nogit && git init -q /private/tmp/sdd-repo2
command tmux new-session -d -s sdd-sync -c /private/tmp/sdd-nogit
command tmux split-window -h -l 40% -t sdd-sync -c /private/tmp/sdd-nogit '~/.dotfiles/scripts/dev-tab-watch.sh'
sleep 2
command tmux capture-pane -p -t sdd-sync.2 | grep -q 'no git repository' && echo PLACEHOLDER-OK
command tmux send-keys -t sdd-sync.1 'cd ~/.dotfiles' Enter
sleep 3
command tmux list-panes -t sdd-sync -F '#{pane_index} #{pane_current_command}'
command tmux send-keys -t sdd-sync.1 'cd /private/tmp/sdd-repo2' Enter
sleep 3
command tmux display -p -t sdd-sync.2 '#{pane_current_command}'
command tmux send-keys -t sdd-sync.1 'cd /private/tmp/sdd-nogit' Enter
sleep 3
command tmux capture-pane -p -t sdd-sync.2 | grep -q 'no git repository' && echo BACK-TO-PLACEHOLDER-OK
command tmux kill-pane -t sdd-sync.1
sleep 3
command tmux has-session -t sdd-sync 2>/dev/null || echo SIBLING-GONE-OK
command tmux kill-session -t sdd-sync 2>/dev/null
rm -rf /private/tmp/sdd-nogit /private/tmp/sdd-repo2
```

Expected, in order: `PLACEHOLDER-OK`; pane 2's command is `lazygit` after the cd into `~/.dotfiles`; still `lazygit` (relaunched) in `sdd-repo2`; `BACK-TO-PLACEHOLDER-OK`; `SIBLING-GONE-OK` (killing the left pane ends the watcher, closing the only remaining pane and thus the session). Record actual output in the report. If a step's output differs, investigate before committing.

- [ ] **Step 8: Commit**

```bash
cd ~/.dotfiles
git add scripts/dev-tab-watch.sh tmux/.config/tmux/tmux.conf CHEATSHEET.md
git commit -m "tmux: dev tab lazygit pane follows left pane's repo"
```
