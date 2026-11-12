// ⚡ FRONT · offline/sync — envoie la file des copies rendues hors ligne au serveur, par 20, et tient leurs statuts à jour
// Rôle : n'envoie que la file de la clé de la page courante ; aucune note locale n'part ; paused et locked restent en attente ; le serveur décide seul de l'expiration (30 jours, motif expired) : toute copie en attente part ; un échec d'envoi (réseau, HTTP, session perdue) est dit dans le résumé
// ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.5, menace P4, R1, R7) · UDR : hors-connexion §3.6
import { currentKey, listCopies, updateCopy } from "./store.js"

export const BATCH_SIZE = 20
export const ENDPOINT = "/offline_copies"
export const QUEUE_EVENT = "lnclass:offline-queue"
export const SENDING_EVENT = "lnclass:offline-sending"
// Le serveur garde ces copies : elles repartent au prochain envoi (l'abonnement, la pause passeront).
const KEEP_PENDING = [ "paused", "locked", "error" ]
// Seuls ces champs partent : la note locale, le statut et le motif ne sont jamais envoyés (menace R1).
const SENT_FIELDS = [ "client_copy_id", "exercise_public_id", "pack_token", "started_at", "submitted_at", "answers" ]

let inFlight = null

const csrfToken = () => globalThis.document?.querySelector('meta[name="csrf-token"]')?.content || null

const tell = (summary, name = QUEUE_EVENT) => {
  if (typeof globalThis.dispatchEvent === "function" && typeof CustomEvent === "function") globalThis.dispatchEvent(new CustomEvent(name, { detail: summary }))
}

// Envoie la file de la clé courante. → { synced, rejected, pending, expired, error } (error : null, ou le premier échec : network,
// no_csrf, auth, unreadable, store, http_<statut>). Deux appels en même temps partagent le même envoi.
export function flush(options = {}) {
  if (inFlight) return inFlight

  inFlight = run(options).finally(() => { inFlight = null })
  return inFlight
}

async function run({ key = currentKey(), fetchImpl = globalThis.fetch?.bind(globalThis) } = {}) {
  const summary = { synced: 0, rejected: 0, pending: 0, expired: 0, error: null }
  if (!key || !fetchImpl) return summary

  // Quoi qu'il arrive (échec d'IndexedDB compris), la page est prévenue : « Envoi… » ne reste jamais affiché.
  try {
    const waiting = await listCopies(key, { status: "pending" })
    summary.pending = waiting.length
    if (navigator.onLine === false || waiting.length === 0) return summary

    const token = csrfToken()
    if (!token) return Object.assign(summary, { error: "no_csrf" })

    tell(summary, SENDING_EVENT)
    for (let from = 0; from < waiting.length; from += BATCH_SIZE) {
      const failure = await sendBatch(key, waiting.slice(from, from + BATCH_SIZE), { fetchImpl, token, summary })
      if (failure) { summary.error = failure; break }
    }
    return summary
  } finally {
    tell(summary)
  }
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
  // Une session perdue : la redirection vers la connexion (ou sa page HTML) répond 200 à fetch ; ce n'est pas une réponse du serveur de copies.
  if (response.redirected || response.headers?.get?.("content-type")?.includes("text/html")) return "auth"
  if (!response.ok) return `http_${response.status}`

  let results
  try { results = (await response.json()).results } catch { return "unreadable" }
  if (!Array.isArray(results)) return "unreadable"

  const sent = new Set(batch.map((copy) => copy.client_copy_id))
  for (const result of results) {
    try { await apply(key, result, summary, sent) } catch (error) { console.error("Copie hors ligne : statut non mis à jour", error); summary.error ||= "store" }
  }
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
    if (result.reason === "expired") summary.expired += 1
  } else if (result.status === "rejected") {
    await updateCopy(key, id, { reason: result.reason })
  }
}
