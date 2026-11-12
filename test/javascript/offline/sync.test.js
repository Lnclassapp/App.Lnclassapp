// hors-connexion, Lot C (ADR §4.5, menace P4, R1, R7, CA-15) : l'envoi de la file. Lancer : node --test test/javascript/offline/sync.test.js
// IndexedDB, document, fetch et événements simulés ; aucune note locale n'est jamais envoyée.
import { test, beforeEach } from "node:test"
import assert from "node:assert/strict"
import { createFakeIndexedDB } from "./fake_indexeddb.js"
import * as store from "../../../app/javascript/offline/store.js"
import { flush, BATCH_SIZE } from "../../../app/javascript/offline/sync.js"

const KEY = "0123456789abcdef"
const OTHER = "fedcba9876543210"
const NOW = Date.parse("2026-11-12T12:00:00Z")
const DAY = 86_400_000

let requests, answer, events

beforeEach(() => {
  globalThis.indexedDB = createFakeIndexedDB()
  globalThis.metaKey = KEY
  globalThis.document = { querySelector: (selector) => {
    if (selector === 'meta[name="lnclass-offline-key"]') return { content: globalThis.metaKey }
    if (selector === 'meta[name="csrf-token"]') return globalThis.csrf === null ? null : { content: "jeton-csrf" }
    return null
  } }
  globalThis.csrf = "jeton-csrf"
  Object.defineProperty(globalThis, "navigator", { value: { onLine: true }, configurable: true })
  events = []
  globalThis.dispatchEvent = (event) => events.push(event)
  requests = []
  answer = (copies) => ({ results: copies.map((copy) => ({ client_copy_id: copy.client_copy_id, status: "synced", percent: 50, url: `/sessions/${copy.client_copy_id}/result` })) })
})

const fetchImpl = async (url, options) => {
  const body = JSON.parse(options.body)
  requests.push({ url, options, body })
  const payload = typeof answer === "function" ? answer(body.copies) : answer
  return { ok: true, status: 200, json: async () => payload }
}

const copy = (id, extra = {}) => ({ client_copy_id: id, exercise_public_id: "ex1", pack_token: "tok", started_at: "2026-11-12T10:00:00Z",
  submitted_at: "2026-11-12T10:10:00Z", answers: { 1: { answer_ids: [ 3 ] } }, provisional_percent: 100, ...extra })
const run = (options = {}) => flush({ fetchImpl, now: () => NOW, ...options })

test("CA-15 : la file part avec le jeton CSRF de la page, sans la note locale ni le statut", async () => {
  await store.putCopy(KEY, copy("a"))
  await run()

  assert.equal(requests.length, 1)
  assert.equal(requests[0].url, "/offline_copies")
  assert.equal(requests[0].options.method, "POST")
  assert.equal(requests[0].options.headers["X-CSRF-Token"], "jeton-csrf")
  assert.equal(requests[0].options.headers["Content-Type"], "application/json")
  assert.equal(requests[0].options.credentials, "same-origin")
  assert.deepEqual(Object.keys(requests[0].body.copies[0]).sort(),
    [ "answers", "client_copy_id", "exercise_public_id", "pack_token", "started_at", "submitted_at" ])
})

test("synced : la copie passe à synced avec la note du serveur et le lien du résultat", async () => {
  await store.putCopy(KEY, copy("a"))
  const summary = await run()

  const [ saved ] = await store.listCopies(KEY)
  assert.equal(saved.status, "synced")
  assert.equal(saved.server_percent, 50)
  assert.equal(saved.result_url, "/sessions/a/result")
  assert.deepEqual([ summary.synced, summary.pending ], [ 1, 0 ])
})

test("already_synced compte comme envoyée", async () => {
  await store.putCopy(KEY, copy("a"))
  answer = (copies) => ({ results: copies.map((c) => ({ client_copy_id: c.client_copy_id, status: "already_synced", percent: 80, url: "/r" })) })
  await run()

  assert.deepEqual((await store.listCopies(KEY)).map((c) => [ c.status, c.server_percent ]), [ [ "synced", 80 ] ])
})

test("P4 : les copies d'une autre clé ne sont jamais envoyées", async () => {
  await store.putCopy(KEY, copy("mine"))
  await store.putCopy(OTHER, copy("theirs"))
  await run()

  assert.deepEqual(requests.flatMap((r) => r.body.copies.map((c) => c.client_copy_id)), [ "mine" ])
  assert.equal((await store.listCopies(OTHER))[0].status, "pending")
})

test("sans clé de page (déconnecté) : rien n'est envoyé", async () => {
  globalThis.metaKey = null
  await store.putCopy(KEY, copy("a"))
  await run()

  assert.equal(requests.length, 0)
})

test("par 20 au plus", async () => {
  assert.equal(BATCH_SIZE, 20)
  for (let i = 0; i < 45; i++) await store.putCopy(KEY, copy(`c${String(i).padStart(2, "0")}`, { submitted_at: `2026-11-12T10:${String(i).padStart(2, "0")}:00Z` }))
  await run()

  assert.deepEqual(requests.map((r) => r.body.copies.length), [ 20, 20, 5 ])
})

test("rejected : stale, forbidden, invalid, wrong_owner sont gardées avec leur motif ; paused et locked restent en attente", async () => {
  for (const id of [ "s", "f", "p", "l" ]) await store.putCopy(KEY, copy(id))
  const reasons = { s: "stale", f: "forbidden", p: "paused", l: "locked" }
  answer = (copies) => ({ results: copies.map((c) => ({ client_copy_id: c.client_copy_id, status: "rejected", reason: reasons[c.client_copy_id] })) })
  const summary = await run()

  const byId = Object.fromEntries((await store.listCopies(KEY)).map((c) => [ c.client_copy_id, [ c.status, c.reason ] ]))
  assert.deepEqual(byId, { s: [ "rejected", "stale" ], f: [ "rejected", "forbidden" ], p: [ "pending", "paused" ], l: [ "pending", "locked" ] })
  assert.deepEqual([ summary.rejected, summary.pending ], [ 2, 2 ])
})

test("hors ligne : rien n'est tenté, la file reste", async () => {
  navigator.onLine = false
  await store.putCopy(KEY, copy("a"))
  await run()

  assert.equal(requests.length, 0)
  assert.equal((await store.listCopies(KEY))[0].status, "pending")
})

test("réseau qui coupe pendant l'envoi : la copie reste en attente, l'erreur n'est pas avalée dans le résumé", async () => {
  await store.putCopy(KEY, copy("a"))
  const summary = await flush({ fetchImpl: async () => { throw new TypeError("Failed to fetch") }, now: () => NOW })

  assert.equal((await store.listCopies(KEY))[0].status, "pending")
  assert.equal(summary.error, "network")
})

test("réponse en erreur (413, 422, 429, redirection vers la connexion) : la file reste, l'erreur est dite", async () => {
  await store.putCopy(KEY, copy("a"))
  for (const status of [ 413, 422, 429, 500 ]) {
    const summary = await flush({ fetchImpl: async () => ({ ok: false, status, json: async () => ({}) }), now: () => NOW })
    assert.equal(summary.error, `http_${status}`)
  }
  assert.equal((await store.listCopies(KEY))[0].status, "pending")
})

test("une réponse illisible laisse la file en attente", async () => {
  await store.putCopy(KEY, copy("a"))
  const summary = await flush({ fetchImpl: async () => ({ ok: true, status: 200, json: async () => { throw new SyntaxError("x") } }), now: () => NOW })

  assert.equal(summary.error, "unreadable")
  assert.equal((await store.listCopies(KEY))[0].status, "pending")
})

test("une copie absente de la réponse reste en attente", async () => {
  await store.putCopy(KEY, copy("a"))
  answer = { results: [] }
  await run()

  assert.equal((await store.listCopies(KEY))[0].status, "pending")
})

test("sans jeton CSRF dans la page : rien n'est envoyé", async () => {
  globalThis.csrf = null
  await store.putCopy(KEY, copy("a"))
  const summary = await run()

  assert.equal(requests.length, 0)
  assert.equal(summary.error, "no_csrf")
})

test("F4 : l'horloge de l'appareil n'empêche jamais l'envoi : une copie « de plus de 30 jours » part, le serveur décide", async () => {
  await store.putCopy(KEY, copy("old", { submitted_at: new Date(NOW - 31 * DAY).toISOString() }))
  const summary = await run({ now: () => NOW + 400 * DAY })

  assert.deepEqual(requests.flatMap((r) => r.body.copies.map((c) => c.client_copy_id)), [ "old" ])
  assert.equal(summary.synced, 1)
})

test("F4 : un motif expired du serveur range la copie refusée et la compte", async () => {
  answer = (copies) => ({ results: copies.map((c) => ({ client_copy_id: c.client_copy_id, status: "rejected", reason: "expired" })) })
  await store.putCopy(KEY, copy("old"))
  const summary = await run()

  const [ stored ] = await store.listCopies(KEY)
  assert.deepEqual([ stored.status, stored.reason, summary.expired, summary.rejected ], [ "rejected", "expired", 1, 1 ])
})

test("F2 : un motif error du serveur laisse la copie en attente (retentée)", async () => {
  answer = (copies) => ({ results: copies.map((c) => ({ client_copy_id: c.client_copy_id, status: "rejected", reason: "error" })) })
  await store.putCopy(KEY, copy("a"))
  const summary = await run()

  assert.equal((await store.listCopies(KEY))[0].status, "pending")
  assert.equal(summary.pending, 1)
})

test("F1 : une réponse 500 est un échec visible (http_500), la copie reste en attente, la page est prévenue", async () => {
  await store.putCopy(KEY, copy("a"))
  const summary = await flush({ fetchImpl: async () => ({ ok: false, status: 500, json: async () => ({}) }) })

  assert.equal(summary.error, "http_500")
  assert.equal((await store.listCopies(KEY))[0].status, "pending")
  assert.equal(events.at(-1).detail.error, "http_500")
})

test("F1 : une réponse redirigée (session perdue, page de connexion) est le motif auth", async () => {
  await store.putCopy(KEY, copy("a"))
  const summary = await flush({ fetchImpl: async () => ({ ok: true, status: 200, redirected: true, json: async () => { throw new Error("html") } }) })

  assert.equal(summary.error, "auth")
  assert.equal((await store.listCopies(KEY))[0].status, "pending")
})

test("F1 : une réponse HTML est le motif auth", async () => {
  await store.putCopy(KEY, copy("a"))
  const summary = await flush({ fetchImpl: async () => ({ ok: true, status: 200, headers: { get: () => "text/html; charset=utf-8" }, json: async () => ({}) }) })

  assert.equal(summary.error, "auth")
})

test("F3 : une panne de la file locale n'empêche pas l'événement de fin (« Envoi… » ne reste pas affiché)", async () => {
  await store.putCopy(KEY, copy("a"))
  const original = globalThis.indexedDB
  const realFetch = fetchImpl
  const broken = async (url, options) => { globalThis.indexedDB = { open: () => { throw new Error("IndexedDB cassé") } }; return realFetch(url, options) }
  const quiet = console.error
  console.error = () => {}
  const summary = await flush({ fetchImpl: broken })
  console.error = quiet
  globalThis.indexedDB = original

  assert.equal(events.at(-1).type, "lnclass:offline-queue")
  assert.equal(summary.error, "store")
})

test("F3 : l'échec de mise à jour d'une copie n'arrête pas les suivantes", async () => {
  await store.putCopy(KEY, copy("a"))
  await store.putCopy(KEY, copy("b"))
  // La copie « a » disparaît pendant l'envoi : sa mise à jour échoue, celle de « b » doit passer.
  const vanishing = async (url, options) => { await store.deleteCopy(KEY, "a"); return fetchImpl(url, options) }
  const quiet = console.error
  console.error = () => {}
  const summary = await flush({ fetchImpl: vanishing })
  console.error = quiet

  assert.equal((await store.listCopies(KEY)).find((c) => c.client_copy_id === "b").status, "synced")
  assert.equal(summary.error, "store")
})

test("un événement dit à la page que la file a changé", async () => {
  await store.putCopy(KEY, copy("a"))
  await run()

  assert.ok(events.some((event) => event.type === "lnclass:offline-queue"))
})

test("deux déclenchements en même temps n'envoient la copie qu'une fois", async () => {
  await store.putCopy(KEY, copy("a"))
  await Promise.all([ run(), run() ])

  assert.equal(requests.length, 1)
})

test("un événement dit que l'envoi commence, avant le premier envoi", async () => {
  await store.putCopy(KEY, copy("a"))
  await run()

  assert.deepEqual(events.map((event) => event.type), [ "lnclass:offline-sending", "lnclass:offline-queue" ])
})

test("une file vide ne fait aucune requête", async () => {
  await run()
  assert.equal(requests.length, 0)
})
