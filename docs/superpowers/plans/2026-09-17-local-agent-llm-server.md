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
- Docker owns `table ip filter` / `ip nat` / `ip6 filter` via iptables-nft with `INPUT policy accept`; Tailscale's `ts-input` hangs off that same INPUT at priority 0. An independent `table inet ollama_gate` at priority `filter - 10` is evaluated first and coexists: an `accept` there is chain-local and does not bypass `ts-input`, so Tailscale's anti-spoof rule still guards the tailnet allow rule.
- Two desktop containers reach Ollama through the host gateway: `open-webui` (`OLLAMA_BASE_URL=http://host.docker.internal:11434`, bridge gw `172.23.0.1`) and `myproject-myagent` (`OLLAMA_HOST=...`, gw `172.22.0.1`). **Decision (Alex, 2026-09-18): allow `172.16.0.0/12` in the gate** rather than repoint them.
- Claude Code 2.1.270 binary contains both `ANTHROPIC_DEFAULT_HAIKU_MODEL` and `ANTHROPIC_SMALL_FAST_MODEL`; the latter is the deprecated alias, so setting both to one value is safe. Note `POST /v1/messages/count_tokens` returns 404 on Ollama, so the token-budget display may be degraded.
- `ollama` is a built-in Codex provider ID whose `base_url` is reportedly ignored (openai/codex#8240, #1734); define a differently-named provider.
- On isis, `alex` is in `docker` and `homelab`; `.env` is group-writable, so no sudo is needed. `docker compose` run from `/home/ween/homelab/services` resolves `llm-router` (65 services via includes).
- isis's `.env` is **already** `{"arch":"http://192.168.0.40:11434"}` with tier `mac,arch`; only the *running container* still carries the obsolete `arch-vpn2`. The real change is the IP plus dropping the dead `mac`.
- Desktop tailnet IP: `100.84.247.20`. GPU idles at 3.6 GB of 32 GB. Root filesystem is at 97% (34 GB free).

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

Append inside the existing `[Service]` section:

```ini
Environment="OLLAMA_CONTEXT_LENGTH=131072"
Environment="OLLAMA_NUM_PARALLEL=1"
EnvironmentFile=-/etc/ollama/cloud.env
```

The leading `-` means "ignore if absent", so the service starts before the cloud key exists. `EnvironmentFile=` is applied after `Environment=`; there is no name collision (`OLLAMA_API_KEY` appears nowhere else).

- [ ] **Step 3: Allow `etc/` in the repo**

Add next to the other allow-list entries in `~/.config/.gitignore`:

```
!etc/
!etc/**
```

- [ ] **Step 4: Verify git sees exactly the intended files**

Run: `cd ~/.config && git status --short etc/ .gitignore`
Expected: `?? etc/ollama-override.conf` and ` M .gitignore`. The repo has unrelated modified files (`HOWTO.md`, `hypr/config/*.lua`) — never `git add -A` here.

- [ ] **Step 5: Commit**

```bash
cd ~/.config && git add .gitignore etc/ollama-override.conf
git commit -m "ollama: track the service drop-in, add long context and cloud env file"
```

### Task 2: Cap context for the small models FIRST

Ordering matters: Task 3 makes 131072 the server-wide default, which would cost
`qwen3:8b` (hermes, sandbox, Open WebUI) ~10.2 GB of KV cache. Build and adopt the
capped variant *before* that lands.

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

- [ ] **Step 3: Verify the cap actually beats the server default**

Do this check *after* Task 3 is applied, and treat it as the gate on the whole approach:

```bash
curl -s --max-time 120 localhost:11434/api/chat \
  -d '{"model":"qwen3:8b-32k","stream":false,"messages":[{"role":"user","content":"hi"}]}' >/dev/null
ollama ps
```
Expected: CONTEXT `32768`.

**If it shows 131072, the env default wins over Modelfile options in this Ollama
release.** Fallback: set `OLLAMA_CONTEXT_LENGTH` to a small-model-safe 32768 and have
the coder clients request large context per call instead (opencode `limit.context`,
and `num_ctx` via `/api/chat` where a client allows it). Record which way it went.

- [ ] **Step 4: Switch the small-model consumers**

Point `sandbox` (`~/.config/sandbox/settings.json`) and hermes/Open WebUI at
`qwen3:8b-32k`, or explicitly record that they stay on `qwen3:8b` and accept the
10.2 GB KV cost. Do not leave this undecided — it is the whole reason for the task.

- [ ] **Step 5: Commit**

```bash
cd ~/.config && git add etc/qwen3-8b-32k.Modelfile
git commit -m "ollama: cap qwen3:8b at 32k context for the small-model agents"
```

### Task 3: Apply the drop-in with a rollback path

**Files:**
- Modify: `/etc/systemd/system/ollama.service.d/override.conf` (root-owned, outside the repo)

Note: `systemctl restart ollama` evicts the loaded model and interrupts any in-flight
request from isis or Open WebUI. Pick a quiet moment.

- [ ] **Step 1: Back up the live file**

```bash
sudo cp /etc/systemd/system/ollama.service.d/override.conf \
        /etc/systemd/system/ollama.service.d/override.conf.bak-$(date +%Y%m%d)
```

systemd reads only `*.conf`, so `.bak-<date>` is ignored, like the three existing stale siblings.

- [ ] **Step 2: Install and reload**

```bash
sudo install -m 644 ~/.config/etc/ollama-override.conf \
        /etc/systemd/system/ollama.service.d/override.conf
sudo systemctl daemon-reload && sudo systemctl restart ollama
```

- [ ] **Step 3: Verify the environment took effect**

```bash
systemctl show ollama -p Environment | tr ' ' '\n' | grep -E 'CONTEXT_LENGTH|NUM_PARALLEL'
systemctl show ollama -p EnvironmentFiles
```
Expected: both variables present, and `EnvironmentFiles=/etc/ollama/cloud.env (ignore_errors=yes)`.

- [ ] **Step 4: Verify a client with no explicit context gets 131072**

```bash
curl -s --max-time 120 localhost:11434/api/chat \
  -d '{"model":"glm-4.7-flash","stream":false,"messages":[{"role":"user","content":"hi"}]}' >/dev/null
ollama ps
```
Expected: CONTEXT `131072`. This is the proof that Claude Code and Codex get long context.

**Rollback:** restore the `.bak-<date>` file, `daemon-reload`, `restart ollama`.

- [ ] **Step 5: No commit** — this task changes only `/etc`. Record the outcome.

---

## Chunk 2: Network gate

### Task 4: Gate port 11434 to LAN, tailnet and docker bridges

Ollama's API is unauthenticated, includes `/api/delete`, binds every interface, and will hold a key that spends money.

**Files:**
- Create: `~/.config/etc/ollama-gate.nft`
- Create: `~/.config/etc/ollama-gate.service`

- [ ] **Step 1: Write the ruleset as positive matches only**

Every rule must match `tcp dport 11434` first. A bare `tcp dport != 11434 accept`
would leave UDP, ICMP and **all IPv6** traffic falling through to the drop — which
would kill IPv6 NDP/RA, Tailscale's direct UDP :41641, and WireGuard handshakes.

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

    tcp dport 11434 iif lo accept
    tcp dport 11434 ip saddr 192.168.0.0/24 accept comment "LAN"
    tcp dport 11434 ip saddr 100.64.0.0/10 accept comment "tailnet"
    tcp dport 11434 ip saddr 172.16.0.0/12 accept comment "docker bridges: open-webui, myproject-myagent"
    tcp dport 11434 counter drop comment "everything else"
  }
}
```

Everything not matching `tcp dport 11434` falls off the chain end to `policy accept`.

- [ ] **Step 2: Dry-run the syntax without loading**

Run: `sudo nft -c -f ~/.config/etc/ollama-gate.nft`
Expected: no output. Any error means stop.

- [ ] **Step 3: Positive control BEFORE loading the gate**

The blocked-path test is worthless without proving the probe works first:

```bash
docker run --rm --network open-webui_default curlimages/curl:latest \
  -s -m 5 -o /dev/null -w '%{http_code}\n' http://172.23.0.1:11434/api/version
```
Expected: `200`. If the image pull fails (root is 97% full), fix that before continuing.

- [ ] **Step 4: Load it and verify all four paths**

```bash
sudo nft -f ~/.config/etc/ollama-gate.nft
curl -s -m 5 localhost:11434/api/version                              # expect version JSON
curl -s -m 5 http://100.84.247.20:11434/api/version                   # expect version JSON
ssh isis-alex 'curl -s -m 5 http://100.84.247.20:11434/api/version'   # expect version JSON
docker run --rm --network open-webui_default curlimages/curl:latest \
  -s -m 5 -o /dev/null -w '%{http_code}\n' http://172.23.0.1:11434/api/version  # expect 200 (allowed)
ping -c1 -W2 192.168.0.176 && ping -c1 -W2 2606:4700:4700::1111      # IPv4 + IPv6 still work
tailscale status | head -3                                            # still direct, not relayed
```

Instant undo if anything misbehaves: `sudo nft destroy table inet ollama_gate`.

- [ ] **Step 5: Persist, verify, commit**

`~/.config/etc/ollama-gate.service`:

```ini
[Unit]
Description=Restrict Ollama (11434) to LAN, tailnet and docker bridges
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
systemctl is-enabled ollama-gate && sudo nft list table inet ollama_gate | head -5
```

The running gate is a *copy*: editing the repo file requires re-running `install` (document this in HOWTO, Task 11).

```bash
cd ~/.config && git add etc/ollama-gate.nft etc/ollama-gate.service
git commit -m "ollama: restrict 11434 to LAN, tailnet and docker bridges"
```

---

## Chunk 3: Client wiring

### Task 5: Claude Code wrapper

**Files:**
- Create: `~/.config/scripts/claude-local`
- Symlink: `~/.local/bin/claude-local`

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
# SMALL_FAST is the deprecated alias of DEFAULT_HAIKU; identical values make
# precedence moot.
export ANTHROPIC_SMALL_FAST_MODEL="$LLM_MODEL"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$LLM_MODEL"

exec claude "$@"
```

- [ ] **Step 2: Install and make executable**

```bash
chmod +x ~/.config/scripts/claude-local
ln -sfn ~/.config/scripts/claude-local ~/.local/bin/claude-local
```

- [ ] **Step 3: Prove the request hits Ollama, not Anthropic**

A reply alone proves nothing — the existing Anthropic login would answer too. Watch the server:

```bash
journalctl -u ollama -f &   # leave running
claude-local -p "reply with only: ok" 2>&1 | tail -3
# expect a POST /v1/messages line in the journal, then:
kill %1
```
Expected: `/v1/messages` appears in the Ollama journal during the call.

- [ ] **Step 4: Confirm the model served it**

Run: `ollama ps`
Expected: `glm-4.7-flash` resident. Combined with Step 3's journal line, that is proof.

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

Append only; the file already holds `model = "gpt-6-astra"` and many `[projects.*]` blocks.

- [ ] **Step 3: Validate the config shape**

```bash
codex --strict-config doctor 2>&1 | tail -20
```
Expected: no "unrecognized field" error. `--profile` is typed `CONFIG_PROFILE_V2` in 0.154.0, so a wrong profile shape is a real risk; strict mode is what catches it.

- [ ] **Step 4: Prove the run reaches Ollama and the default is unchanged**

```bash
journalctl -u ollama -f &
codex -p local exec "reply with only: ok" 2>&1 | tail -5
kill %1
codex doctor 2>&1 | grep -iE 'default model|model provider'
```
Expected: a `/v1/responses` line in the Ollama journal (Codex can silently fall back to the default provider, so the journal is the proof), and the doctor output still naming `gpt-6-astra · openai`.

- [ ] **Step 5: Commit the snippet**

```bash
cd ~/.config && git add codex/config-local.toml
git commit -m "codex: add a local profile pointing at the desktop Ollama server"
```

### Task 7: opencode context limits and small model

**Files:**
- Modify: `~/.config/opencode/opencode.json`

- [ ] **Step 1: Raise context only for the coder-class models**

Set `limit.context` to `131072` for `qwen3-coder:30b` and `qwen3.6:27b`, and add a `glm-4.7-flash` entry with `{ "context": 131072, "output": 16384 }`. Leave `qwen2.5:7b-instruct` at 32768 — its real ceiling.

- [ ] **Step 2: Change `small_model` off qwen3:8b**

`"small_model": "ollama/glm-4.7-flash"` — same eviction reasoning as Claude Code.

- [ ] **Step 3: Assert the values, not just valid JSON**

```bash
jq -e '.small_model=="ollama/glm-4.7-flash"
  and .provider.ollama.models["glm-4.7-flash"].limit.context==131072
  and .provider.ollama.models["qwen2.5:7b-instruct"].limit.context==32768' \
  ~/.config/opencode/opencode.json && echo asserted
```
Expected: `asserted`.

- [ ] **Step 4: Leave the desktop on localhost**

Do **not** run `setup-llm.sh` here: the desktop is the server, and
`~/.local/state/dotfiles/llm.env` is sourced by `zsh/.zshrc:185` *before* the localhost
fallback, so writing a tailnet URL would override the correct local value. That command
belongs on *other* machines: `bash ~/.config/scripts/setup-llm.sh http://100.84.247.20:11434/v1`.
Document it in HOWTO (Task 11).

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

The on-disk `.env` is already `arch`-only; only the running container still has the
obsolete `arch-vpn2`. Remaining edits: the IP, and dropping the dead `mac` tier entry.

```bash
ssh isis-alex 'cd /home/ween/homelab/services/llm-router && cp .env .env.bak-$(date +%Y%m%d)'
```

Set:
```
LLM_ROUTER_BACKENDS_JSON={"arch":"http://100.84.247.20:11434"}
LLM_ROUTER_BACKEND_TIER=arch
```

`apps/llm-router/docker-compose.yml` maps `BACKENDS_JSON=${LLM_ROUTER_BACKENDS_JSON}`, so the prefixed names are correct.

- [ ] **Step 2: Recreate the container**

```bash
ssh isis-alex 'cd /home/ween/homelab/services && docker compose up -d --force-recreate llm-router'
```

No sudo needed (`alex` is in `docker`). Running from `services/` resolves `llm-router` through the include tree; `services/llm-router/` also works.

- [ ] **Step 3: Verify the backend URL actually changed**

```bash
ssh isis-alex 'docker inspect llm-router --format "{{range .Config.Env}}{{println .}}{{end}}" | grep BACKEND'
ssh isis-alex 'sleep 35; docker exec llm-router wget -qO- http://127.0.0.1:8080/health'
```
Expected: env shows `100.84.247.20`; health shows `arch` non-zero and no `arch-vpn2` key.

- [ ] **Step 4: Verify a real completion, plus the external URL**

```bash
ssh isis-alex 'docker exec llm-router wget -qO- -T 60 --header="content-type: application/json" \
  --post-data="{\"model\":\"glm-4.7-flash\",\"messages\":[{\"role\":\"user\",\"content\":\"say ok\"}],\"max_tokens\":50}" \
  http://127.0.0.1:8080/v1/chat/completions' | head -c 200
curl -s -m 10 https://llm.thelunadog.com/health   # spec criterion 3; Traefik local-only@file
```

- [ ] **Step 5: Confirm nothing needs committing on isis**

`/home/ween/homelab/.gitignore` excludes `.env`, `.env.*` and `*.bak`, and the `.env` holds a live MiniMax key. Run `ssh isis-alex 'cd /home/ween/homelab && git status --short'` and expect no `.env` entries.

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

- [ ] **Step 2: Install the real key without a world-readable window**

```bash
sudo install -d -m 755 /etc/ollama
read -rs KEY                      # paste; not echoed, not in history
printf 'OLLAMA_API_KEY=%s\n' "$KEY" | sudo install -m 600 /dev/stdin /etc/ollama/cloud.env
unset KEY
sudo systemctl restart ollama
```

`install -m 600` creates the file with the mode already set, unlike `tee` + `chmod`.

- [ ] **Step 3: Verify a cloud model answers through the local server**

```bash
curl -s --max-time 120 localhost:11434/api/chat \
  -d '{"model":"glm-5.3-flash:cloud","stream":false,"messages":[{"role":"user","content":"say ok"}]}' \
  | head -c 200
```
Expected: a reply. An auth error means the server does not read `OLLAMA_API_KEY` for proxying — fall back to `sudo -u ollama HOME=/var/lib/ollama ollama signin` and record which mechanism worked.

- [ ] **Step 4: Verify it works from isis over the tailnet**

```bash
ssh isis-alex 'curl -s -m 120 http://100.84.247.20:11434/v1/chat/completions \
  -H "content-type: application/json" \
  -d "{\"model\":\"deepseek-v4.1-flash:cloud\",\"messages\":[{\"role\":\"user\",\"content\":\"say ok\"}]}"' | head -c 200
```
Expected: a completion. This is the point of the design — remote agents get frontier models through the same endpoint.

- [ ] **Step 5: Commit the example only**

```bash
cd ~/.config && git add etc/cloud.env.example
git commit -m "ollama: document the cloud key env file"
```

Confirm `git status` never shows the real key file (it lives outside the repo).

---

## Chunk 5: Acceptance and docs

### Task 10: Run the spec's success criteria

- [ ] **Step 1: Agent tool-call test.** In a scratch repo, have each of opencode, `claude-local`, `codex -p local` and hermes edit a named file via tool calls. Record pass/fail and any malformed tool calls per client.

- [ ] **Step 2: Tailnet test.** `ssh isis-alex 'curl -s --max-time 30 http://100.84.247.20:11434/v1/models'` lists the coder model, and one `/v1/chat/completions` call returns 200.

- [ ] **Step 3: Eviction measurement.** During a coding session: `journalctl -u ollama --since "10 min ago" | grep -ci 'loading model'`, confirming loads happen only after a small-model request and complete in under 30s.

- [ ] **Step 4: Persistence.** `systemctl is-enabled ollama ollama-gate`, `systemctl show ollama -p Environment`, and after the next reboot `tailscale debug prefs | grep RouteAll` still `false`, plus `nft list table inet ollama_gate` still present. **Ask Alex before rebooting** — it ends the session.

- [ ] **Step 5: Model bake-off.** Apply the spec's decision rule: `glm-4.7-flash` replaces `qwen3-coder:30b` only if it completes at least as many of three agent tasks without malformed tool calls and is no more than 25% slower. Remove the loser to reclaim ~19 GB (disk at 97%).

### Task 11: Update the default model and the repo docs

**Files:**
- Modify: `~/.config/environment.d/50-llm.conf`, `~/.config/zsh/.zshrc`
- Modify: `~/.config/README.md`, `ARCHITECTURE.md`, `ROADMAP.md`, `HOWTO.md`

- [ ] **Step 1: Update `LLM_MODEL` to the bake-off winner**

Both `environment.d/50-llm.conf` and the `zsh/.zshrc:191` fallback default to `qwen3-coder:30b`. If Task 10 Step 5 removed that model, every non-shell launcher would point at a deleted model. Update both to the winner.

- [ ] **Step 2: README** — add the local agent server and the one-liner for pointing *another* machine at it (`scripts/setup-llm.sh <url>`).

- [ ] **Step 3: ARCHITECTURE** — the topology (desktop Ollama as the single model server; isis reaches it over the tailnet via llm-router) and the decisions with teeth: network-only auth plus the nftables gate, one loaded model at a time.

- [ ] **Step 4: HOWTO** — run an agent against the local server; switch the default model; add the cloud key; roll back the drop-in or the gate; and the warning that editing `etc/ollama-gate.nft` requires re-running `install` or the running gate drifts.

- [ ] **Step 5: ROADMAP + commit** — status and deferrals (`/think` handling, whether hermes/Open WebUI move to `qwen3:8b-32k`, disk cleanup).

```bash
cd ~/.config && git add README.md ARCHITECTURE.md ROADMAP.md HOWTO.md environment.d/50-llm.conf zsh/.zshrc
git commit -m "docs: record the local agent LLM server"
```

`HOWTO.md` had uncommitted changes before this work began — check `git diff` and keep them.
