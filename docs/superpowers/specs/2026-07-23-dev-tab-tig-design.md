# Dev Tab: tig status Viewer — Design

**Date:** 2026-07-23
**Status:** Approved

## Goal

Replace the custom fzf `dev-tab-diff.sh` viewer with `tig status` as the
dev tab's right pane. tig natively gives the keyboard-driven files+diff
experience (j/k between files, Ctrl-f/Ctrl-b scroll the diff) and
live-refreshes without losing cursor/scroll position — the problem the
fzf viewer couldn't solve (its 2s reload snapped the diff back to the
top). Applies to both entry points (`dev` and `Ctrl-a g`) via the
watcher.

## Context

- The dev tab's right pane runs `scripts/dev-tab-watch.sh`, which follows
  the left (sibling) pane's directory: polls once a second, resolves it
  to a git toplevel, runs a viewer rooted there, relaunches on repo
  change, shows a "no git repository" placeholder when the sibling isn't
  in a repo, and exits when the sibling closes.
- The current viewer is `scripts/dev-tab-diff.sh` — a custom fzf UI whose
  per-file preview + 2s send-keys refresh ticker required a `trap`/PID
  cleanup dance and still fought the user's scrolling. This whole script
  is being removed.
- `tig` is not yet installed (`brew install tig`).
- tig is a single foreground process (like lazygit), so the watcher's
  existing single-PID `kill "$viewer_pid"` tears it down cleanly — no
  ticker, no `trap`, no orphan risk.

## Components

### 1. Brewfile

Add `brew "tig"` to the Git section. Install with `brew install tig`.

### 2. tig config — `tig/.config/tig/config` (new stow package)

- `set refresh-mode = auto` — the status view live-updates as the working
  tree changes, preserving the current selection and scroll position.
- `set vertical-split = yes` — the file list and the diff sit side by side
  (matching the approved mockup), rather than stacked.

Stowed like the other packages: `~/.config/tig/config` becomes a symlink
into the repo. Applies to all tig usage, which is fine — these are sane
global defaults.

### 3. `scripts/dev-tab-watch.sh` — swap the viewer

Replace the viewer launch line:

```bash
  "$HOME/.dotfiles/scripts/dev-tab-diff.sh" "$root" &
```

with:

```bash
  ( cd "$root" && exec tig status </dev/tty ) &
```

`exec` makes tig take over the subshell's PID, so `viewer_pid=$!` is
tig's PID and the existing `kill "$viewer_pid"` on repo-change /
sibling-close reaps it directly. The `</dev/tty` is required: a
backgrounded job (`&`) has its stdin redirected to `/dev/null`, and tig
refuses to run interactively without a terminal on stdin (it prints
"Ignoring stdin" and exits 1). lazygit and fzf opened `/dev/tty`
themselves, so they didn't need this; tig does. Job control is off in the
non-interactive watcher, so tig shares the pane's foreground process
group and reads `/dev/tty` without SIGTTIN. The header comment is updated to say
"tig status" instead of the files+diff viewer. The follow-loop,
placeholder, and sibling-exit logic are otherwise unchanged.

### 4. Delete `scripts/dev-tab-diff.sh`

Remove the custom fzf viewer — nothing references it after the watcher
swap (`grep -rn dev-tab-diff` should return only historical docs/plans).

### 5. `CHEATSHEET.md`

Update the `Ctrl-a g` row to describe the dev tab as "shell + tig
files/diff pane (live, read-only browsing)".

## Data flow

```
dev / Ctrl-a g → dev-tab-open.sh → split, right pane = dev-tab-watch.sh
                                        │ follows sibling pane's repo root
                                        ▼
                          ( cd "$root" && exec tig status )
                            └─ tig: status list (j/k) + diff (Ctrl-f/b),
                               auto-refresh, native rendering
```

## Keybindings (all tig-native, nothing to configure)

- `j` / `k` — move between changed files in the status view.
- `Enter` — focus/open the selected file's diff.
- `Ctrl-f` / `Ctrl-b` — page the diff forward / back.
- `q` — quit (tears down the pane; the watcher exits with the sibling).
- `u` — stage/unstage (tig default; optional, never fires unless pressed).

## Error handling

- **No repo:** handled upstream by the watcher's placeholder; tig is only
  launched with a valid root.
- **Clean tree:** tig's status view shows "nothing to commit" natively.
- **Repo change / sibling close:** the watcher kills the single tig PID
  and relaunches or exits — same mechanism it used for lazygit.

## Testing

- `brew install tig` succeeds; `tig --version` prints a version.
- `bash -n scripts/dev-tab-watch.sh` passes after the swap.
- `~/.config/tig/config` resolves to the stowed file (symlink) and tig
  starts without config errors (`tig status` in a repo, then `q`).
- Watcher swap in a throwaway tmux session: the right pane's process is
  `tig` (not `dev-tab-diff.sh`/`fzf`) when the sibling is in a repo, the
  placeholder still appears when it is not, and closing the sibling exits
  the pane.
- `grep -rn dev-tab-diff scripts/ tmux/` returns nothing (file removed,
  no dangling reference).
- Manual visual check (user): run `dev` / `Ctrl-a g`, confirm the
  side-by-side list+diff, that `j`/`k` move files and the diff follows,
  `Ctrl-f`/`Ctrl-b` scroll the diff, edits refresh live without losing
  position, and `q` quits. If the diff doesn't follow selection to taste,
  tune the tigrc (a known follow-up knob).

## Out of scope (YAGNI)

- No delta integration inside tig (tig renders its own diff views; delta
  isn't an external pager it uses).
- No custom keybindings — tig defaults already match the desired keys.
- No lock-down of tig's staging keys — it's read-only in practice unless
  the user opts in.
