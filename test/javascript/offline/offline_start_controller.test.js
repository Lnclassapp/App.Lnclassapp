// hors-connexion Lot B (UDR §3.3, ADR §4.4) : « Commencer » range le paquet en ligne, mène à la copie hors ligne quand le paquet est là, sinon se désactive.
// Lancer : node --test test/javascript/offline/offline_start_controller.test.js (IndexedDB, fetch, DOM et Stimulus simulés).
import "./stimulus_base.js"
import { test, beforeEach } from "node:test"
import assert from "node:assert/strict"
import { createFakeIndexedDB } from "./fake_indexeddb.js"
import * as store from "../../../app/javascript/offline/store.js"
import OfflineStartController from "../../../app/javascript/offline/controllers/start_controller.js"

const KEY = "0123456789abcdef"
const PACK = { exercise_public_id: "EX1", token: "jeton", digest: "0123456789abcdef", issued_at: "2026-11-12T09:00:00Z", questions: [] }

let fake, controller, button, message, visits, fetched, listeners, packResponse

beforeEach(() => {
  fake = createFakeIndexedDB()
  globalThis.indexedDB = fake
  globalThis.document = { querySelector: () => ({ content: KEY }) }
  listeners = {}
  globalThis.window = { addEventListener: (name, fn) => { listeners[name] = fn }, removeEventListener: (name) => { delete listeners[name] }, location: { assign: (url) => visits.push(url) } }
  Object.defineProperty(globalThis, "navigator", { value: { onLine: true }, configurable: true })
  visits = []
  fetched = []
  packResponse = { ok: true, json: async () => PACK }
  globalThis.fetch = async (url, options) => { fetched.push({ url, options }); return url.includes("pack") ? packResponse : { ok: true } }
  globalThis.Turbo = { visit: (url) => visits.push(url) }
  button = { disabled: false, attrs: {}, setAttribute(name, value) { this.attrs[name] = value } }
  message = { hidden: true }
  controller = Object.create(OfflineStartController.prototype)
  Object.defineProperties(controller, {
    exerciseValue: { value: "EX1" }, packUrlValue: { value: "/exercises/EX1/offline_pack" }, copyUrlValue: { value: "/exercises/EX1/offline_copy" },
    buttonTarget: { value: button }, unavailableTarget: { value: message }
  })
})

const settle = () => new Promise((resolve) => setTimeout(resolve, 20))

test("en ligne : le paquet est rangé dans la base de la clé, puis la copie est demandée pour être gardée ; le bouton reste actif", async () => {
  controller.connect()
  await settle()

  assert.deepEqual((await store.getPack(KEY, "EX1")).token, "jeton")
  assert.deepEqual(fetched.map((call) => call.url), [ "/exercises/EX1/offline_copy", "/exercises/EX1/offline_pack" ])
  assert.equal(fetched[1].options.credentials, "same-origin")
  assert.equal(fetched[0].options.headers.Accept, "text/html")
  assert.equal(button.disabled, false)
  assert.equal(message.hidden, true)
})

test("en ligne, un refus du serveur (accès, limite) ne range rien et ne gêne pas le démarrage", async () => {
  packResponse = { ok: false, status: 429, json: async () => ({}) }
  const original = console.warn
  console.warn = () => {}
  try {
    controller.connect()
    await settle()
  } finally { console.warn = original }

  assert.equal(await store.getPack(KEY, "EX1"), null)
  assert.equal(button.disabled, false)
})

test("la page de la copie est demandée d'abord ; si elle ne répond pas ok, aucun paquet n'est rangé (console.warn), hors ligne le bouton est désactivé", async () => {
  globalThis.fetch = async (url, options) => { fetched.push({ url, options }); return url.includes("pack") ? { ok: true, json: async () => PACK } : { ok: false, status: 500 } }
  const warnings = []
  const original = console.warn
  console.warn = (...args) => warnings.push(args)
  try {
    controller.connect()
    await settle()
  } finally { console.warn = original }

  assert.equal(fetched[0].url, "/exercises/EX1/offline_copy")
  assert.equal(await store.getPack(KEY, "EX1"), null)
  assert.equal(warnings.length, 1)
  navigator.onLine = false
  await listeners.offline()
  assert.equal(button.disabled, true)
  assert.equal(message.hidden, false)
})

for (const status of [ 402, 403, 404 ]) {
  test(`refus ${status} du serveur : le paquet déjà rangé est supprimé, hors ligne le bouton est désactivé`, async () => {
    await store.putPack(KEY, PACK)
    packResponse = { ok: false, status, json: async () => ({}) }
    const original = console.warn
    console.warn = () => {}
    try {
      controller.connect()
      await settle()
    } finally { console.warn = original }

    assert.equal(await store.getPack(KEY, "EX1"), null)
    navigator.onLine = false
    await listeners.offline()
    assert.equal(button.disabled, true)
  })
}

test("429 ou 5xx : le paquet déjà rangé est gardé (console.warn)", async () => {
  await store.putPack(KEY, PACK)
  packResponse = { ok: false, status: 503, json: async () => ({}) }
  const warnings = []
  const original = console.warn
  console.warn = (...args) => warnings.push(args)
  try {
    controller.connect()
    await settle()
  } finally { console.warn = original }

  assert.equal((await store.getPack(KEY, "EX1")).token, "jeton")
  assert.equal(warnings.length, 1)
})

test("le clic attend la vérification en cours avant de décider", async () => {
  await store.putPack(KEY, PACK)
  navigator.onLine = false
  controller.connect()
  const going = controller.go({ preventDefault() {} })
  assert.deepEqual(visits, [])
  await going

  assert.deepEqual(visits, [ "/exercises/EX1/offline_copy" ])
})

test("en ligne, un réseau qui échoue ou un stockage plein est dit en console, jamais en exception", async () => {
  globalThis.fetch = async () => { throw new TypeError("réseau") }
  const warnings = []
  const original = console.warn
  console.warn = (...args) => warnings.push(args)
  try {
    controller.connect()
    await settle()
  } finally { console.warn = original }

  assert.equal(warnings.length, 1)
  assert.equal(button.disabled, false)
})

test("hors ligne, paquet rangé : le bouton reste actif et le clic mène à la copie hors ligne", async () => {
  await store.putPack(KEY, PACK)
  navigator.onLine = false
  controller.connect()
  await settle()
  let prevented = false
  await controller.go({ preventDefault: () => { prevented = true } })

  assert.equal(button.disabled, false)
  assert.equal(message.hidden, true)
  assert.equal(prevented, true)
  assert.deepEqual(visits, [ "/exercises/EX1/offline_copy" ])
  assert.deepEqual(fetched, [])
})

test("hors ligne, paquet absent : bouton désactivé (aria-disabled) et message visible ; rien ne part", async () => {
  navigator.onLine = false
  controller.connect()
  await settle()
  let prevented = false
  await controller.go({ preventDefault: () => { prevented = true } })

  assert.equal(button.disabled, true)
  assert.equal(button.attrs["aria-disabled"], "true")
  assert.equal(message.hidden, false)
  assert.equal(prevented, true)
  assert.deepEqual(visits, [])
})

test("hors ligne, base illisible : traité comme paquet absent", async () => {
  fake.failOpen = new Error("refusé")
  navigator.onLine = false
  const original = console.warn
  console.warn = () => {}
  try {
    controller.connect()
    await settle()
  } finally { console.warn = original }

  assert.equal(button.disabled, true)
})

test("en ligne, le clic n'est pas intercepté : le formulaire part au serveur", () => {
  let prevented = false
  controller.go({ preventDefault: () => { prevented = true } })

  assert.equal(prevented, false)
  assert.deepEqual(visits, [])
})

test("sans Turbo, la copie s'ouvre par une navigation ordinaire", async () => {
  delete globalThis.Turbo
  await store.putPack(KEY, PACK)
  navigator.onLine = false
  controller.connect()
  await settle()
  await controller.go({ preventDefault() {} })

  assert.deepEqual(visits, [ "/exercises/EX1/offline_copy" ])
})

test("le retour du réseau réactive le bouton et range le paquet ; la perte du réseau le désactive sans paquet", async () => {
  controller.connect()
  await settle()
  navigator.onLine = false
  await listeners.offline()
  await store.purgeKey(KEY)
  await listeners.offline()
  assert.equal(button.disabled, true)

  navigator.onLine = true
  await listeners.online()
  assert.equal(button.disabled, false)
  assert.equal(message.hidden, true)
  controller.disconnect()
  assert.deepEqual(Object.keys(listeners), [])
})
