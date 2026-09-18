# Local LLM server for coding agents and regular agents

Date: 2026-09-17
Status: design approved, not implemented
Repo: this file lives in `~/.config` (the dotfiles repo itself)

## Goal

Make the desktop's Ollama the model server for coding agents (opencode, Claude
Code, Codex CLI) and regular agents (hermes-agent, companion apps), reachable
from any machine on the LAN or the tailnet, with Ollama Cloud available for
models too large to run locally.

Non-goals: no new gateway service, no per-client API keys, no multi-user quotas.

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Shape | Ollama direct, no new proxy | Ollama 0.34 already serves OpenAI `/v1`, `/v1/responses` and Anthropic `/v1/messages`; all three verified against the running server. |
| Client auth | None | User's choice: the network is the gate. |
| Network gate | nftables: port 11434 reachable only from `192.168.0.0/24` and `100.64.0.0/10` | `OLLAMA_HOST=0.0.0.0:11434` binds every interface including eight Docker bridges. The API is unauthenticated and includes `/api/delete`, `/api/pull`, and (once cloud is on) spending. |
| Concurrency | One agent at a time locally | User's choice. One model loaded, one parallel slot. |
| Address | `http://100.84.247.20:11434` (tailnet) | The LAN IP `192.168.0.40` is DHCP. MagicDNS is off on this tailnet (verified: `CurrentTailnet.MagicDNS` is null, `getent hosts archdesktop` fails on isis), so the raw tailnet IP is the stable option. |
| Cloud | Ollama Cloud on the Pro plan | Gives access to `glm-5.3-flash:cloud` and `deepseek-v4.1-flash:cloud`, which cannot run on 32 GB. |
| Home | `~/.config` | Verified: `~/.config` is the dotfiles repo (forgejo `alex/dotfiles.git`, branch `main`), and it tracks `opencode/opencode.json`, `environment.d/50-llm.conf`, `scripts/setup-llm.sh`, `zsh/.zshrc`. |

`~/projects/dotfiles` is a stale clone (forked at `b0b683f`, Sep 12) and is to be
deleted. An earlier draft of this spec used its paths and wrongly called the live
`zsh/.zshrc` "stale"; the live 191-line file is the tracked one.

## Prerequisite fixed during design (done)

isis could not reach the desktop at all. The desktop ran Tailscale with
`accept-routes` on while isis advertises `192.168.0.0/24`, so ip rule 5270
(table 52) sent the desktop's replies to LAN peers out `tailscale0`, where isis
dropped them. Echo requests arrived and were answered; the replies took the
wrong path. Fixed with `sudo tailscale set --accept-routes=false`; the router
went from `arch: 0` to `arch: 8` models.

Consequence to accept: the desktop no longer receives isis's advertised
`192.168.0.0/24` or exit-node routes, and `tailscale status` now warns about
this. Add a post-reboot check that the setting persisted.

## Server configuration

Drop-in `/etc/systemd/system/ollama.service.d/override.conf`, tracked as
`etc/ollama-override.conf`. Three stale siblings exist (`override.conf.bak`,
`.bak-keepalive`, `.disabled-20260329`); systemd ignores them, leave them.

Added:

- `OLLAMA_CONTEXT_LENGTH=131072` — the OpenAI and Anthropic APIs have no context
  field, so API clients get the server default. Claude Code's system prompt plus
  tool definitions alone run about 20k tokens.
- `OLLAMA_NUM_PARALLEL=1` — each slot allocates its own KV cache.
- `EnvironmentFile=-/etc/ollama/cloud.env` — holds `OLLAMA_API_KEY` (mode 0600,
  untracked; a `cloud.env.example` is tracked).

Kept: `OLLAMA_VULKAN=1`, `OLLAMA_FLASH_ATTENTION=1`, `OLLAMA_KV_CACHE_TYPE=q8_0`,
`OLLAMA_MAX_LOADED_MODELS=1`, `OLLAMA_KEEP_ALIVE=-1`,
`GGML_VK_VISIBLE_DEVICES=0`, `OLLAMA_HOST=0.0.0.0:11434`,
`OLLAMA_MODELS=/home/ollama`, `ProtectHome=no`.

Apply sequence, with rollback:

```sh
sudo cp /etc/systemd/system/ollama.service.d/override.conf \
        /etc/systemd/system/ollama.service.d/override.conf.bak-$(date +%Y%m%d)
sudo install -m 644 ~/.config/etc/ollama-override.conf \
        /etc/systemd/system/ollama.service.d/override.conf
sudo systemctl daemon-reload && sudo systemctl restart ollama
# rollback: restore the .bak-<date> file, daemon-reload, restart
```

### VRAM budget

The card reports 32 GB total (31 GiB) with ~3.6 GB used at idle by the desktop
session, so real headroom is about 28 GB. KV cache at q8_0 is ~1.06 bytes per
element; elements per token = 2 x layers x kv_heads x head_dim.

| Model | Layers x KV heads x dim | KV/token | KV at 131k | Weights | Total |
|---|---|---|---|---|---|
| `qwen3-coder:30b` | 48 x 4 x 128 | 52.1 KB | 6.8 GB | 18 GB | ~24.8 GB + graph buffers |
| `qwen3.6:27b` | 16 full-attn of 65 x 4 x 256 | 34.7 KB | 4.6 GB | 17 GB | ~21.6 GB, a floor (linear-attention state excluded) |
| `qwen3:8b` | 36 x 8 x 128 | 78.1 KB | 10.2 GB | 5.2 GB | ~15.4 GB |
| `glm-4.7-flash` | MLA, 47 x 576 latent | ~24 KB (measured) | ~3 GB | 19 GB | **22 GB measured at 131k, 100% GPU** |

`qwen3-coder:30b` at 131k fits the ~28 GB headroom, but not with room to spare.

The `qwen3:8b` row is why the global context length needs a counterweight: the
regular agents (hermes, sandbox, Open WebUI) call that model, and 131k would
cost it 10.2 GB of KV. Ship per-model `num_ctx` for the small models via a
Modelfile (e.g. 32k for `qwen3:8b`), or accept the cost knowingly.

### Eviction

`OLLAMA_MAX_LOADED_MODELS=1` means any regular-agent call to a small model
evicts the coder model; the next coding request waits for a reload. This is
already happening today (`ollama ps` has shown `qwen2.5-coder:1.5b-base`
resident where `qwen3:8b` was). Accepted, and measured rather than forbidden:
see criterion 4.

## Ollama Cloud

The local daemon detects a `:cloud` model suffix, attaches the stored
credentials, strips the suffix and proxies upstream. So LAN and tailnet clients
get cloud models through the same endpoint with no client change.

- Plan: Pro ($20/mo, $60 credits, 3 concurrent). Free tier is starter models
  with 1 concurrent request and does not cover these models.
- Auth: `OLLAMA_API_KEY` in `/etc/ollama/cloud.env`, read by the service. The
  service user is `ollama` with `HOME=/var/lib/ollama`; `ollama signin` is
  interactive and stores credentials per-user, so the env-file route is the one
  that fits a headless system service. To verify at implementation: that the
  server honours `OLLAMA_API_KEY` for proxying, not just the CLI.
- Models: `glm-5.3-flash:cloud` (320B total, 18B active, 1M context) and
  `deepseek-v4.1-flash:cloud` (552B, 1M context). Neither is downloadable.
- Kill switch: `OLLAMA_NO_CLOUD=1` disables cloud; removing `cloud.env` also
  suffices.
- Privacy: prompts and code sent to a `:cloud` model leave the machine. Local
  models remain the default; cloud is opt-in per request by model name.
- This is why the nftables gate is required rather than optional: an
  unauthenticated port that can spend money.

## Model selection

Researched 2026-09-17:

- **GLM 5.3** (Zhipu, 2026-08-14): ~744B MoE, ~40B active. Local: impossible.
  Cloud only, as `glm-5.3-flash:cloud`.
- **DeepSeek V4.1-Flash** (2026-09-10): 552B MoE, MIT licence, 1M context.
  Cloud only, as `deepseek-v4.1-flash:cloud`.
- **`glm-4.7-flash`**: 30B-A3B MoE, 19 GB at `q4_K_M`, 198K context, tools and
  thinking. The local candidate, comparable to `qwen3-coder:30b` (18 GB).

Decision rule for the local default: `glm-4.7-flash` replaces
`qwen3-coder:30b` only if, on the same three agent tasks (a multi-file edit, a
test-fix loop, a codebase question), it completes at least as many without
malformed tool calls and is no more than 25% slower end to end. Otherwise
`qwen3-coder:30b` stays and `glm-4.7-flash` is removed to reclaim 19 GB.

## Client wiring

Endpoint: `http://100.84.247.20:11434` (and `/v1` for OpenAI-style clients).

**opencode.** `opencode/opencode.json` (tracked in `~/.config`) reads
`{env:LLM_SERVER_URL}` and `{env:LLM_MODEL}`. Three sources set these:
`environment.d/50-llm.conf` (tracked, currently `http://localhost:11434/v1`),
a fallback at `zsh/.zshrc:190`, and `~/.local/state/dotfiles/llm.env` written by
`scripts/setup-llm.sh` (currently absent). Decision: leave the tracked defaults
on localhost — correct for the desktop itself — and set the tailnet URL
per-machine with `scripts/setup-llm.sh <url>`, the mechanism README.md:145 and
HOWTO.md:163 already document. Raise `limit.context` to 131072 only for the
coder models, not for `qwen2.5:7b-instruct` (real ceiling 32k). Change
`small_model` off `qwen3:8b` to the coder model, for the same eviction reason as
Claude Code.

**Claude Code.** New `scripts/claude-local`, symlinked into `~/.local/bin`
(`~/bin` exists but is NOT on PATH), setting `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`,
`ANTHROPIC_MODEL` and the background/small-model variable to the same model.
The exact name of that last variable (`ANTHROPIC_SMALL_FAST_MODEL` versus
`ANTHROPIC_DEFAULT_HAIKU_MODEL`) must be confirmed against the installed
version 2.1.270 at implementation time. Plain `claude` is untouched.

**Codex.** Codex reads `~/.codex/config.toml`. The tracked
`codex/config-local.toml` is a snippet to merge into that file (not a separate
config Codex would ignore), adding `[model_providers.ollama]` with
`base_url = "http://100.84.247.20:11434/v1"` and `wire_api = "responses"`, plus
`[profiles.local]`. Used as `codex -p local`; default stays `gpt-6-astra`.

**hermes, Open WebUI, companion apps.** These reach the desktop through
`llm-router` on isis, whose live config is
`BACKENDS_JSON={"arch":"http://192.168.0.40:11434","arch-vpn2":"http://10.8.0.15:11434"}`
with `BACKEND_TIER=mac,arch,arch-vpn2`. Two changes:
repoint `arch` at `100.84.247.20` (it currently uses the DHCP address this
design rejects), and remove `arch-vpn2` plus the dead `mac` from the tier.
`10.8.0.15`, `192.168.0.40` and `100.84.247.20` are all the same machine, so
`arch-vpn2` is a fallback to the host that just failed; its container logs show
it timing out every 30s refresh. Then recreate the container.

## Success criteria

1. Each of opencode, `claude-local`, `codex -p local`, and hermes edits a named
   scratch file through tool calls against the chosen coder model, with no
   malformed tool call.
2. The same works from isis over the tailnet:
   `curl -s --max-time 30 http://100.84.247.20:11434/v1/models` lists the coder
   model, and one `/v1/chat/completions` call returns 200.
3. `https://llm.thelunadog.com/health` reports `arch` non-zero, its
   `BACKENDS_JSON` entry is the tailnet IP, and `arch-vpn2` is gone.
4. Eviction is bounded, not absent: during a coding session,
   `journalctl -u ollama` shows a model load only after a regular-agent request,
   and the reload completes in under 30s. `ollama ps` shows the coder model
   resident otherwise.
5. `systemctl show ollama -p Environment` contains the new variables and
   `systemctl is-enabled ollama` is `enabled`. After the next reboot,
   `tailscale debug prefs` still shows `RouteAll: false`.
6. The gate is live and correct: `nft list table inet ollama_gate` shows the
   rules, LAN/tailnet/loopback and the docker bridges reach 11434, and IPv6,
   Tailscale direct UDP and SSH are unaffected. Docker bridges are allowed by
   decision (2026-09-18): `open-webui` and `myproject-myagent` reach Ollama via
   `host.docker.internal`, and repointing them was rejected as more invasive
   than trusting local containers.
7. A cloud model answers through the local server:
   `ollama run glm-5.3-flash:cloud` returns text, and the same model works from
   isis via the tailnet endpoint.

## Open items

- `/think` handling: `qwen3-coder:30b` advertises only `completion, tools`, so
  the appended `/think` seen in probes matters only for models that advertise
  `thinking` (e.g. `qwen3.6:27b`). Scope any fix to those.
- Docs to update in `~/.config` per the repo's own rule: README, ARCHITECTURE,
  ROADMAP, HOWTO.
