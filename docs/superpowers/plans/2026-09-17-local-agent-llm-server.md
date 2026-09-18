# Local Agent LLM Server Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the desktop's Ollama the model server for coding agents (opencode, Claude Code, Codex) and regular agents (hermes, companion apps) over the tailnet, with Ollama Cloud for models too large to run locally.

**Architecture:** No new service. Ollama 0.34 already serves the OpenAI, Responses and Anthropic wire protocols, and proxies `:cloud` models upstream for any client that asks. Work is therefore config only: a systemd drop-in, an nftables gate, three client configs, and one container env change on isis.

**Tech Stack:** Ollama 0.34.0 (Vulkan, R9700 32 GB), systemd, nftables, Tailscale, Docker on isis, zsh/dotfiles repo at `~/.config`.

**Spec:** `~/.config/docs/superpowers/specs/2026-09-17-local-agent-llm-server-design.md`

**Verified facts this plan depends on** (re-check if stale):
- The dotfiles repo *is* `~/.config` (forgejo `alex/dotfiles.git`). `~/projects/dotfiles` was a stale clone and has been deleted.
- `~/bin` is **not** on PATH; `~/.local/bin` is (PATH entry 3). Wrappers go to `~/.local/bin`.
- `/etc/nftables.conf` is the stock Arch template with `policy drop` and `destroy table inet filter`. It is NOT loaded and `nftables.service` is disabled. Do not enable it.
- Docker owns `table ip filter` / `ip nat` via iptables-nft. An independent `table inet ollama_gate` coexists safely.
- Claude Code 2.1.270 binary contains both `ANTHROPIC_DEFAULT_HAIKU_MODEL` and `ANTHROPIC_SMALL_FAST_MODEL`.
- `ollama` is a built-in Codex provider ID; define a differently-named provider instead.
- Desktop tailnet IP: `100.84.247.20`. GPU idles at 3.6 GB of 32 GB.

---

## Chunk 1: Server configuration

### Task 1: Track the Ollama drop-in in the repo

**Files:**
- Create: `~/.config/etc/ollama-override.conf`
- Modify: `~/.config/.gitignore`

- [ ] **Step 1: Capture the current drop-in as the starting point**

```bash
mkdir -p ~/.config/etc
cp /etc/systemd/system/ollama.service.d/override.conf ~/.config/etc/ollama-override.conf
```

- [ ] **Step 2: Add the two new settings and the cloud env file**

Append to `~/.config/etc/ollama-override.conf`, inside the existing `[Service]` section:

```ini
Environment="OLLAMA_CONTEXT_LENGTH=131072"
Environment="OLLAMA_NUM_PARALLEL=1"
EnvironmentFile=-/etc/ollama/cloud.env
```

The leading `-` means "ignore if absent", so the service still starts before the cloud key exists.

- [ ] **Step 3: Allow `etc/` in the repo**

`~/.config/.gitignore` ignores all directories by default. Add next to the other allow-list entries:

```
!etc/
!etc/**
```

- [ ] **Step 4: Verify git sees exactly the intended files**

Run: `cd ~/.config && git status --short etc/ .gitignore`
Expected: `?? etc/ollama-override.conf` and ` M .gitignore`. Note the repo has unrelated
modified files (`HOWTO.md`, `hypr/config/*.lua`) — never `git add -A` here.

- [ ] **Step 5: Commit**

```bash
cd ~/.config && git add .gitignore etc/ollama-override.conf
git commit -m "ollama: track the service drop-in, add long context and cloud env file"
```

### Task 2: Apply the drop-in with a rollback path

**Files:**
- Modify: `/etc/systemd/system/ollama.service.d/override.conf` (root-owned, outside the repo)

- [ ] **Step 1: Back up the live file**

```bash
sudo cp /etc/systemd/system/ollama.service.d/override.conf \
        /etc/systemd/system/ollama.service.d/override.conf.bak-$(date +%Y%m%d)
```

- [ ] **Step 2: Install and reload**

```bash
sudo install -m 644 ~/.config/etc/ollama-override.conf \
        /etc/systemd/system/ollama.service.d/override.conf
sudo systemctl daemon-reload && sudo systemctl restart ollama
```

- [ ] **Step 3: Verify the environment took effect**

Run: `systemctl show ollama -p Environment | tr ' ' '\n' | grep -E 'CONTEXT_LENGTH|NUM_PARALLEL'`
Expected: `OLLAMA_CONTEXT_LENGTH=131072` and `OLLAMA_NUM_PARALLEL=1`.

- [ ] **Step 4: Verify the server still answers and honours the context**

```bash
curl -s --max-time 120 localhost:11434/api/chat \
  -d '{"model":"glm-4.7-flash","stream":false,"messages":[{"role":"user","content":"hi"}]}' \
  | head -c 120
ollama ps
```
Expected: a reply, and `ollama ps` showing CONTEXT `131072` with no explicit `num_ctx` sent.
This is the proof that API clients (Claude Code, Codex) get long context.

**Rollback if anything fails:** restore the `.bak-<date>` file, `daemon-reload`, `restart ollama`.

- [ ] **Step 5: Commit nothing** — this task changes only `/etc`. Record the outcome in the task notes.

### Task 3: Cap context for the small models

The global 131072 would cost `qwen3:8b` 10.2 GB of KV cache. That model serves
hermes, sandbox and Open WebUI.

**Files:**
- Create: `~/.config/etc/qwen3-8b-32k.Modelfile`

- [ ] **Step 1: Write the Modelfile**

```
FROM qwen3:8b
PARAMETER num_ctx 32768
```

- [ ] **Step 2: Build the capped variant**

```bash
ollama create qwen3:8b-32k -f ~/.config/etc/qwen3-8b-32k.Modelfile
```

- [ ] **Step 3: Verify the cap**

```bash
curl -s --max-time 120 localhost:11434/api/chat \
  -d '{"model":"qwen3:8b-32k","stream":false,"messages":[{"role":"user","content":"hi"}]}' >/dev/null
ollama ps
```
Expected: CONTEXT `32768`, resident size well under 10 GB.

- [ ] **Step 4: Decide and record** whether hermes/sandbox/Open WebUI switch to
`qwen3:8b-32k`. Each consumer names its model in its own config; changing them is
out of scope for this plan. Note the decision in the spec's Open items.

- [ ] **Step 5: Commit**

```bash
cd ~/.config && git add etc/qwen3-8b-32k.Modelfile
git commit -m "ollama: cap qwen3:8b at 32k context for the small-model agents"
```

---

## Chunk 2: Network gate

### Task 4: Gate port 11434 to LAN and tailnet

Ollama's API is unauthenticated, includes `/api/delete`, binds every interface
including eight Docker bridges, and will soon hold a key that spends money.

**Files:**
- Create: `~/.config/etc/ollama-gate.nft`
- Create: `~/.config/etc/ollama-gate.service`

- [ ] **Step 1: Write the ruleset as its own table**

`~/.config/etc/ollama-gate.nft`:

```
#!/usr/bin/nft -f
# Independent of /etc/nftables.conf (stock template, policy drop, NOT loaded)
# and of Docker's iptables-nft tables in the ip family.
destroy table inet ollama_gate
table inet ollama_gate {
  chain input {
    type filter hook input priority filter - 10
    policy accept

    tcp dport != 11434 accept
    iif lo accept
    ip saddr 192.168.0.0/24 accept comment "LAN"
    ip saddr 100.64.0.0/10 accept comment "tailnet"
    counter drop comment "everything else, incl. docker bridges"
  }
}
```

- [ ] **Step 2: Dry-run the syntax without loading**

Run: `sudo nft -c -f ~/.config/etc/ollama-gate.nft`
Expected: no output. Any error here means do not proceed.

- [ ] **Step 3: Load it and test from three directions**

```bash
sudo nft -f ~/.config/etc/ollama-gate.nft
curl -s -m 5 localhost:11434/api/version                       # expect version JSON
curl -s -m 5 http://100.84.247.20:11434/api/version            # expect version JSON
ssh isis-alex 'curl -s -m 5 http://100.84.247.20:11434/api/version'  # expect version JSON
docker run --rm curlimages/curl:latest -s -m 5 http://172.17.0.1:11434/api/version \
  && echo "UNEXPECTED: bridge reached it" || echo "blocked as intended"
```

If the desktop loses connectivity in any unexpected way, run
`sudo nft destroy table inet ollama_gate` to remove the gate instantly.

- [ ] **Step 4: Make it persist across reboot**

`~/.config/etc/ollama-gate.service`:

```ini
[Unit]
Description=Restrict Ollama (11434) to LAN and tailnet
After=network-pre.target
Before=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/nft -f /etc/ollama-gate.nft
ExecStop=/usr/bin/nft destroy table inet ollama_gate

[Install]
WantedBy=multi-user.target
```

```bash
sudo install -m 644 ~/.config/etc/ollama-gate.nft /etc/ollama-gate.nft
sudo install -m 644 ~/.config/etc/ollama-gate.service /etc/systemd/system/ollama-gate.service
sudo systemctl daemon-reload && sudo systemctl enable --now ollama-gate.service
```

- [ ] **Step 5: Verify the unit and commit**

Run: `systemctl is-enabled ollama-gate && sudo nft list table inet ollama_gate | head -5`
Expected: `enabled`, and the table listed.

```bash
cd ~/.config && git add etc/ollama-gate.nft etc/ollama-gate.service
git commit -m "ollama: restrict 11434 to LAN and tailnet"
```

---

## Chunk 3: Client wiring

### Task 5: Claude Code wrapper

**Files:**
- Create: `~/.config/scripts/claude-local`
- Symlink: `~/.local/bin/claude-local` (PATH entry 3; `~/bin` is NOT on PATH)

- [ ] **Step 1: Write the wrapper**

```bash
#!/usr/bin/env bash
# Run Claude Code against the local Ollama server instead of Anthropic.
# Plain `claude` is unaffected.
set -euo pipefail

: "${LLM_HOST:=http://100.84.247.20:11434}"
: "${LLM_MODEL:=glm-4.7-flash}"

export ANTHROPIC_BASE_URL="$LLM_HOST"
export ANTHROPIC_AUTH_TOKEN="ollama"
export ANTHROPIC_MODEL="$LLM_MODEL"
# Background tasks (titles, summaries) must use the SAME model: only one model
# fits in VRAM, so a different small model would evict the coder every turn.
# 2.1.270 contains both names; set both rather than guess which it honours.
export ANTHROPIC_SMALL_FAST_MODEL="$LLM_MODEL"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$LLM_MODEL"

exec claude "$@"
```

- [ ] **Step 2: Install and make executable**

```bash
chmod +x ~/.config/scripts/claude-local
ln -sfn ~/.config/scripts/claude-local ~/.local/bin/claude-local
```

- [ ] **Step 3: Verify it reaches the local server, not Anthropic**

```bash
claude-local -p "reply with only: ok" 2>&1 | tail -3
ollama ps
```
Expected: a reply, and `ollama ps` showing the model resident. If it errors about
credentials, the request went to Anthropic — check `ANTHROPIC_BASE_URL` took effect.

- [ ] **Step 4: Verify plain `claude` is untouched**

Run: `env | grep -c ANTHROPIC_BASE_URL || true`
Expected: `0` in a normal shell — the wrapper exports only into its own process.

- [ ] **Step 5: Commit**

```bash
cd ~/.config && git add scripts/claude-local
git commit -m "claude: add claude-local wrapper for the desktop Ollama server"
```

### Task 6: Codex provider

**Files:**
- Create: `~/.config/codex/config-local.toml` (tracked snippet)
- Modify: `~/.codex/config.toml` (not in the repo)

- [ ] **Step 1: Write the snippet**

`ollama` is a built-in Codex provider ID whose `base_url` is reportedly ignored
(openai/codex#8240, #1734), so use a distinct name:

```toml
[model_providers.ollama-desktop]
name = "Ollama (desktop)"
base_url = "http://100.84.247.20:11434/v1"
wire_api = "responses"

[profiles.local]
model = "glm-4.7-flash"
model_provider = "ollama-desktop"
```

- [ ] **Step 2: Merge into the live config, with a backup**

```bash
cp ~/.codex/config.toml ~/.codex/config.toml.bak-$(date +%Y%m%d)
cat ~/.config/codex/config-local.toml >> ~/.codex/config.toml
```

Append only. The file already holds `model = "gpt-6-astra"` and many
`[projects.*]` blocks; appending a new table does not disturb them.

- [ ] **Step 3: Verify Codex parses it and the default is unchanged**

```bash
codex doctor 2>&1 | grep -iE 'model provider|default model'
codex -p local exec "reply with only: ok" 2>&1 | tail -5
```
Expected: default still `gpt-6-astra · openai`; the profile run answers from the
local model. Confirm with `ollama ps`.

- [ ] **Step 4: Commit the snippet**

```bash
cd ~/.config && git add codex/config-local.toml
git commit -m "codex: add a local profile pointing at the desktop Ollama server"
```

### Task 7: opencode context limits and small model

**Files:**
- Modify: `~/.config/opencode/opencode.json`

- [ ] **Step 1: Raise context only for the coder-class models**

Set `limit.context` to `131072` for `qwen3-coder:30b` and `qwen3.6:27b`, and add a
`glm-4.7-flash` entry with `{ "context": 131072, "output": 16384 }`. Leave
`qwen2.5:7b-instruct` at 32768 — that is its real ceiling.

- [ ] **Step 2: Change `small_model` off qwen3:8b**

`"small_model": "ollama/glm-4.7-flash"` — same eviction reasoning as Claude Code.

- [ ] **Step 3: Verify the JSON is valid**

Run: `jq -e . ~/.config/opencode/opencode.json >/dev/null && echo valid`
Expected: `valid`.

- [ ] **Step 4: Point this machine at the server and verify**

```bash
bash ~/.config/scripts/setup-llm.sh http://100.84.247.20:11434/v1
cat ~/.local/state/dotfiles/llm.env
```
Expected: `LLM_SERVER_URL` set to the tailnet URL. The tracked defaults in
`environment.d/50-llm.conf` and `zsh/.zshrc:190` stay on localhost, which is
correct for the desktop; other machines run the same script with the same URL.

- [ ] **Step 5: Commit**

```bash
cd ~/.config && git add opencode/opencode.json
git commit -m "opencode: long context for coder models, stop evicting on small tasks"
```

---

## Chunk 4: isis and cloud

### Task 8: Repoint llm-router at the tailnet address

**Files:**
- Modify: `/home/ween/homelab/services/llm-router/.env` on isis

- [ ] **Step 1: Back up and edit**

Live value is
`BACKENDS_JSON={"arch":"http://192.168.0.40:11434","arch-vpn2":"http://10.8.0.15:11434"}`
with `BACKEND_TIER=mac,arch,arch-vpn2`. All three addresses are the same machine,
so `arch-vpn2` is a fallback to the host that just failed, and `mac` is gone.

```bash
ssh isis-alex 'cd /home/ween/homelab/services/llm-router && cp .env .env.bak-$(date +%Y%m%d)'
```

Set:
```
LLM_ROUTER_BACKENDS_JSON={"arch":"http://100.84.247.20:11434"}
LLM_ROUTER_BACKEND_TIER=arch
```

- [ ] **Step 2: Recreate the container**

```bash
ssh isis-alex 'cd /home/ween/homelab/services && docker compose up -d --force-recreate llm-router'
```

- [ ] **Step 3: Verify health reports the new backend**

```bash
ssh isis-alex 'sleep 35; docker exec llm-router wget -qO- http://127.0.0.1:8080/health'
```
Expected: `arch` non-zero, no `arch-vpn2` key.

- [ ] **Step 4: Verify a real completion still works end to end**

```bash
ssh isis-alex 'docker exec llm-router wget -qO- -T 60 --header="content-type: application/json" \
  --post-data="{\"model\":\"glm-4.7-flash\",\"messages\":[{\"role\":\"user\",\"content\":\"say ok\"}],\"max_tokens\":50}" \
  http://127.0.0.1:8080/v1/chat/completions' | head -c 200
```
Expected: a chat completion JSON body.

- [ ] **Step 5: Commit on isis** if that directory is a git repo
(`/home/ween/homelab`, forgejo `alex/homeserver.git`); otherwise note the change.

### Task 9: Ollama Cloud

**Blocked until Alex provides an API key** from ollama.com (Pro plan).

**Files:**
- Create: `/etc/ollama/cloud.env` (mode 0600, untracked)
- Create: `~/.config/etc/cloud.env.example` (tracked)

- [ ] **Step 1: Write the tracked example**

```
# Copy to /etc/ollama/cloud.env, mode 0600. Never commit the real key.
OLLAMA_API_KEY=
```

- [ ] **Step 2: Install the real key**

```bash
sudo install -d -m 755 /etc/ollama
printf 'OLLAMA_API_KEY=%s\n' "$KEY" | sudo tee /etc/ollama/cloud.env >/dev/null
sudo chmod 600 /etc/ollama/cloud.env
sudo systemctl restart ollama
```

Do not paste the key into a shell that records history; prefer `read -rs KEY`.

- [ ] **Step 3: Verify a cloud model answers through the local server**

```bash
curl -s --max-time 120 localhost:11434/api/chat \
  -d '{"model":"glm-5.3-flash:cloud","stream":false,"messages":[{"role":"user","content":"say ok"}]}' \
  | head -c 200
```
Expected: a reply. An auth error means the server does not read `OLLAMA_API_KEY`
for proxying — fall back to `sudo -u ollama HOME=/var/lib/ollama ollama signin`
and record which mechanism actually worked.

- [ ] **Step 4: Verify it works from isis over the tailnet**

```bash
ssh isis-alex 'curl -s -m 120 http://100.84.247.20:11434/v1/chat/completions \
  -H "content-type: application/json" \
  -d "{\"model\":\"deepseek-v4.1-flash:cloud\",\"messages\":[{\"role\":\"user\",\"content\":\"say ok\"}]}"' | head -c 200
```
Expected: a completion. This is the whole point of the design — remote agents get
frontier models through the same endpoint.

- [ ] **Step 5: Commit the example only**

```bash
cd ~/.config && git add etc/cloud.env.example
git commit -m "ollama: document the cloud key env file"
```

Confirm `git status` never shows `/etc/ollama/cloud.env` (it is outside the repo).

---

## Chunk 5: Acceptance and docs

### Task 10: Run the spec's success criteria

- [ ] **Step 1: Agent tool-call test.** In a scratch repo, have each of opencode,
`claude-local`, `codex -p local` and hermes edit a named file via tool calls.
Record pass/fail and any malformed tool calls per client.

- [ ] **Step 2: Tailnet test.**
`ssh isis-alex 'curl -s --max-time 30 http://100.84.247.20:11434/v1/models'` lists
the coder model, and one `/v1/chat/completions` call returns 200.

- [ ] **Step 3: Eviction measurement.** During a coding session, run
`journalctl -u ollama --since "10 min ago" | grep -ci 'loading model'` and confirm
loads happen only after a small-model request, completing in under 30s.

- [ ] **Step 4: Persistence.** `systemctl is-enabled ollama ollama-gate`,
`systemctl show ollama -p Environment`, and after the next reboot
`tailscale debug prefs | grep RouteAll` still shows `false`.
**Ask Alex before rebooting** — rebooting ends the session.

- [ ] **Step 5: Model bake-off.** Run the spec's decision rule: `glm-4.7-flash`
replaces `qwen3-coder:30b` only if it completes at least as many of three agent
tasks without malformed tool calls and is no more than 25% slower. Record the
result; remove the loser to reclaim ~19 GB (disk is at 97%).

### Task 11: Update the repo docs

**Files:**
- Modify: `~/.config/README.md`, `ARCHITECTURE.md`, `ROADMAP.md`, `HOWTO.md`

- [ ] **Step 1: README** — add the local agent server to the overview and the
one-liner for pointing a machine at it (`scripts/setup-llm.sh <url>`).

- [ ] **Step 2: ARCHITECTURE** — record the topology (desktop Ollama as the single
model server; isis reaches it over the tailnet via llm-router) and the two
decisions with teeth: network-only auth plus the nftables gate, and one loaded
model at a time.

- [ ] **Step 3: HOWTO** — add: run an agent against the local server, switch the
default model, add the cloud key, and roll back the drop-in or the gate.

- [ ] **Step 4: ROADMAP** — status of this work and what is deferred
(`/think` handling, whether hermes/sandbox move to `qwen3:8b-32k`, disk cleanup).

- [ ] **Step 5: Commit**

```bash
cd ~/.config && git add README.md ARCHITECTURE.md ROADMAP.md HOWTO.md
git commit -m "docs: record the local agent LLM server"
```

Note `HOWTO.md` already had uncommitted changes before this work began — check
`git diff` and keep them.
