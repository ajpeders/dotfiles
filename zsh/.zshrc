# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Editor for OpenCode's external editor prompt (Ctrl+X E)
export EDITOR=nvim

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

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

# zoxide — smarter cd: `z <fuzzy>` jumps to a frecent directory, `zi` picks
# via fzf. Guarded so a machine without zoxide still starts.
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

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
        # Keep Kitty's keyboard protocol in legacy mode for password prompts,
        # without replacing the ssh() reconnect/disarm wrapper below.
        _kitty_legacy_keys_run kitten ssh "$@"
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
    local arg letters ch i dest="" opts_done=""
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

alias ls='eza --icons'
alias lc='eza -la --icons --group-directories-first'

# --- VPN ---------------------------------------------------------------------
# Two independent VPNs, neither enabled at boot; bring up whichever you need.
#
# 1. WireGuard (AmneziaWG client, which also runs plain WireGuard configs).
#    Full-tunnel and it pushes its own DNS into systemd-resolved, so it's
#    disruptive to leave running. Configs are git-ignored in
#    ~/.config/wireguard/; awg-quick takes the interface name from the
#    filename, so keep those names <=15 chars. Pass a name to pick one
#    (`vpn-up work`), set VPN_DEFAULT, or with a single .conf just `vpn-up`.
_vpn_conf() {
  local name="${1:-${VPN_DEFAULT:-}}"
  if [[ -z "$name" ]]; then
    local confs=(~/.config/wireguard/*.conf(N))
    (( $#confs == 1 )) || { echo "vpn: pass a name or set VPN_DEFAULT (see vpn-list)" >&2; return 1 }
    name="${confs[1]:t:r}"
  fi
  print -r -- ~/.config/wireguard/"$name".conf
}
vpn-up()   { local c; c=$(_vpn_conf "${1:-}") || return; sudo awg-quick up   "$c" }
vpn-down() { local c; c=$(_vpn_conf "${1:-}") || return; sudo awg-quick down "$c" }
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

# ~/.local/bin holds the installers' launchers (opencode-*).
# uv's env script adds it where uv is installed; make sure of it everywhere.
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
[[ ":$PATH:" == *":$HOME/.local/bin:"* ]] || export PATH="$HOME/.local/bin:$PATH"

# opencode — packaged on Arch (pacman) and macOS (brew), so this only
# matters where upstream's installer put it in ~/.opencode/bin (Debian).
# Only as a fallback: a stale upstream copy must not shadow the package.
if ! command -v opencode >/dev/null && [ -d "$HOME/.opencode/bin" ]; then
    export PATH="$HOME/.opencode/bin:$PATH"
fi

# LLM_SERVER_URL for opencode, written per-machine by scripts/setup-llm.sh.
# Under ~/.local/state, not ~/.config: on Arch the repo is ~/.config itself.
[ -f "$HOME/.local/state/dotfiles/llm.env" ] && . "$HOME/.local/state/dotfiles/llm.env"
# opencode.json resolves {env:LLM_SERVER_URL} for the ollama baseURL (its models
# are fixed in the file). An unset URL would leave an empty baseURL, which only
# fails at request time.
# Default to the local ollama so a machine with no llm.env just works; running
# setup-llm.sh is only needed to point at a different host.
export LLM_SERVER_URL="${LLM_SERVER_URL:-http://localhost:11434/v1}"

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

# ---------- Kitty shell integration ----------
# Kitty's automatic method hands the integration over via ZDOTDIR, which
# ~/.zshenv overwrites unconditionally, so it never loads. Load it explicitly.
# Without it nothing resets kitty's keyboard protocol at each prompt: any TUI
# that exits without popping the protocol leaves Enter arriving as \e[13u, which
# zsh and sudo silently ignore -- looks exactly like a dead Enter key, and makes
# sudo fail with "conversation failed" rather than a wrong password.
if [[ -n "${KITTY_INSTALLATION_DIR:-}" ]]; then
    export KITTY_SHELL_INTEGRATION="no-cursor"
    autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
    kitty-integration
    unfunction kitty-integration
fi

# ---------- Password prompts under kitty's keyboard protocol ----------
# Programs that read a password straight from the tty (sudo, ssh, su, passwd)
# do a plain canonical read and wait for a newline. When kitty's enhanced
# keyboard protocol is active -- which any TUI can enable, Claude Code included,
# and which leaks into commands launched from inside one -- Enter is reported as
# \e[13u instead of \n. The read never terminates, so sudo times out and PAM
# logs "conversation failed" / "authentication failure" rather than anything
# about the password. zsh's own line editor speaks the protocol, which is why
# `read` works in the same terminal and it looks like sudo alone is broken.
#
# CSI > 0 u pushes a flags=0 (legacy) keyboard mode; CSI < u pops back to
# whatever was active, so the surrounding TUI keeps its own mode.
if [[ -n "${KITTY_WINDOW_ID:-}" ]]; then
    _kitty_legacy_keys_run() {
        local cmd="$1"; shift
        [[ -t 0 && -t 1 ]] || { command "$cmd" "$@"; return $?; }
        printf '\033[>0u'
        command "$cmd" "$@"
        local ret=$?
        printf '\033[<u'
        return $ret
    }
    # ssh is handled in _ssh_run above; overriding ssh() here would bypass its
    # reconnect and terminal-mode cleanup behavior entirely.
    for _kk_cmd in sudo su passwd; do
        eval "${_kk_cmd}() { _kitty_legacy_keys_run ${_kk_cmd} \"\$@\"; }"
    done
    unset _kk_cmd
fi
