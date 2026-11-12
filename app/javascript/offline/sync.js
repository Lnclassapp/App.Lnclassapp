// ⚡ FRONT · offline/sync — envoie la file des copies rendues hors ligne au serveur, par 20, et tient leurs statuts à jour
// Rôle : n'envoie que la file de la clé de la page courante ; aucune note locale n'part ; paused et locked restent en attente ; une copie de plus de 30 jours est refusée « expired » et dite
// ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.5, menace P4, R1, R7) · UDR : hors-connexion §3.6
import { currentKey, listCopies, updateCopy } from "./store.js"

export const BATCH_SIZE = 20
export const MAX_AGE_MS = 30 * 24 * 3600 * 1000
export const ENDPOINT = "/offline_copies"
export const QUEUE_EVENT = "lnclass:offline-queue"
export const SENDING_EVENT = "lnclass:offline-sending"
// Le serveur garde ces copies : elles repartent au prochain envoi (l'abonnement, la pause passeront).
const KEEP_PENDING = [ "paused", "locked" ]
// Seuls ces champs partent : la note locale, le statut et le motif ne sont jamais envoyés (menace R1).
const SENT_FIELDS = [ "client_copy_id", "exercise_public_id", "pack_token", "started_at", "submitted_at", "answers" ]

let inFlight = null

const csrfToken = () => globalThis.document?.querySelector('meta[name="csrf-token"]')?.content || null

const tell = (summary, name = QUEUE_EVENT) => {
  if (typeof globalThis.dispatchEvent === "function" && typeof CustomEvent === "function") globalThis.dispatchEvent(new CustomEvent(name, { detail: summary }))
}

// Envoie la file de la clé courante. → { synced, rejected, pending, expired, error } (error : null, ou le premier échec : network,
// no_csrf, unreadable, http_<statut>). Deux appels en même temps partagent le même envoi.
export function flush(options = {}) {
  if (inFlight) return inFlight

  inFlight = run(options).finally(() => { inFlight = null })
  return inFlight
}

async function run({ key = currentKey(), fetchImpl = globalThis.fetch?.bind(globalThis), now = () => Date.now() } = {}) {
  const summary = { synced: 0, rejected: 0, pending: 0, expired: 0, error: null }
  if (!key || !fetchImpl) return summary

  const queue = await listCopies(key, { status: "pending" })
  summary.expired = await expire(key, queue, now())
  const waiting = queue.filter((copy) => !isExpired(copy, now()))
  summary.pending = waiting.length
  if (navigator.onLine === false || waiting.length === 0) return finish(summary)

  const token = csrfToken()
  if (!token) return finish({ ...summary, error: "no_csrf" })

  tell(summary, SENDING_EVENT)
  for (let from = 0; from < waiting.length; from += BATCH_SIZE) {
    const failure = await sendBatch(key, waiting.slice(from, from + BATCH_SIZE), { fetchImpl, token, summary })
    if (failure) { summary.error = failure; break }
  }
  return finish(summary)
}

const isExpired = (copy, at) => at - Date.parse(copy.submitted_at) > MAX_AGE_MS

// Le serveur refuserait le jeton (30 jours) : la copie passe « expired » et reste montrée à l'élève, jamais effacée en silence.
async function expire(key, queue, at) {
  const old = queue.filter((copy) => isExpired(copy, at))
  for (const copy of old) await updateCopy(key, copy.client_copy_id, { status: "rejected", reason: "expired" })
  return old.length
}

function finish(summary) {
  tell(summary)
  return summary
}

// → null, ou le motif de l'échec (la file reste telle quelle).
async function sendBatch(key, batch, { fetchImpl, token, summary }) {
  let response
  try {
    response = await fetchImpl(ENDPOINT, {
      method: "POST", credentials: "same-origin",
      headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": token },
      body: JSON.stringify({ copies: batch.map((copy) => Object.fromEntries(SENT_FIELDS.map((field) => [ field, copy[field] ]))) })
    })
  } catch {
    return "network"
  }
  if (!response.ok) return `http_${response.status}`

  let results
  try { results = (await response.json()).results } catch { return "unreadable" }
  if (!Array.isArray(results)) return "unreadable"

  const sent = new Set(batch.map((copy) => copy.client_copy_id))
  for (const result of results) await apply(key, result, summary, sent)
  return null
}

async function apply(key, result, summary, sent) {
  const id = result?.client_copy_id
  if (!sent.has(id)) return

  if (result.status === "synced" || result.status === "already_synced") {
    await updateCopy(key, id, { status: "synced", server_percent: result.percent, result_url: result.url, reason: null })
    summary.synced += 1
    summary.pending -= 1
  } else if (result.status === "rejected" && !KEEP_PENDING.includes(result.reason)) {
    await updateCopy(key, id, { status: "rejected", reason: result.reason })
    summary.rejected += 1
    summary.pending -= 1
  } else if (result.status === "rejected") {
    await updateCopy(key, id, { reason: result.reason })
  }
}
