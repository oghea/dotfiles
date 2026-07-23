# Dev Tab tig Viewer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the custom fzf `dev-tab-diff.sh` with `tig status` as the dev tab's viewer — native keyboard-driven files+diff with live refresh that preserves position.

**Architecture:** Install tig, add a stowed tigrc (auto-refresh + side-by-side split), swap the watcher's viewer line to launch `tig status` in the repo root (single process, so the watcher's existing single-PID teardown works), delete the fzf viewer, update the cheatsheet.

**Tech Stack:** tig, tmux 3.7b, git, GNU stow, Homebrew.

## Global Constraints

- All work happens in `~/.dotfiles`. The repo has unrelated uncommitted changes (`lazygit` config, `nvim/`, `scripts/workday-start.sh`, `zsh/.zsh_aliases`, `markdownlint/`, `nvim …/markdown.lua`) — this feature touches NONE of them; stage only the exact files this task changes, never `git add -A` / `git add .`.
- Inside scripts, plain `tmux` is correct (the zsh alias only affects interactive shells). In interactive verification shells, use `command tmux`.
- Verification uses throwaway detached tmux sessions named `sdd-*`, always killed afterwards.
- `~/.config/tig` is a stow target; the repo package is `tig/.config/tig/`.

---

### Task 1: Install tig, add config, swap viewer, delete fzf viewer, cheatsheet

**Files:**
- Create: `tig/.config/tig/config`
- Modify: `Brewfile` (Git section)
- Modify: `scripts/dev-tab-watch.sh` (header comment lines 2–7; viewer line 47)
- Delete: `scripts/dev-tab-diff.sh`
- Modify: `CHEATSHEET.md` (the `Ctrl-a g` row)

**Interfaces:**
- Consumes: the existing `dev-tab-watch.sh` follow-loop (unchanged except the viewer line) and `dev-tab-open.sh` (unchanged).
- Produces: the dev tab's right pane runs `tig status` rooted at the sibling pane's repo.

- [ ] **Step 1: Install tig and add it to the Brewfile**

Run: `brew install tig` (expected: installs; `tig --version` prints e.g. `tig version 2.5.x`).

Then in `Brewfile`, in the `# Git` section, add a `tig` line so it reads:

```ruby
# Git
brew "gh"         # GitHub CLI
brew "git-delta"  # Syntax-highlighting pager for git diffs (used by lazygit)
brew "git-lfs"    # Git Large File Storage
brew "lazygit"    # Terminal UI for git
brew "tig"        # ncurses git browser — powers the dev tab's files/diff pane
```

(Keep whatever other lines already exist in the Git section; just add the `tig` line after `lazygit`.)

- [ ] **Step 2: Verify the Brewfile is satisfied**

Run: `brew bundle check --file ~/.dotfiles/Brewfile`
Expected: `The Brewfile's dependencies are satisfied.`

- [ ] **Step 3: Create the tig config**

Create `tig/.config/tig/config` with exactly this content:

```
# tig config — powers the dev tab's files/diff pane (see dev-tab-watch.sh).
# Auto-refresh keeps the status view current as the working tree changes
# without losing the cursor/scroll position; vertical split puts the file
# list and the diff side by side.
set refresh-mode = auto
set vertical-split = yes
```

- [ ] **Step 4: Verify the config resolves via stow**

`~/.config/tig` is a stow target. Confirm the file is reachable through the symlink:

Run: `test -e ~/.config/tig/config && readlink ~/.config/tig && echo LINKED || echo "run: cd ~/.dotfiles && stow tig"`

If it prints the `stow tig` hint, run `cd ~/.dotfiles && stow tig` (creates the `~/.config/tig` symlink into the repo), then re-run the test until it prints the symlink target and `LINKED`.

(Don't try to run `tig` here to check config parsing — tig reads the controlling terminal, not piped stdin, so it can't be exercised headlessly. A malformed config surfaces as an on-screen error in Step 10's real-tty tmux run, which is where tig actually loads.)

- [ ] **Step 5: Swap the watcher's viewer line**

In `scripts/dev-tab-watch.sh`, replace the viewer launch line (line 47):

```bash
  "$HOME/.dotfiles/scripts/dev-tab-diff.sh" "$root" &
```

with (note the leading comment lines and the `</dev/tty`):

```bash
  # stdin from /dev/tty: backgrounding (&) redirects stdin to /dev/null,
  # and tig refuses to run interactively without a terminal on stdin
  # (lazygit/fzf opened /dev/tty themselves; tig does not).
  ( cd "$root" && exec tig status </dev/tty ) &
```

(`exec` makes tig take over the subshell's PID, so the existing `viewer_pid=$!` and `kill "$viewer_pid"` on the next lines reap tig directly — no other changes to the loop. The `</dev/tty` is mandatory: without it, backgrounding sends tig's stdin to `/dev/null` and it exits 1 with "Ignoring stdin" — verified. Job control is off in the watcher, so tig shares the pane's foreground group and reads `/dev/tty` without SIGTTIN.)

- [ ] **Step 6: Update the watcher's header comment**

In `scripts/dev-tab-watch.sh`, replace the comment block (lines 2–7):

```bash
# dev-tab-watch.sh — right-hand pane of the dev tab (dev / Ctrl-a g).
# Follows the sibling (left) pane's directory: runs the read-only
# files+diff viewer (dev-tab-diff.sh) rooted at that repo, restarts it
# when the sibling moves to a different repo, and shows a placeholder
# when the sibling isn't inside a git repo. Exits when the sibling pane
# closes or when the viewer is quit with q.
```

with:

```bash
# dev-tab-watch.sh — right-hand pane of the dev tab (dev / Ctrl-a g).
# Follows the sibling (left) pane's directory: runs `tig status` rooted at
# that repo, restarts it when the sibling moves to a different repo, and
# shows a placeholder when the sibling isn't inside a git repo. Exits when
# the sibling pane closes or when tig is quit with q.
```

- [ ] **Step 7: Syntax-check the watcher**

Run: `bash -n ~/.dotfiles/scripts/dev-tab-watch.sh && echo OK`
Expected: `OK`

- [ ] **Step 8: Delete the fzf viewer**

Run: `cd ~/.dotfiles && git rm scripts/dev-tab-diff.sh`
Expected: `rm 'scripts/dev-tab-diff.sh'`.

Then confirm nothing still references it:
Run: `grep -rn 'dev-tab-diff' ~/.dotfiles/scripts ~/.dotfiles/tmux`
Expected: no output (references remain only in `docs/`, which is historical and fine).

- [ ] **Step 9: Update the cheatsheet row**

In `CHEATSHEET.md`, replace the `Ctrl-a g` row:

```markdown
| `Ctrl-a g` | Dev tab: shell + live read-only files/diff pane (lazygit via `lg`) |
```

with:

```markdown
| `Ctrl-a g` | Dev tab: shell + tig files/diff pane, live (lazygit via `lg`) |
```

- [ ] **Step 10: Functional check in a throwaway tmux session**

```bash
mkdir -p /private/tmp/sdd-nogit && git init -q /private/tmp/sdd-tigrepo
: > /private/tmp/sdd-tigrepo/change.txt
command tmux new-session -d -s sdd-tig -c /private/tmp/sdd-nogit
command tmux split-window -h -l 40% -t sdd-tig -c /private/tmp/sdd-nogit '~/.dotfiles/scripts/dev-tab-watch.sh'
sleep 2
echo "--- no-repo placeholder (expect PLACEHOLDER-OK):"
command tmux capture-pane -p -t sdd-tig:1.2 | grep -q 'no git repository' && echo PLACEHOLDER-OK
: > /private/tmp/sdd-tigrepo/change.txt
command tmux send-keys -t sdd-tig:1.1 'cd /private/tmp/sdd-tigrepo' Enter
sleep 3
echo "--- tig renders when sibling is in a repo (verify by CONTENT, not pane_current_command):"
command tmux capture-pane -p -t sdd-tig:1.2 | grep -qiE 'change.txt|staged|commit' && echo TIG-RENDERS-OK
echo "--- sibling close tears down the pane (expect GONE):"
command tmux kill-pane -t sdd-tig:1.1
sleep 3
command tmux has-session -t sdd-tig 2>/dev/null || echo GONE
command tmux kill-session -t sdd-tig 2>/dev/null
rm -rf /private/tmp/sdd-nogit /private/tmp/sdd-tigrepo
```
Expected: `PLACEHOLDER-OK`; `TIG-RENDERS-OK` (tig's status view shows the changed file when the sibling is in a repo); `GONE` after killing the left pane (the watcher exits with its sibling, leaving no panes, so the session ends). Record actual output.

Note: verify by tig's rendered CONTENT, not `#{pane_current_command}` — tig runs as the watcher's backgrounded child, so `pane_current_command` reports the shell (`bash`), not `tig`. That is expected and correct; the content check is the real signal. If the pane shows the placeholder or is empty when the sibling is in a repo, the viewer isn't launching — STOP and report BLOCKED.

- [ ] **Step 11: Commit**

```bash
cd ~/.dotfiles
git add Brewfile tig/.config/tig/config scripts/dev-tab-watch.sh CHEATSHEET.md
# dev-tab-diff.sh deletion is already staged by `git rm` in Step 8
git commit -m "dev-tab: use tig status as the files/diff viewer"
```
Expected: `git show --stat HEAD` lists exactly five paths — `Brewfile`, `tig/.config/tig/config` (new), `scripts/dev-tab-watch.sh`, `scripts/dev-tab-diff.sh` (deleted), `CHEATSHEET.md` — and none of the unrelated WIP files.

- [ ] **Step 12: Manual visual check (user-run, not automated)**

Note for the controller: leave this for the user. In a fresh shell inside tmux: run `dev` (and separately `Ctrl-a g`), and confirm:
- the right pane shows tig's status view with the file list and diff side by side;
- `j`/`k` move between files and the diff follows;
- `Ctrl-f`/`Ctrl-b` page the diff;
- editing a file updates the view live without losing position;
- `q` quits and the dev pane tears down;
- lazygit is no longer here (`lg` still opens it).
If the diff doesn't follow the selection to taste, that's the known tigrc tuning knob called out in the spec — report back and we'll adjust `tig/.config/tig/config`.
