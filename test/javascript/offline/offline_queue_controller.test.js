// hors-connexion, Lot C (UDR §3.6, CA-15) : « N copies à envoyer », « Envoi… », copie refusée avec « J'ai compris », « Copie envoyée · N % » une fois.
// Lancer : node --test test/javascript/offline/offline_queue_controller.test.js (Stimulus, DOM, IndexedDB et window simulés).
import { test, beforeEach } from "node:test"
import assert from "node:assert/strict"
import { createFakeIndexedDB } from "./fake_indexeddb.js"
import * as store from "../../../app/javascript/offline/store.js"
import OfflineQueueController from "../../../app/javascript/controllers/offline_queue_controller.js"

const KEY = "0123456789abcdef"
let listeners

beforeEach(() => {
  globalThis.indexedDB = createFakeIndexedDB()
  listeners = {}
  globalThis.window = { addEventListener: (name, fn) => { listeners[name] = fn }, removeEventListener: (name) => { delete listeners[name] } }
  globalThis.document = { querySelector: () => ({ content: KEY }), createElement: () => fakeNode() }
})

function fakeNode() {
  const node = { hidden: false, textContent: "", children: [], dataset: {}, listeners: {}, nodes: {} }
  node.append = (...items) => node.children.push(...items)
  node.replaceChildren = (...items) => { node.children = items }
  node.querySelector = (selector) => (node.nodes[selector] ||= fakeNode())
  node.cloneNode = () => { const copy = fakeNode(); copy.nodes = {}; return copy }
  return node
}

function build() {
  const controller = Object.create(OfflineQueueController.prototype)
  const targets = { error: fakeNode(), pending: fakeNode(), pendingText: fakeNode(), synced: fakeNode(), rejected: fakeNode(), rejectedRow: { content: { firstElementChild: fakeNode() } } }
  const values = {
    pendingOne: "1 copie à envoyer", pendingOther: "%{count} copies à envoyer", sending: "Envoi…", failed: "Envoi impossible, nouvel essai plus tard.", synced: "Copie envoyée · %{percent} %",
    rejected: { stale: "Exercice modifié depuis : copie non comptée.", invalid: "Copie refusée par le serveur." }
  }
  for (const [name, value] of Object.entries(values)) Object.defineProperty(controller, `${name}Value`, { value })
  for (const [name, value] of Object.entries(targets)) {
    Object.defineProperty(controller, `${name}Target`, { value })
    Object.defineProperty(controller, `has${name[0].toUpperCase()}${name.slice(1)}Target`, { value: true })
  }
  Object.defineProperty(controller, "element", { value: { hidden: true } })
  controller.sent = []
  controller.sending = false
  return { controller, targets }
}

const copy = (id, extra = {}) => ({ client_copy_id: id, exercise_public_id: "ex1", pack_token: "t", started_at: "2026-11-12T10:00:00Z",
  submitted_at: "2026-11-12T10:10:00Z", answers: {}, ...extra })

test("rien en file : tout reste caché", async () => {
  const { controller } = build()
  await controller.refresh()

  assert.equal(controller.element.hidden, true)
})

test("CA-15 : 2 copies en file : « 2 copies à envoyer » ; 1 seule : « 1 copie à envoyer »", async () => {
  await store.putCopy(KEY, copy("a"))
  const { controller, targets } = build()
  await controller.refresh()
  assert.equal(targets.pendingText.textContent, "1 copie à envoyer")

  await store.putCopy(KEY, copy("b"))
  await controller.refresh()
  assert.equal(controller.element.hidden, false)
  assert.equal(targets.pending.hidden, false)
  assert.equal(targets.pendingText.textContent, "2 copies à envoyer")
})

test("pendant l'envoi : « Envoi… » ; l'envoi fini, le compte revient", async () => {
  await store.putCopy(KEY, copy("a"))
  const { controller, targets } = build()
  controller.connect()
  await listeners["lnclass:offline-sending"]()
  assert.equal(targets.pendingText.textContent, "Envoi…")

  await listeners["lnclass:offline-queue"]()
  assert.equal(targets.pendingText.textContent, "1 copie à envoyer")
})

test("CA-15 : une copie envoyée dit « Copie envoyée · N % » une fois, puis disparaît de la file au chargement suivant", async () => {
  await store.putCopy(KEY, copy("a", { status: "synced", server_percent: 75, result_url: "/r" }))
  const { controller, targets } = build()
  await controller.refresh()

  assert.equal(targets.synced.children.length, 1)
  assert.equal(targets.synced.children[0].textContent, "Copie envoyée · 75 %")
  assert.equal(targets.pending.hidden, true)
  assert.deepEqual(await store.listCopies(KEY), [])

  await controller.refresh()
  assert.equal(targets.synced.children.length, 1)

  const { controller: next, targets: nextTargets } = build()
  await next.refresh()
  assert.equal(nextTargets.synced.children.length, 0)
  assert.equal(next.element.hidden, true)
})

test("une copie refusée : le motif, « J'ai compris » la retire", async () => {
  await store.putCopy(KEY, copy("a", { status: "rejected", reason: "stale" }))
  await store.putCopy(KEY, copy("b", { status: "rejected", reason: "inconnu" }))
  const { controller, targets } = build()
  await controller.refresh()

  assert.equal(targets.rejected.children.length, 2)
  const [ first, second ] = targets.rejected.children
  assert.equal(first.querySelector("[data-role='reason']").textContent, "Exercice modifié depuis : copie non comptée.")
  assert.equal(second.querySelector("[data-role='reason']").textContent, "Copie refusée par le serveur.")

  await first.querySelector("button").onclick()
  assert.deepEqual((await store.listCopies(KEY)).map((c) => c.client_copy_id), [ "b" ])
  assert.equal(targets.rejected.children.length, 1)
})

test("le titre de l'exercice vient du paquet gardé quand il en a un", async () => {
  await store.putPack(KEY, { exercise_public_id: "ex1", token: "t", title: "La méiose" })
  await store.putCopy(KEY, copy("a", { status: "rejected", reason: "stale" }))
  const { controller, targets } = build()
  await controller.refresh()

  assert.equal(targets.rejected.children[0].querySelector("[data-role='title']").textContent, "La méiose")
})

test("sans clé de page : caché, rien n'est lu", async () => {
  globalThis.document = { querySelector: () => null }
  const { controller } = build()
  await controller.refresh()

  assert.equal(controller.element.hidden, true)
})

test("disconnect retire les écouteurs", () => {
  const { controller } = build()
  controller.connect()
  controller.disconnect()

  assert.deepEqual(Object.keys(listeners), [])
})

test("F1 : un envoi en échec dit « Envoi impossible, nouvel essai plus tard. » tant que des copies attendent", async () => {
  await store.putCopy(KEY, copy("a"))
  const { controller, targets } = build()
  controller.connect()
  await listeners["lnclass:offline-queue"]({ detail: { error: "http_500" } })

  assert.equal(targets.error.hidden, false)
  assert.equal(targets.error.textContent, "Envoi impossible, nouvel essai plus tard.")

  await listeners["lnclass:offline-sending"]()
  assert.equal(targets.error.hidden, true)
  await listeners["lnclass:offline-queue"]({ detail: { error: null } })
  assert.equal(targets.error.hidden, true)
})

test("F6 : un rafraîchissement non attendu qui échoue est écrit en console, pas perdu", async () => {
  const errors = []
  const original = console.error
  console.error = (...args) => errors.push(args)
  const { controller } = build()
  controller.refresh = async () => { throw new Error("boum") }
  await controller.safeRefresh()
  console.error = original

  assert.equal(errors.length, 1)
})
