#!/bin/bash
# Point the local LLM coding tools (opencode) at an Ollama / llama.cpp /
# OpenAI-compatible server, and record the URL per-machine.
# Usage: bash scripts/setup-llm.sh [base-url]
#   e.g. bash scripts/setup-llm.sh http://<host>:11434/v1   # Ollama
#
# The URL is written to ~/.local/state/dotfiles/llm.env as LLM_SERVER_URL and
# sourced by zsh/.zshrc. That lives under
# ~/.local/state (next to dotfiles-mode) rather than ~/.config because on Arch
# the repo IS ~/.config — anything there would be inside the working tree. The
# URL is a LAN address that differs per machine and must not reach the public
# mirror.
#
# Safe to re-run; re-running just re-probes and rewrites the same file.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The repo root is one level up: this script lives in <repo>/scripts/.
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV_DIR="$HOME/.local/state/dotfiles"
ENV_FILE="$ENV_DIR/llm.env"
SYSTEMD_ENV_DIR="$HOME/.config/environment.d"
SYSTEMD_ENV_FILE="$SYSTEMD_ENV_DIR/90-llm-local.conf"
OPENCODE_CONFIG="$REPO_DIR/opencode/opencode.json"
PROVIDER="ollama"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${YELLOW}[i]${NC} $1"; }

for arg in "$@"; do
    case "$arg" in
        # Print the header comment block, however long it happens to be.
        --help|-h) awk 'NR>1{ if (!/^#/) exit; sub(/^# ?/,""); print }' "$0"; exit 0 ;;
    esac
done

for bin in curl jq; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        print_error "$bin not found; install it first"
        exit 1
    fi
done

# ---------- 1. Base URL ----------

if [ $# -ge 1 ]; then
    BASE_URL="$1"
else
    default_url=""
    # Offer whatever is already configured as the default, so re-runs are a no-op.
    if [ -f "$ENV_FILE" ]; then
        default_url="$(sed -n 's/^export LLM_SERVER_URL=["'\'']\{0,1\}\([^"'\'']*\).*/\1/p' "$ENV_FILE" | head -1)"
    fi
    if [ -n "${LLM_SERVER_URL:-}" ]; then
        default_url="$LLM_SERVER_URL"
    fi

    if [ -n "$default_url" ]; then
        read -rp "LLM server base URL [$default_url]: " BASE_URL
        BASE_URL="${BASE_URL:-$default_url}"
    else
        echo "Base URL of the OpenAI-compatible server, including the /v1 path."
        echo "  e.g. http://r9700.lan:8080/v1   or   http://192.168.1.50:8080/v1"
        read -rp "LLM server base URL: " BASE_URL
    fi
fi

if [ -z "${BASE_URL:-}" ]; then
    print_error "No URL provided"
    exit 1
fi

# Trailing slashes break naive URL joins downstream.
BASE_URL="${BASE_URL%/}"

case "$BASE_URL" in
    http://*|https://*) ;;
    *)
        print_error "URL must start with http:// or https:// (got: $BASE_URL)"
        exit 1
        ;;
esac

if [ "${BASE_URL##*/}" != "v1" ]; then
    print_info "URL does not end in /v1 — most Ollama, llama.cpp and vLLM servers expect it."
    read -rp "Append /v1? [Y/n]: " append_v1
    case "${append_v1:-y}" in
        [Yy]*|"") BASE_URL="$BASE_URL/v1" ;;
    esac
fi

# ---------- 2. Probe ----------

print_info "Probing $BASE_URL/models ..."
models_json=""
if ! models_json="$(curl -fsS --max-time 10 "$BASE_URL/models" 2>&1)"; then
    print_error "Could not reach $BASE_URL/models"
    print_error "  ${models_json}"
    print_info "Check the server is running and reachable from this machine:"
    print_info "  curl $BASE_URL/models"
    exit 1
fi

if ! echo "$models_json" | jq -e '.data' >/dev/null 2>&1; then
    print_error "Server responded but not with an OpenAI-style model list:"
    echo "$models_json" | head -5
    exit 1
fi

# Read into an array the long way: macOS ships bash 3.2, which has no mapfile.
MODEL_IDS=()
while IFS= read -r line; do
    [ -n "$line" ] && MODEL_IDS+=("$line")
done < <(echo "$models_json" | jq -r '.data[].id')

if [ "${#MODEL_IDS[@]}" -eq 0 ]; then
    print_error "Server is up but serving no models"
    exit 1
fi
print_status "Reachable — ${#MODEL_IDS[@]} model(s) available"

# ---------- 3. Write the env file ----------

mkdir -p "$ENV_DIR" "$SYSTEMD_ENV_DIR"
cat > "$ENV_FILE" <<EOF
# Written by scripts/setup-llm.sh — per-machine, intentionally outside the repo.
# opencode reads LLM_SERVER_URL via {env:...} in opencode/opencode.json.
export LLM_SERVER_URL="$BASE_URL"
EOF
print_status "Wrote $ENV_FILE"

cat > "$SYSTEMD_ENV_FILE" <<EOF
# Written by scripts/setup-llm.sh — per-machine and intentionally gitignored.
LLM_SERVER_URL=$BASE_URL
EOF
print_status "Wrote $SYSTEMD_ENV_FILE"

# Make menu/keybinding launches use the new endpoint immediately. environment.d
# remains the durable source for the next login.
if systemctl --user show-environment >/dev/null 2>&1; then
    systemctl --user set-environment "LLM_SERVER_URL=$BASE_URL"
    print_status "Updated the current systemd user environment"
fi

# ---------- 4. Compare the served models with the catalog ----------

# opencode.json is a machine-agnostic catalog: it declares context/output limits
# per model; the agents' models are fixed in the file. This script deliberately
# does NOT rewrite it — doing so dirtied the repo on every machine that served a
# different model. It only reports the drift, in both directions: an id the
# catalog lists but the server dropped 404s the moment an agent picks it.
if [ ! -f "$OPENCODE_CONFIG" ]; then
    print_info "No opencode config at $OPENCODE_CONFIG, skipping catalog check"
elif ! jq -e . "$OPENCODE_CONFIG" >/dev/null 2>&1; then
    print_error "$OPENCODE_CONFIG is not valid JSON; fix it and re-run"
    exit 1
else
    catalog_ids="$(jq -r --arg p "$PROVIDER" \
        '.provider[$p].models // {} | keys[]' "$OPENCODE_CONFIG")"

    for id in "${MODEL_IDS[@]}"; do
        if ! echo "$catalog_ids" | grep -qxF "$id"; then
            print_info "Served but not in the catalog: $id"
            print_info "  It still works; add an entry to declare its limits."
        fi
    done

    while IFS= read -r id; do
        [ -n "$id" ] || continue
        printf '%s\n' "${MODEL_IDS[@]}" | grep -qxF "$id" && continue
        print_info "In the catalog but not served: $id (picking it 404s)"
    done <<< "$catalog_ids"
fi

# ---------- 5. Done ----------

echo ""
echo -e "${GREEN}LLM setup complete.${NC}"
echo ""
echo -e "${BOLD}Server:${NC} $BASE_URL"
echo -e "${BOLD}Models:${NC} ${MODEL_IDS[*]}"
echo ""
if [ "${LLM_SERVER_URL:-}" != "$BASE_URL" ]; then
    echo "Start a new shell (or 'source $ENV_FILE') to pick up the new values."
    echo ""
fi

# opencode runs a detached `serve --service` daemon that outlives every shell and
# is what actually talks to the server, so a new login alone does not repoint it:
# until it restarts it keeps the URL it was started with. It respawns on demand,
# so stopping it here is safe and is the only way the change takes effect today.
# Match on the process NAME and then inspect its arguments. A bare
# `pgrep -f 'opencode serve --service'` also matches any shell whose command line
# merely mentions that string — including the one running this script, which it
# would then kill.
opencode_service_pids() {
    local pid
    for pid in $(pgrep -x opencode 2>/dev/null); do
        case "$(ps -o args= -p "$pid" 2>/dev/null)" in
            *"serve --service"*) printf '%s ' "$pid" ;;
        esac
    done
}

service_pids="$(opencode_service_pids)"
if [ -n "$service_pids" ]; then
    # shellcheck disable=SC2086 # deliberately word-split: possibly several pids
    kill $service_pids 2>/dev/null || true
    # It shuts down gracefully and takes a moment; wait, so the interactive check
    # below does not mistake a dying daemon for a session the user has open.
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        [ -n "$(opencode_service_pids)" ] || break
        sleep 0.5
    done
    print_status "Stopped the opencode service daemon; it respawns with the new URL"
fi

# Anything still running is an interactive session, which we must not kill.
if pgrep -x opencode >/dev/null 2>&1; then
    echo "Quit and restart OpenCode so it inherits the updated server environment."
    echo ""
fi
