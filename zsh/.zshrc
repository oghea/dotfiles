# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
#ZSH_THEME="powerlevel10k/powerlevel10k"
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
# tmux autostart: first window attaches to "main"; additional windows get
# their own fully separate session (private windows, nothing shared with
# main). Extra sessions destroy themselves when their terminal closes —
# use `tmux new -s name` instead for work that should survive the window.
# Only autostart in a real interactive terminal. Tools that source this rc to
# probe the environment (VS Code, Claude Code) pipe stdout, so `-t 1` is false
# there and the `exec tmux` is skipped — otherwise it replaces the probe shell
# and makes it exit non-zero ("Unable to resolve your shell environment").
if [[ -z "$TMUX" ]] && [[ -o interactive ]] && [[ -t 1 ]]; then
  if tmux ls -F '#{session_name} #{session_attached}' 2>/dev/null | grep -q '^main [1-9]'; then
    n=2
    while tmux has-session -t "=scratch-$n" 2>/dev/null; do (( n++ )); done
    exec tmux new-session -s "scratch-$n" \; set-option destroy-unattached on
  else
    exec tmux new-session -A -s main
  fi
fi

plugins=(git tmux zsh-autosuggestions aliases alias-finder)

source $ZSH/oh-my-zsh.sh

# Source custom configs
source ~/.zsh_aliases
source ~/.zsh_exports

# starship prompt
eval "$(starship init zsh)"

# zoxide — smarter cd (z <dir>, zi for interactive picker)
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# fzf keybindings (Ctrl-R history, Ctrl-T files) and completion
command -v fzf >/dev/null && source <(fzf --zsh)

# pyenv (only on machines that have it)
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
command -v pyenv >/dev/null && eval "$(pyenv init -)"

export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

# marta prod (account 458209770945) enforces MFA. Run `marta-login <6-digit-code>`
# once per ~12h to mint a session into the `prayoga-mfa` profile and (re)build the
# `marta-prod` kube context. Then switch clusters with: kubectx marta-prod
marta-login() {
  local code="$1"
  if [[ -z "$code" ]]; then echo "usage: marta-login <mfa-code>"; return 1; fi
  local creds ak sk st
  creds=$(aws sts get-session-token \
    --profile marta \
    --serial-number arn:aws:iam::458209770945:mfa/iphone \
    --token-code "$code" \
    --duration-seconds 43200 \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text) || return 1
  read -r ak sk st <<< "$creds"
  aws configure set aws_access_key_id     "$ak" --profile prayoga-mfa
  aws configure set aws_secret_access_key "$sk" --profile prayoga-mfa
  aws configure set aws_session_token     "$st" --profile prayoga-mfa
  aws configure set region eu-central-1          --profile prayoga-mfa
  aws eks update-kubeconfig --profile prayoga-mfa --region eu-central-1 \
    --name k8s-cluster --alias marta-prod >/dev/null \
    && echo "✅ marta-prod session valid ~12h — switch with: kubectx marta-prod"
}
