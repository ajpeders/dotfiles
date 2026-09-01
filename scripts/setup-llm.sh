#!/bin/bash
# Point the local LLM coding tools (opencode) at a llama.cpp / OpenAI-compatible
# server, and record the URL per-machine.
# Usage: bash scripts/setup-llm.sh [base-url]
#   e.g. bash scripts/setup-llm.sh http://r9700.lan:8080/v1
#
# The URL is written to ~/.local/state/dotfiles/llm.env as LLM_SERVER_URL and
# sourced by zsh/.zshrc. It lives under ~/.local/state (next to dotfiles-mode)
# rather than ~/.config because on Arch the repo IS ~/.config — anything there
# would be inside the working tree. It is a LAN address that differs per machine
# and must not reach the public mirror.
#
# Safe to re-run; re-running just re-probes and rewrites the same file.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The repo root is one level up: this script lives in <repo>/scripts/.
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV_DIR="$HOME/.local/state/dotfiles"
ENV_FILE="$ENV_DIR/llm.env"
OPENCODE_CONFIG="$REPO_DIR/opencode/opencode.json"
PROVIDER="llama.cpp"

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
        --help|-h) sed -n '2,13p' "$0" | sed -E 's/^# ?//'; exit 0 ;;
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
    print_info "URL does not end in /v1 — most llama.cpp and vLLM servers expect it."
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

# ---------- 3. Pick a model ----------

if [ "${#MODEL_IDS[@]}" -eq 1 ]; then
    MODEL_ID="${MODEL_IDS[0]}"
    print_status "Using the only model served: $MODEL_ID"
else
    echo ""
    echo -e "${BOLD}Models served:${NC}"
    for i in "${!MODEL_IDS[@]}"; do
        printf '  %2d) %s\n' "$((i + 1))" "${MODEL_IDS[$i]}"
    done
    echo ""
    read -rp "Select a model [1]: " choice
    choice="${choice:-1}"
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#MODEL_IDS[@]}" ]; then
        print_error "Invalid selection: $choice"
        exit 1
    fi
    MODEL_ID="${MODEL_IDS[$((choice - 1))]}"
fi

# ---------- 4. Write the env file ----------

mkdir -p "$ENV_DIR"
cat > "$ENV_FILE" <<EOF
# Written by scripts/setup-llm.sh — per-machine, intentionally outside the repo.
# opencode reads this via {env:LLM_SERVER_URL} in opencode/opencode.json.
export LLM_SERVER_URL="$BASE_URL"
EOF
print_status "Wrote $ENV_FILE"

# ---------- 5. Point opencode at the chosen model ----------

if [ ! -f "$OPENCODE_CONFIG" ]; then
    print_info "No opencode config at $OPENCODE_CONFIG, skipping model wiring"
else
    if ! jq -e . "$OPENCODE_CONFIG" >/dev/null 2>&1; then
        print_error "$OPENCODE_CONFIG is not valid JSON; fix it and re-run"
        exit 1
    fi

    # Keep whatever display name / limits the model entry already had, so a
    # hand-tuned context window survives a re-run.
    tmp="$(mktemp)"
    jq --arg provider "$PROVIDER" --arg model "$MODEL_ID" '
        .model = ($provider + "/" + $model)
        | .provider[$provider].models |= (
            if has($model) then .
            else . + { ($model): { "name": $model } }
            end
          )
    ' "$OPENCODE_CONFIG" > "$tmp"

    if ! jq -e . "$tmp" >/dev/null 2>&1; then
        rm -f "$tmp"
        print_error "Failed to update $OPENCODE_CONFIG"
        exit 1
    fi
    mv "$tmp" "$OPENCODE_CONFIG"
    print_status "opencode default model: $PROVIDER/$MODEL_ID"
fi

# ---------- 6. Done ----------

echo ""
echo -e "${GREEN}LLM setup complete.${NC}"
echo ""
echo -e "${BOLD}Server:${NC} $BASE_URL"
echo -e "${BOLD}Model: ${NC} $MODEL_ID"
echo ""
if [ "${LLM_SERVER_URL:-}" != "$BASE_URL" ]; then
    echo "Start a new shell (or 'source $ENV_FILE') to pick up LLM_SERVER_URL."
    echo ""
fi
