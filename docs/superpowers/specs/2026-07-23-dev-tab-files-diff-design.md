# Dev Tab Files + Diff View — Design

**Date:** 2026-07-23
**Status:** Approved

## Goal

Replace lazygit in the `dev` tab with a lightweight, read-only "what
changed" view: a changed-files list plus a delta-rendered diff of the
selected file, with lazygit-style modal keyboard navigation. Applies to
**both** entry points — the `dev` alias and the `Ctrl-a g` binding.
Full lazygit remains available separately via the existing `lg` alias.

## Context

- The dev tab is built by `scripts/dev-tab-open.sh` (new window for
  `Ctrl-a g`, in-place split for `dev --here`), whose right pane runs
  `scripts/dev-tab-watch.sh`.
- `dev-tab-watch.sh` follows the left (sibling) pane's directory: it
  polls once a second, resolves the directory to a git toplevel, runs a
  viewer rooted there, relaunches on repo change, shows a "no git
  repository" placeholder when the sibling isn't in a repo, and exits
  when the sibling pane closes. Today the viewer is hardcoded to
  `lazygit --path "$root"`.
- delta is installed; its flags mirror the lazygit pager config
  (`delta --dark --paging=never --line-numbers`).
- fzf is 0.74.1 (`--style=full`, `--listen`, preview-scroll actions).
- `curl` is available and supports `--unix-socket`.

## Components

### 1. `scripts/dev-tab-diff.sh <repo-root>` — new

A read-only fzf viewer for one repo root. Styled like the pmon dashboard
(`--style=full`).

**File list** (`FZF_DEFAULT_COMMAND`): `git -C <root> status
--porcelain=v1`, one line per change as `status ⇥ path`, shown as
`status path` (e.g. ` M src/foo.ts`, `?? new.ts`). When there are no
changes, emit a single non-actionable line `✓ working tree clean`.

**Preview** (delta-rendered), keyed on the selected path:
- Tracked & modified → `git -C <root> diff HEAD -- <path>`.
- Untracked (`??`) → `git -C <root> diff --no-index /dev/null <path>`.
- Piped through `delta --dark --paging=never --line-numbers`.
- The `✓ working tree clean` sentinel line → empty preview.
- Preview label = the selected file's path.

**Live refresh:** a background ticker `while sleep 2; do tmux send-keys
-t "$TMUX_PANE" C-r; done` nudges this pane every 2s, triggering the same
`ctrl-r` reload bind as a manual refresh. (This replaces an earlier
`--listen`+`curl` design: sending `reload(...)` over fzf's socket needs
the less-safe `--listen-unsafe` mode, whereas `send-keys` is already
in-tmux, dependency-free, and achieves identical behavior.) The ticker
starts before fzf and is killed when fzf exits. If `send-keys` ever fails
(pane gone), the ticker exits; fzf still works via manual `ctrl-r`.

**Keymap (lazygit-style modal):**
- `j` / `k` → `down` / `up` (move selection in the files list).
- Arrow keys → also move the list (fzf default, kept).
- `ctrl-f` / `ctrl-b` → `preview-page-down` / `preview-page-up`.
- `ctrl-d` / `ctrl-u` → `preview-half-page-down` / `preview-half-page-up`.
- `ctrl-r` → `reload(<list-cmd>)+refresh-preview` (manual refresh).
- `q` and `enter` → `abort` (quit).
- **Read-only:** no staging, commit, branch, or discard bindings.

**Footer:** ` j/k file · ^f/^b scroll · ^d/^u half · ^r refresh · q quit `.

### 2. `scripts/dev-tab-watch.sh` — one-line viewer swap

Change the viewer line from `lazygit --path "$root"` to
`"$HOME/.dotfiles/scripts/dev-tab-diff.sh" "$root"`. The follow-loop
(poll, resolve root, relaunch on move, placeholder when no repo, exit on
sibling close) is otherwise unchanged. Because both entry points route
through this watcher, both get the files+diff view.

### 3. `scripts/dev-tab-open.sh` — unchanged

Still builds the layout (new window or in-place split) and launches the
watcher. No viewer flag needed — the watcher now always uses the diff
viewer.

### 4. `zsh/.zsh_aliases` — unchanged behavior

The `dev` alias (`dev-tab-open.sh --here`) and the `Ctrl-a g` binding are
unchanged; they inherit the new viewer through the watcher. No edit is
required here unless the plan finds one; the `mp` WIP stays uncommitted
regardless.

### 5. `tmux/.config/tmux/tmux.conf` — resurrect list

`@resurrect-processes` keeps `lazygit` (still launched manually via `lg`)
and `~dev-tab-watch.sh`. No change required; noted for completeness.

### 6. `CHEATSHEET.md`

Update the `Ctrl-a g` row to describe the dev tab as "shell + live
read-only files/diff pane (lazygit via `lg`)".

## Data flow

```
dev / Ctrl-a g → dev-tab-open.sh → split, right pane = dev-tab-watch.sh
                                        │ follows sibling pane's repo root
                                        ▼
                          dev-tab-diff.sh <root>
                            ├─ list:    git status --porcelain=v1
                            ├─ preview: git diff [HEAD|--no-index] -- <file> | delta
                            └─ ticker:  curl --unix-socket → reload+refresh (~2s)
```

## Error handling

- **No repo:** handled upstream by the watcher's placeholder; the diff
  script is only launched with a valid root.
- **Clean tree:** the `✓ working tree clean` sentinel line; empty preview.
- **Refresh failure (socket/curl):** non-fatal; `ctrl-r` still refreshes,
  and selection changes always re-render the preview from current state.
- **Repo change / sibling close:** the watcher kills and relaunches (or
  exits), exactly as it does for lazygit today.

## Testing

- `bash -n` on `dev-tab-diff.sh` and `dev-tab-watch.sh`.
- In a dirty repo: `dev-tab-diff.sh` list generator prints the changed
  files with status markers; in a clean repo it prints `✓ working tree
  clean`.
- Preview renders delta output for a tracked modified file
  (`git diff HEAD -- <file> | delta …`) and for an untracked file
  (`--no-index`).
- Watcher swap: in a throwaway tmux session, the right pane's process is
  `dev-tab-diff.sh`/`fzf` (not `lazygit`) when the sibling is in a repo,
  and the placeholder still appears when it is not.
- Manual visual check (user): run `dev`, confirm the panels/footer, that
  `j`/`k` switch files, `ctrl-f`/`ctrl-b` page the diff, `ctrl-d`/`ctrl-u`
  half-page, the list auto-updates ~2s after an edit, and `q` quits.

## Out of scope (YAGNI)

- No staging / commit / branch / discard — that is what `lg` (lazygit) is
  for.
- No viewer-selection flag — lazygit is fully removed from the dev tab.
- No configurable refresh interval — fixed at ~2s.
