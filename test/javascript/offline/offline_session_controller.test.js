// hors-connexion, Lot A, CA-4 (ADR §4.2, menace P1, P2) : la clé part au programme d'arrière-plan, l'ancienne clé est purgée
// (file gardée), et la déconnexion joue runBeforePurge puis purgeKey avant de laisser partir la requête.
// Lancer : node --test test/javascript/offline/offline_session_controller.test.js (store.js réel sur IndexedDB, caches et DOM simulés).
import "./stimulus_base.js"
import { test, beforeEach } from "node:test"
import assert from "node:assert/strict"
import { createFakeIndexedDB } from "./fake_indexeddb.js"
import * as store from "../../../app/javascript/offline/store.js"
import OfflineSessionController from "../../../app/javascript/offline/controllers/session_controller.js"

const KEY = "0123456789abcdef"
const OTHER = "fedcba9876543210"

let fake, deletedCaches, local, posted, listeners, errors, unregister

beforeEach(() => {
  fake = createFakeIndexedDB()
  deletedCaches = []
  posted = []
  listeners = {}
  errors = []
  local = new Map()
  unregister = []
  globalThis.indexedDB = fake
  globalThis.caches = { delete: async (name) => { deletedCaches.push(name); return true } }
  globalThis.localStorage = { getItem: (k) => local.get(k) ?? null, setItem: (k, v) => local.set(k, String(v)) }
  globalThis.metaKey = KEY
  globalThis.document = {
    querySelector: (selector) => (selector === 'meta[name="lnclass-offline-key"]' && globalThis.metaKey ? { content: globalThis.metaKey } : null),
    addEventListener: (name, fn) => { listeners[name] = fn },
    removeEventListener: (name) => { delete listeners[name] },
  }
  const worker = { postMessage: (message) => posted.push(message) }
  Object.defineProperty(globalThis, "navigator", {
    configurable: true,
    value: { serviceWorker: { ready: Promise.resolve({ active: worker }), controller: worker, addEventListener() {}, removeEventListener() {} } },
  })
  console.error = (...args) => errors.push(args)
})

const settle = () => new Promise((resolve) => setTimeout(resolve, 20))

function build() {
  const controller = Object.create(OfflineSessionController.prototype)
  Object.defineProperty(controller, "element", { value: {} })
  return controller
}

function logoutForm({ action = "https://lnclass.test/session", method = "delete" } = {}) {
  const form = {
    tagName: "FORM", action, method: "post", submitted: [],
    querySelector: (selector) => (selector === 'input[name="_method"]' ? { value: method } : null),
    requestSubmit(submitter) { this.submitted.push(submitter ?? true) },
    submit() { this.submitted.push("submit") },
  }
  return form
}

function submitEvent(form) {
  return { target: form, submitter: null, prevented: false, stopped: false, preventDefault() { this.prevented = true }, stopImmediatePropagation() { this.stopped = true } }
}

test("la clé de la page part au programme d'arrière-plan", async () => {
  build().connect()
  await settle()

  assert.deepEqual(posted, [ { type: "lnclass:key", key: KEY } ])
})

test("sans clé (page non connectée), rien n'est envoyé ni purgé", async () => {
  globalThis.metaKey = null
  build().connect()
  await settle()

  assert.deepEqual(posted, [])
  assert.deepEqual(deletedCaches, [])
})

test("un changement de clé purge l'ancienne (pages et paquets) et garde sa file en attente", async () => {
  await store.putPack(OTHER, { exercise_public_id: "ex1", token: "t" })
  await store.putCopy(OTHER, { client_copy_id: "c1", exercise_public_id: "ex1", submitted_at: "2026-11-12T10:00:00Z" })
  await store.putCopy(OTHER, { client_copy_id: "c2", exercise_public_id: "ex1", submitted_at: "2026-11-12T10:01:00Z", status: "rejected" })
  store.rememberKey(OTHER)

  build().connect()
  await settle()

  assert.deepEqual(deletedCaches, [ `lnclass-pages-${OTHER}` ])
  assert.equal(await store.getPack(OTHER, "ex1"), null)
  assert.deepEqual((await store.listCopies(OTHER)).map((copy) => copy.client_copy_id), [ "c1" ])
  assert.deepEqual(posted, [ { type: "lnclass:key", key: KEY } ])
  assert.equal(store.rememberKey(KEY), KEY)
})

test("la même clé ne purge rien", async () => {
  store.rememberKey(KEY)
  build().connect()
  await settle()

  assert.deepEqual(deletedCaches, [])
})

test("une purge de l'ancienne clé qui échoue est signalée et n'empêche pas d'envoyer la nouvelle clé", async () => {
  store.rememberKey(OTHER)
  globalThis.caches = { delete: async () => { throw new Error("boom") } }

  build().connect()
  await settle()

  assert.ok(errors.length >= 1)
  assert.deepEqual(posted, [ { type: "lnclass:key", key: KEY } ])
})

test("déconnexion : runBeforePurge, puis purgeKey, puis seulement la requête", async () => {
  const order = []
  const off = store.registerBeforePurge(async () => { order.push("before") })
  await store.putPack(KEY, { exercise_public_id: "ex1", token: "t" })
  globalThis.caches = { delete: async (name) => { order.push(`purge ${name}`); return true } }
  const controller = build()
  controller.connect()
  const form = logoutForm()
  const event = submitEvent(form)

  listeners.submit(event)
  assert.ok(event.prevented && event.stopped)
  assert.deepEqual(form.submitted, [])
  await settle()

  assert.deepEqual(order, [ "before", `purge lnclass-pages-${KEY}` ])
  assert.equal(form.submitted.length, 1)
  assert.equal(fake.databases.has(`lnclass-offline-${KEY}`), false)
  off()

  const again = submitEvent(form)
  listeners.submit(again)
  assert.equal(again.prevented, false, "le second envoi, libéré, part sans nouvelle purge")
})

test("déconnexion : une erreur de purge est signalée mais la déconnexion part", async () => {
  globalThis.caches = { delete: async () => { throw new Error("boom") } }
  build().connect()
  const form = logoutForm()

  listeners.submit(submitEvent(form))
  await settle()

  assert.ok(errors.length >= 1)
  assert.equal(form.submitted.length, 1)
})

test("déconnexion : le programme reçoit forget, même quand purgeKey échoue", async () => {
  globalThis.caches = { delete: async () => { throw new Error("boom") } }
  build().connect()
  const form = logoutForm()

  listeners.submit(submitEvent(form))
  await settle()

  assert.ok(posted.some((message) => message.type === "lnclass:forget" && message.key === KEY))
  assert.equal(form.submitted.length, 1)
})

test("déconnexion : forget part aussi quand la purge réussit", async () => {
  build().connect()
  listeners.submit(submitEvent(logoutForm()))
  await settle()

  assert.deepEqual(posted.filter((message) => message.type === "lnclass:forget"), [ { type: "lnclass:forget", key: KEY } ])
})

test("déconnexion : si l'envoi de la file échoue, la file est gardée (jamais de copie perdue) et la déconnexion part", async () => {
  await store.putCopy(KEY, { client_copy_id: "c1", exercise_public_id: "ex1", submitted_at: "2026-11-12T10:00:00Z" })
  const off = store.registerBeforePurge(async () => { throw new Error("hors ligne") })
  build().connect()
  const form = logoutForm()

  listeners.submit(submitEvent(form))
  await settle()
  off()

  assert.ok(errors.length >= 1)
  assert.deepEqual((await store.listCopies(KEY)).map((copy) => copy.client_copy_id), [ "c1" ])
  assert.equal(form.submitted.length, 1)
})

test("les autres formulaires ne sont pas touchés", async () => {
  build().connect()
  for (const form of [ logoutForm({ method: "post" }), logoutForm({ action: "https://lnclass.test/profile/pin" }) ]) {
    const event = submitEvent(form)
    listeners.submit(event)
    assert.equal(event.prevented, false)
  }
  assert.deepEqual(deletedCaches, [])
})

test("disconnect retire l'écouteur", async () => {
  const controller = build()
  controller.connect()
  controller.disconnect()

  assert.equal(listeners.submit, undefined)
})
