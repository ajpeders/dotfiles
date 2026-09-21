// Model fallback for the frontier chain. When the current model errors, or is
// stuck in rate-limit retries, abort, revert the turn, and replay the user's
// message on the next model in CHAIN. Every new message starts again at the top
// of the chain (the TUI's selected model), so GPT is always tried first.
// opencode has no native fallback yet: https://github.com/anomalyco/opencode/issues/7602
//
// OPENCODE_FALLBACK_CHAIN="provider/model,provider/model,..." overrides CHAIN (for testing).

const CHAIN = (process.env.OPENCODE_FALLBACK_CHAIN?.split(",") ?? [
  "openai/gpt-5.5",
  "minimax-coding-plan/MiniMax-M3",
  "deepseek/deepseek-v4-pro",
]).map((s) => s.trim())

const RETRY_ATTEMPTS_BEFORE_FALLBACK = 2 // let opencode retry once for transient blips
const IGNORED_ERRORS = new Set(["MessageAbortedError", "MessageOutputLengthError"])

const split = (s) => {
  const i = s.indexOf("/")
  return { providerID: s.slice(0, i), modelID: s.slice(i + 1) }
}

// Rebuild prompt inputs from the stored user message. Synthetic parts (file
// contents opencode inlined) are regenerated from the file parts on replay.
const toInput = (p) => {
  if (p.type === "text" && !p.synthetic) return { type: "text", text: p.text }
  if (p.type === "file") return { type: "file", mime: p.mime, url: p.url, filename: p.filename }
  if (p.type === "agent") return { type: "agent", name: p.name }
  return null
}

export const ModelFallback = async ({ client }) => {
  const inFlight = new Set() // sessions mid-fallback; our own abort must not cascade

  const log = (level, message) =>
    client.app.log({ body: { service: "model-fallback", level, message } }).catch(() => {})

  async function fallback(sessionID, reason) {
    if (inFlight.has(sessionID)) return
    inFlight.add(sessionID)
    try {
      const { data: msgs } = await client.session.messages({ path: { id: sessionID } })
      if (!msgs?.length) return
      const lastUser = msgs.findLast((m) => m.info.role === "user")
      const lastAsst = msgs.findLast((m) => m.info.role === "assistant")
      if (!lastUser) return

      const failed = lastAsst
        ? `${lastAsst.info.providerID}/${lastAsst.info.modelID}`
        : `${lastUser.info.model.providerID}/${lastUser.info.model.modelID}`
      const i = CHAIN.indexOf(failed)
      if (i === -1) return // not a chain model (e.g. local subagents): leave alone
      if (i === CHAIN.length - 1) {
        log("warn", `${failed} failed (${reason}); no fallbacks left`)
        return
      }
      const next = CHAIN[i + 1]
      const parts = lastUser.parts.map(toInput).filter(Boolean)
      if (!parts.length) return

      log("warn", `${failed} failed (${reason}); replaying on ${next}`)
      client.tui
        .showToast({ body: { title: "Model fallback", message: `${failed} → ${next}`, variant: "warning" } })
        .catch(() => {})

      await client.session.abort({ path: { id: sessionID } })
      await client.session.revert({ path: { id: sessionID }, body: { messageID: lastUser.info.id } })
      await client.session.promptAsync({
        path: { id: sessionID },
        body: { agent: lastUser.info.agent, model: split(next), parts },
      })
    } catch (e) {
      log("error", `fallback failed: ${e?.message ?? e}`)
    } finally {
      inFlight.delete(sessionID)
    }
  }

  return {
    event: async ({ event }) => {
      const p = event.properties
      if (event.type === "session.status" && p.status.type === "retry" && p.status.attempt >= RETRY_ATTEMPTS_BEFORE_FALLBACK) {
        await fallback(p.sessionID, `retry ${p.status.attempt}: ${p.status.message}`)
      } else if (event.type === "session.error" && p.sessionID && p.error && !IGNORED_ERRORS.has(p.error.name)) {
        await fallback(p.sessionID, `${p.error.name}: ${p.error.data?.message ?? ""}`)
      }
    },
  }
}
