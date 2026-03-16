# Dotfiles

Personal dotfiles for macOS, managed with [GNU Stow](https://www.gnu.org/software/stow/). Unified Tokyo Night theme across all tools.

## What's Included

| Tool | Description |
|------|-------------|
| [Neovim](https://neovim.io/) | Editor — LazyVim distribution with TypeScript/React focus |
| [Zsh](https://www.zsh.org/) | Shell — Oh My Zsh + Powerlevel10k |
| [Tmux](https://github.com/tmux/tmux) | Terminal multiplexer — `Ctrl-a` prefix, vim-style navigation |
| [Starship](https://starship.rs/) | Cross-shell prompt with language/tool detection |
| [Ghostty](https://ghostty.org/) | Terminal emulator — keybinds wired to tmux windows |
| [Lazygit](https://github.com/jesseduffield/lazygit) | Terminal UI for git |

## Requirements

**macOS** with [Homebrew](https://brew.sh/) installed.

### Install dependencies

```bash
brew bundle
```

This installs everything listed in the [`Brewfile`](./Brewfile) — CLI tools, casks, and dev dependencies.

### Additional requirements

- **Node.js** — install via [nvm](https://github.com/nvm-sh/nvm) (configured in `.zsh_exports`)
- **Oh My Zsh** — https://ohmyz.sh/#install
- **Zsh plugins** — install into Oh My Zsh custom plugins directory:
  ```bash
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  ```
- **Tmux Plugin Manager (tpm)**:
  ```bash
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  ```
- **Nerd Font** — required for icons (e.g., [JetBrainsMono Nerd Font](https://www.nerdfonts.com/))

## Installation

Clone the repo to your home directory:

```bash
git clone https://github.com/<your-username>/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

Use GNU Stow to symlink configs. Each directory is a stow package — the folder structure inside mirrors `$HOME`:

```bash
# Symlink everything
stow nvim starship lazygit tmux zsh ghostty

# Or symlink individually
stow nvim
stow tmux
```

This creates symlinks like:

- `nvim/.config/nvim/` → `~/.config/nvim/`
- `tmux/.config/tmux/` → `~/.config/tmux/`
- `ghostty/.config/ghostty/` → `~/.config/ghostty/`
- `starship/starship.toml` → `~/starship.toml`
- `zsh/.zshrc` → `~/.zshrc`

### Post-install

1. **Tmux** — open tmux and press `Ctrl-a + I` to install plugins via tpm.
2. **Neovim** — open nvim, Lazy.nvim will auto-install plugins on first launch. Run `:Mason` to install LSP servers/formatters.
3. **Zsh** — restart your shell or run `source ~/.zshrc`.

## Key Highlights

### Neovim

- **Plugin manager:** Lazy.nvim with LazyVim distribution
- **Languages:** TypeScript, JavaScript, React/TSX, JSON, Docker, YAML, Bash, Tailwind CSS
- **Formatting:** Prettier (TS/JS), ESLint integration
- **LSP:** Managed via Mason (auto-install)
- **Navigation:** vim-tmux-navigator for seamless pane switching with `Ctrl-h/j/k/l`
- **Theme:** Tokyo Night (transparent background)
- **Git:** gitsigns, diffview, octo.nvim (GitHub PRs/issues)
- **Project picker:** custom picker for `~/Documents/repo`

### Tmux

- **Prefix:** `Ctrl-a`
- **Splits:** `d` (horizontal), `D` (vertical)
- **Pane navigation:** `Ctrl-h/j/k/l` (shared with Neovim)
- **Theme:** Tokyo Night

### Ghostty

- `Cmd+1-9` remapped to switch tmux windows (sends `Ctrl-a + <number>`)
- Background opacity: 0.95

### Zsh

- **Prompt:** Powerlevel10k (lean style)
- **Plugins:** git, tmux (auto-attaches to "main" session), zsh-autosuggestions, alias-finder
- **CLI replacements:** `ls` → `eza`, `lg` → `lazygit`, `v` → `nvim`
- **Dev shortcuts:** `mono`, `employeeweb`, `famweb`, `cgweb` for monorepo services
- **Cloud/DevOps:** kubectl (`k`), AWS EKS config (`awks`)

### Starship

- Left: git metrics, command duration, prompt character
- Right: language versions, kubernetes context, docker, cloud providers, git status

## Uninstall

```bash
cd ~/.dotfiles
stow -D nvim starship lazygit tmux zsh ghostty
```
