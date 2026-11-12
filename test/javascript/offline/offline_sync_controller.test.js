// hors-connexion, Lot C (ADR §4.5) : la page envoie la file à l'ouverture, au retour du réseau et avant la déconnexion (registerBeforePurge).
// Lancer : node --test test/javascript/offline/offline_sync_controller.test.js
import { test, beforeEach } from "node:test"
import assert from "node:assert/strict"
import { createFakeIndexedDB } from "./fake_indexeddb.js"
import * as store from "../../../app/javascript/offline/store.js"
import OfflineSyncController from "../../../app/javascript/controllers/offline_sync_controller.js"

const KEY = "0123456789abcdef"
let listeners, sent

beforeEach(() => {
  globalThis.indexedDB = createFakeIndexedDB()
  listeners = {}
  sent = 0
  globalThis.window = { addEventListener: (name, fn) => { listeners[name] = fn }, removeEventListener: (name) => { delete listeners[name] } }
  globalThis.document = { querySelector: (s) => (s.includes("csrf") ? { content: "t" } : { content: KEY }) }
  Object.defineProperty(globalThis, "navigator", { value: { onLine: true }, configurable: true })
  globalThis.fetch = async (url, options) => {
    sent += JSON.parse(options.body).copies.length
    return { ok: true, status: 200, json: async () => ({ results: JSON.parse(options.body).copies.map((c) => ({ client_copy_id: c.client_copy_id, status: "synced", percent: 10, url: "/r" })) }) }
  }
})

const copy = (id) => ({ client_copy_id: id, exercise_public_id: "ex1", pack_token: "t", started_at: "2026-11-12T10:00:00Z", submitted_at: new Date().toISOString(), answers: {} })
const settle = () => new Promise((resolve) => setTimeout(resolve, 20))

test("à l'ouverture de la page en ligne, la file part", async () => {
  await store.putCopy(KEY, copy("a"))
  const controller = Object.create(OfflineSyncController.prototype)
  controller.connect()
  await settle()

  assert.equal(sent, 1)
  controller.disconnect()
})

test("au retour du réseau, la file part", async () => {
  const controller = Object.create(OfflineSyncController.prototype)
  controller.connect()
  await settle()
  await store.putCopy(KEY, copy("b"))
  listeners.online()
  await settle()

  assert.equal(sent, 1)
  controller.disconnect()
})

test("avant la purge (déconnexion), la file est envoyée ; après disconnect elle ne l'est plus", async () => {
  const controller = Object.create(OfflineSyncController.prototype)
  controller.connect()
  await settle()
  await store.putCopy(KEY, copy("c"))
  await store.runBeforePurge()
  assert.equal(sent, 1)

  controller.disconnect()
  assert.deepEqual(Object.keys(listeners), [])
  await store.putCopy(KEY, copy("d"))
  await store.runBeforePurge()
  assert.equal(sent, 1)
})

test("un échec d'envoi est dit dans la console, pas avalé", async () => {
  const errors = []
  const original = console.error
  console.error = (...args) => errors.push(args)
  globalThis.indexedDB = { open: () => { throw new Error("IndexedDB cassé") } }
  const controller = Object.create(OfflineSyncController.prototype)
  controller.connect()
  await settle()
  console.error = original

  assert.equal(errors.length, 1)
  controller.disconnect()
})
