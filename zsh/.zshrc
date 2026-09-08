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
ZSH_THEME="powerlevel10k/powerlevel10k"

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
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# Override OMZ's matcher-list to drop anchor patterns (r:|=*, l:|=* r:|=*);
# Claude Code's completion can't parse anchor-based matching.
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="$EDITOR ${ZDOTDIR:-$HOME}/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# To customize prompt, run `p10k configure` or edit $ZDOTDIR/.p10k.zsh.
[[ ! -f ${ZDOTDIR:-$HOME}/.p10k.zsh ]] || source ${ZDOTDIR:-$HOME}/.p10k.zsh
# Route ssh through the kitty kitten only when we're actually inside a kitty
# window. Outside kitty (TTY, other terminals, scripts) the kitten errors out
# with "The SSH kitten is meant to run inside a kitty window".
if [[ -n "${KITTY_WINDOW_ID:-}" ]]; then
    alias ssh='kitten ssh'
fi

alias ls='eza --icons'
alias lc='eza -la --icons --group-directories-first'

# --- VPN ---------------------------------------------------------------------
# Two independent VPNs, neither enabled at boot; bring up whichever you need.
#
# 1. WireGuard -> home wg-easy server. Full-tunnel (0.0.0.0/0) and it pushes its
#    own DNS into systemd-resolved, so it's disruptive to leave running.
#    Configs are git-ignored in ~/.config/wireguard/; awg-quick takes the
#    interface name from the filename, so keep those names <=15 chars.
#      alex - original client (10.8.0.2), has the AmneziaWG obfuscation params
#      isis - reissued 2026-08-20 (10.8.0.16), plain WireGuard, no obfuscation
#    Pass a name to pick one (`vpn-up isis`), or set VPN_DEFAULT.
VPN_DEFAULT=alex
vpn-up()   { sudo awg-quick up   ~/.config/wireguard/"${1:-$VPN_DEFAULT}".conf }
vpn-down() { sudo awg-quick down ~/.config/wireguard/"${1:-$VPN_DEFAULT}".conf }
alias vpn-status='sudo awg show'
alias vpn-list='print -l ~/.config/wireguard/*.conf(N:t:r)'

# 2. Tailscale. --accept-dns=false keeps tailscaled out of systemd-resolved so
#    it can't fight the DNS the AmneziaWG tunnel pushes; the tradeoff is that
#    MagicDNS short names don't resolve (use tailnet IPs or full names).
#    ts-up starts tailscaled first since it isn't enabled at boot. Extra args
#    pass through, e.g. `ts-up --exit-node=<host>`.
ts-up() {
  sudo systemctl start tailscaled && sudo tailscale up --accept-dns=false "$@"
}
ts-down() {
  sudo tailscale down && sudo systemctl stop tailscaled
}
alias ts-status='tailscale status'

# Default cliamp to the Plex provider on launch
alias cliamp='cliamp --provider plex'

unset zle_bracketed_paste

# Only fetch autosuggestions after 2+ characters to avoid freeze on single keys
_zsh_autosuggest_fetch_min() {
  if (( ${#BUFFER} < 2 )); then
    _zsh_autosuggest_clear
    return
  fi
  _zsh_autosuggest_fetch_orig "$@"
}
if (( ${+functions[_zsh_autosuggest_fetch]} )); then
  functions[_zsh_autosuggest_fetch_orig]="${functions[_zsh_autosuggest_fetch]}"
  functions[_zsh_autosuggest_fetch]="${functions[_zsh_autosuggest_fetch_min]}"
fi

[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
