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

# fzf-tab — replace Tab with an fzf picker showing flags + descriptions.
# Cloned into the oh-my-zsh custom tree by scripts/install.sh, alongside
# zsh-autosuggestions; sourced (not listed in plugins=) so it loads after
# compinit. Guarded so a clone that predates the installer still starts.
_fzf_tab="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fzf-tab/fzf-tab.plugin.zsh"
[ -r "$_fzf_tab" ] && source "$_fzf_tab"
unset _fzf_tab

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
#
# Also wrap ssh so a dropped connection leaves the local terminal usable and
# reconnects once automatically. A remote tmux/herdr/editor arms terminal
# modes (mouse tracking, focus reporting, alternate screen) that only it can
# disarm; if the connection dies, those modes stay armed locally and every
# mouse move floods the prompt with escape junk.
#
# The wrapper dispatches to kitten ssh inside kitty, plain command ssh
# elsewhere, so the alias and the function stay in sync without aliases
# calling each other.
_ssh_run() {
    if [[ -n "${KITTY_WINDOW_ID:-}" ]]; then
        kitten ssh "$@"
    else
        command ssh "$@"
    fi
}

_ssh_disarm() {
    printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l\e[?1004l\e[?1049l\e[?25h'
}

# True for an interactive session: a destination and no remote command. The
# letters are the ssh(1) options that consume a value, so their arguments
# are not mistaken for the destination.
_ssh_interactive() {
    local value_opts="BbcDEeFIiJLlmOoPpQRSWw"
    local arg letters i dest="" opts_done=""
    local -a argv=("$@")

    while (($#)); do
        arg="$1"
        shift

        if [[ -z $opts_done && $arg == "--" ]]; then
            opts_done=1
        elif [[ -z $opts_done && $arg == -?* ]]; then
            letters="${arg#-}"
            for ((i = 1; i <= ${#letters}; i++)); do
                ch="${letters[$i]}"
                if [[ $value_opts == *"$ch"* ]]; then
                    # The value is glued to the letter (-p2222) unless the
                    # letter ends the argument, in which case it consumes
                    # the next one (-p 2222).
                    (( i == ${#letters} )) && shift
                    break
                fi
            done
        elif [[ -z $dest ]]; then
            dest="$arg"
        else
            return 1
        fi
    done

    [[ -n $dest ]] || return 1

    # A RemoteCommand from ssh_config or -o replays on reconnect just like
    # a positional command; ssh -G resolves the effective configuration for
    # this exact invocation without connecting. Fail closed when it cannot
    # resolve, since an undetected RemoteCommand must not replay. The
    # explicit "none" cancels a configured command, and some versions emit
    # it when unset.
    local resolved
    resolved=$(command ssh -G "${argv[@]}" 2>/dev/null) || return 1
    ! print -r -- "$resolved" | grep -i '^remotecommand ' | grep -qvi '^remotecommand none$'
}

ssh() {
    local rc started
    started=$SECONDS

    _ssh_run "$@"
    rc=$?

    [[ -t 1 ]] || return $rc
    _ssh_disarm

    # Reconnect only when an interactive session drops: ssh exits 255 for
    # transport failures, but a fast 255 with no established session is a
    # connect/auth failure, a remote command's own 255 passes through
    # indistinguishably and must not replay its side effects, and redirected
    # stdin would feed the remaining piped input to a fresh remote shell.
    if (( rc != 255 )) || [[ ! -t 0 ]] || ! _ssh_interactive "$@" ||
        (( SECONDS - started < 30 )); then
        return $rc
    fi

    # Retry in a subshell: Ctrl-C reaches the whole foreground process group,
    # so it cancels both the in-flight attempt and the loop itself. Keep
    # retrying fast failures, since a rebooting server refuses connections too.
    (
        while true; do
            echo "Connection lost. Reconnecting (Ctrl-C to stop)..."
            sleep 2
            _ssh_run "$@"
            rc=$?
            _ssh_disarm
            (( rc != 255 )) && exit $rc
        done
    )
}

unset -f _ssh_drop_kitten_alias 2>/dev/null

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
#    ts-up starts tailscaled in case it isn't running yet. Extra args
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

# opencode — packaged on Arch (pacman) and macOS (brew), so this only
# matters where upstream's installer put it in ~/.opencode/bin (Debian).
[ -d "$HOME/.opencode/bin" ] && export PATH="$HOME/.opencode/bin:$PATH"

# LLM_SERVER_URL + LLM_MODEL for opencode, written per-machine by
# scripts/setup-llm.sh. Under ~/.local/state, not ~/.config: on Arch the repo
# is ~/.config itself.
[ -f "$HOME/.local/state/dotfiles/llm.env" ] && . "$HOME/.local/state/dotfiles/llm.env"
# opencode.json resolves {env:LLM_SERVER_URL} for the ollama baseURL (its models
# are fixed in the file); claude-local reads LLM_MODEL. An unset URL would leave
# an empty baseURL, which only fails at request time.
# Default to the local ollama so a machine with no llm.env just works; running
# setup-llm.sh is only needed to point at a different host.
export LLM_SERVER_URL="${LLM_SERVER_URL:-http://localhost:11434/v1}"
export LLM_MODEL="${LLM_MODEL:-qwen3-coder:30b}"

# ---------------------------------------------------------------------------
# fzf -- Ctrl-T inserts files, Ctrl-R searches history, Alt-C cd's.
# Arch ships /usr/share/fzf/{key-bindings,completion}.zsh; source them once.
# Skip on TTY-only shells where loading is wasted and key bindings clash with
# nothing useful.
# ---------------------------------------------------------------------------
if [ -r /usr/share/fzf/key-bindings.zsh ] && [ -r /usr/share/fzf/completion.zsh ]; then
    source /usr/share/fzf/key-bindings.zsh
    source /usr/share/fzf/completion.zsh

    # Ctrl-G: fuzzy-pick a commit and insert "hash  subject" at the cursor.
    # Useful for `git show <hash>` or `git checkout <hash>` without leaving
    # the command line.
    fzf-git-hash-widget() {
        local selection
        selection=$(
            git log --pretty=format:'%h %s' -n 200 -- . 2>/dev/null |
            fzf --no-sort --height 40% --reverse --tiebreak=index --no-multi
        ) || return 0
        LBUFFER+="${selection%% *}"
        zle reset-prompt
    }
    zle -N fzf-git-hash-widget
    bindkey '^G' fzf-git-hash-widget
fi
