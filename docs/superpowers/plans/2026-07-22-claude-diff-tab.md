# Claude Code + Live Diff Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A tmux keybind (`prefix+g`) that opens a two-pane "dev tab" — shell on the left for Claude Code, live lazygit+delta diff view on the right.

**Architecture:** Three independent config changes in the dotfiles repo: (1) install the `git-delta` pager via Brewfile, (2) a new lazygit `config.yml` that pipes diffs through delta, wired up via the `LG_CONFIG_FILE` env var because macOS lazygit defaults to `~/Library/Application Support`, (3) a one-line tmux binding that builds the window layout.

**Tech Stack:** Homebrew, lazygit, git-delta, tmux 3.7b, GNU stow (already applied — `~/.config/lazygit` is a live symlink into this repo).

## Global Constraints

- Do NOT touch `~/.gitconfig` (work/personal identity split lives there, outside this repo).
- The repo has unrelated uncommitted changes (`nvim/`, `scripts/workday-start.sh`, `zsh/.zsh_aliases`, `markdownlint/`) — every commit must `git add` exact paths, never `git add -A` or `git add .`.
- All work happens in `~/.dotfiles`.
- tmux is 3.7b: use `-l 40%` for split sizes (`-p` is deprecated).

---

### Task 1: Install git-delta

**Files:**
- Modify: `Brewfile` (Git section, lines 28–31)

**Interfaces:**
- Produces: `delta` binary on PATH, consumed by Task 2's lazygit pager config.

- [ ] **Step 1: Install delta**

Run: `brew install git-delta`
Expected: installs successfully; `delta --version` prints `delta 0.18.x` (or newer).

- [ ] **Step 2: Add to Brewfile**

In `Brewfile`, change the Git section:

```ruby
# Git
brew "gh"         # GitHub CLI
brew "git-delta"  # Syntax-highlighting pager for git diffs (used by lazygit)
brew "git-lfs"    # Git Large File Storage
brew "lazygit"    # Terminal UI for git
```

- [ ] **Step 3: Verify Brewfile is satisfied**

Run: `brew bundle check --file ~/.dotfiles/Brewfile`
Expected: `The Brewfile's dependencies are satisfied.`

- [ ] **Step 4: Commit**

```bash
cd ~/.dotfiles
git add Brewfile
git commit -m "brew: add git-delta for fancy diffs"
```

---

### Task 2: lazygit config with delta pager

**Files:**
- Create: `lazygit/.config/lazygit/config.yml`
- Modify: `zsh/.zsh_exports` (append at end)

**Interfaces:**
- Consumes: `delta` binary from Task 1.
- Produces: lazygit renders all diffs through delta; `LG_CONFIG_FILE` env var points lazygit at the stowed config. Task 3's tmux binding sets the same var inline.

- [ ] **Step 1: Create the lazygit config**

Create `lazygit/.config/lazygit/config.yml`:

```yaml
# Diffs rendered through delta (see Brewfile: git-delta).
# lazygit on macOS looks in ~/Library/Application Support/lazygit by
# default; LG_CONFIG_FILE (set in zsh/.zsh_exports and in the tmux
# prefix+g binding) points it at this stowed file instead.
git:
  paging:
    colorArg: always
    pager: delta --dark --paging=never --line-numbers
```

Note: `~/.config/lazygit` is already a stow symlink to `~/.dotfiles/lazygit/.config/lazygit`, so the file is immediately visible at `~/.config/lazygit/config.yml` — no restow needed.

- [ ] **Step 2: Verify the symlinked path resolves**

Run: `cat ~/.config/lazygit/config.yml`
Expected: prints the YAML above.

- [ ] **Step 3: Export LG_CONFIG_FILE for shells**

Append to `zsh/.zsh_exports`:

```bash

# lazygit — use the stowed config (macOS default is ~/Library/Application Support)
export LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml"
```

- [ ] **Step 4: Verify delta renders a diff**

Run: `cd ~/.dotfiles && git log -1 -p --color=never | delta --dark --paging=never --line-numbers | head -20`
Expected: syntax-highlighted output with a line-number gutter, no errors.

- [ ] **Step 5: Verify lazygit accepts the config**

Run: `LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml" lazygit --print-config-dir`
Expected: prints a path and exits 0 (no YAML parse error printed).

- [ ] **Step 6: Commit**

```bash
cd ~/.dotfiles
git add lazygit/.config/lazygit/config.yml zsh/.zsh_exports
git commit -m "lazygit: render diffs through delta"
```

---

### Task 3: tmux prefix+g dev tab + cheatsheet

**Files:**
- Modify: `tmux/.config/tmux/tmux.conf` (Windows section, after `bind p previous-window`; and `@resurrect-processes` line)
- Modify: `CHEATSHEET.md` (tmux table)

**Interfaces:**
- Consumes: lazygit + `LG_CONFIG_FILE` behavior from Task 2 (the binding sets the var inline because tmux runs pane commands via `/bin/sh -c`, which never sources `.zsh_exports`).

- [ ] **Step 1: Add the binding**

In `tmux/.config/tmux/tmux.conf`, in the `# --- Windows ---` section, after `bind p previous-window`, add:

```tmux
# Dev tab: shell (left, for Claude Code) + lazygit diff watcher (right).
# LG_CONFIG_FILE is set inline because tmux runs pane commands via
# /bin/sh -c, which doesn't source .zsh_exports.
bind g new-window -c "#{pane_current_path}" \; \
  split-window -h -l 40% -c "#{pane_current_path}" 'LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml" lazygit' \; \
  select-pane -L
```

- [ ] **Step 2: Add lazygit to resurrect processes**

In the same file, change:

```tmux
set -g @resurrect-processes 'btop lazydocker'
```

to:

```tmux
set -g @resurrect-processes 'btop lazydocker lazygit'
```

- [ ] **Step 3: Reload and verify the binding is registered**

Run: `command tmux source-file ~/.config/tmux/tmux.conf && command tmux list-keys | grep 'bind-key.*prefix.*g '`
Expected: one line showing `g` bound to `new-window ... split-window ... lazygit ... select-pane -L`. (Skip the source-file if no tmux server is running; then just start tmux and check.)

- [ ] **Step 4: Functional check**

In a tmux session inside a git repo, press `Ctrl-a g`.
Expected: new window; left pane is a shell in the same directory and has focus; right pane (~40% width) runs lazygit; diffs in lazygit show delta's line-number gutter and syntax colors. Edit any tracked file and confirm lazygit's Files panel refreshes.

- [ ] **Step 5: Add cheatsheet row**

In `CHEATSHEET.md`, in the tmux table, after the `| `Ctrl-a c` | New window |` row, add:

```markdown
| `Ctrl-a g` | Dev tab: shell + lazygit diff pane |
```

- [ ] **Step 6: Commit**

```bash
cd ~/.dotfiles
git add tmux/.config/tmux/tmux.conf CHEATSHEET.md
git commit -m "tmux: prefix+g dev tab with lazygit diff pane"
```

---

### Task 4: Correct the spec's resurrect claim

**Files:**
- Modify: `docs/superpowers/specs/2026-07-22-claude-diff-tab-design.md`

**Interfaces:**
- Consumes: nothing; documentation fix only. The spec says lazygit was already in `@resurrect-processes`; it wasn't — Task 3 added it.

- [ ] **Step 1: Fix the spec**

In the spec's Context section, change:

```markdown
- lazygit is already installed and already listed in
  `@resurrect-processes`, so the layout survives tmux restarts.
```

to:

```markdown
- lazygit is already installed; it gets added to
  `@resurrect-processes` so the layout survives tmux restarts.
```

- [ ] **Step 2: Commit**

```bash
cd ~/.dotfiles
git add docs/superpowers/specs/2026-07-22-claude-diff-tab-design.md
git commit -m "docs: fix resurrect claim in diff-tab spec"
```
