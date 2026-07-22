# Keyboard Cheatsheet

Consolidated shortcuts across AeroSpace, Ghostty, tmux, and Neovim.
Open this popup from anywhere in tmux with **`Ctrl-a /`**.

> Generated from the configs in this repo. When you change a binding, update
> this file too (or ask Claude to regenerate it).

**Mac modifier keys:** `Cmd` ⌘ · `Ctrl` ⌃ · `Opt`/`Alt` ⌥ · `Shift` ⇧
`Opt` and `Alt` are the same physical key — Ghostty's `macos-option-as-alt`
is what makes the `Alt`/`Opt` bindings below work.

**Live lookups (always current, per tool):**
| Tool | Show its bindings |
|------|-------------------|
| tmux | `Ctrl-a ?` (raw list) · `Ctrl-a /` (this sheet) |
| Neovim | press `Space` and wait (which-key) · `Space s k` (search all keymaps) |
| Ghostty | `ghostty +list-keybinds` in a shell |
| AeroSpace | no live popup — this sheet / `aerospace.toml` |

---

## AeroSpace — window manager

Layout, focus, and workspaces. Most bindings use the **`Cmd+Ctrl`** combo.

| Keys | Action |
|------|--------|
| `Cmd+Ctrl+H/J/K/L` | Focus window left / down / up / right |
| `Cmd+Ctrl+Shift+H/J/K/L` | Move window left / down / up / right |
| `Alt+Tab` / `Alt+Shift+Tab` | Cycle windows within the current workspace |
| `Cmd+Ctrl+1`…`5` | Switch to workspace 1–5 |
| `Cmd+Ctrl+Shift+1`…`5` | Move focused window to workspace 1–5 |
| `Cmd+Alt+1`…`9` | Jump to the Nth window in the SketchyBar app bar |
| `Cmd+Ctrl+Tab` | Toggle previous / current workspace |
| `Cmd+Ctrl+Shift+Tab` | Move workspace to next monitor |
| `Cmd+Ctrl+F` | Toggle fullscreen |
| `Cmd+Ctrl+Space` | Toggle floating / tiling for focused window |
| `Cmd+Ctrl+A` | Toggle tiles ↔ accordion (stacked) layout |
| `Cmd+Ctrl+/` | Toggle split direction (horizontal ↔ vertical) |
| `Cmd+Ctrl+-` / `Cmd+Ctrl+=` | Resize focused window smaller / larger |
| `Cmd+Ctrl+R` | Reset (flatten) the workspace layout tree |

_You can also click any icon in the SketchyBar app bar to focus that window._

---

## Ghostty — terminal

Kept minimal on purpose — window/pane management lives in tmux.

| Keys | Action |
|------|--------|
| `Cmd+1`…`9` | Switch to tmux window 1–9 (sends `Ctrl-a` + number) |
| `Cmd+K` | Clear screen (Ghostty built-in) |
| `Cmd+Enter` | Toggle native fullscreen |

_Full list (mostly defaults): `ghostty +list-keybinds`._

---

## tmux — multiplexer

Prefix is **`Ctrl-a`** (shown as `⌃a`). "Prefix + X" = press `Ctrl-a`, release, then X.

| Keys | Action |
|------|--------|
| `Ctrl-a d` | Split pane horizontally (side by side) |
| `Ctrl-a D` | Split pane vertically (stacked) |
| `Alt+1`…`9` | Select pane by number |
| `Ctrl-a h/j/k/l` | Resize pane left/down/up/right (repeatable) |
| `Ctrl-l` | Clear screen + scrollback (no prefix) |
| `Ctrl-a c` | New window |
| `Ctrl-a g` | Dev tab: shell + lazygit diff pane |
| `Ctrl-a n` / `Ctrl-a p` | Next / previous window |
| `Cmd+1`…`9` | Jump to window N (via Ghostty) |
| `Ctrl-a T` | sesh session picker |
| `Ctrl-a [` | Enter copy mode (then `v` select, `y` copy) |
| `Ctrl-a r` | Reload tmux config |
| `Ctrl-a /` | Open this cheatsheet |
| `Ctrl-a ?` | Raw list of all tmux keys |

---

## Neovim — editor (LazyVim)

Leader is **`Space`**. Press `Space` and pause to let which-key show you the rest.
This lists custom/notable maps only — `Space s k` searches every keymap.

| Keys | Action |
|------|--------|
| `Space` (wait) | which-key: show available follow-up keys |
| `Space s k` | Search all keymaps |
| `Ctrl+H/J/K/L` | Navigate splits (and out to tmux panes) |
| `Ctrl+/` | Toggle floating terminal |
| `Space e` | Toggle file explorer |
| `Space f d` | Find directory, open explorer there |
| `Space f p` / `Space f P` | Recent projects / all projects |
| `Space b d` / `Space b D` | Delete buffer / close all & dashboard |
| `Space g d` / `Space g D` | Diffview open / close |
| `Space g f` / `Space g F` | File history (current file / whole repo) |
| `Space g m` | GitHub dashboard (octo) |

_LazyVim ships hundreds more — reach them through which-key and `Space s k`._
