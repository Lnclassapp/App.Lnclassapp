// hors-connexion, Lot 0 (UDR §3.1) : le bandeau est visible hors ligne ou sur une page servie du cache, avec la date gardée.
// Lancer : node --test test/javascript/offline/offline_status_controller.test.js (valeurs Stimulus, DOM et window simulés).
import "./stimulus_base.js"
import { test, beforeEach } from "node:test"
import assert from "node:assert/strict"
import OfflineStatusController from "../../../app/javascript/offline/controllers/status_controller.js"

let served, listeners

beforeEach(() => {
  served = null
  listeners = {}
  globalThis.window = { addEventListener: (name, fn) => { listeners[name] = fn }, removeEventListener: (name) => { delete listeners[name] } }
  globalThis.document = { querySelector: () => (served ? { content: served } : null) }
  Object.defineProperty(globalThis, "navigator", { value: { onLine: true }, configurable: true })
})

function build() {
  const controller = Object.create(OfflineStatusController.prototype)
  const text = { textContent: "" }
  const values = { offlineText: "Hors ligne.", savedOnTemplate: "Gardée le %{date}", dateFormat: "%{day}/%{month} à %{hour}:%{minute}" }
  for (const [name, value] of Object.entries(values)) Object.defineProperty(controller, `${name}Value`, { value })
  Object.defineProperty(controller, "textTarget", { value: text })
  Object.defineProperty(controller, "element", { value: { hidden: true } })
  return { controller, text }
}

test("en ligne et page du réseau : caché", () => {
  const { controller } = build()
  controller.connect()
  assert.equal(controller.element.hidden, true)
})

test("hors ligne : visible avec le texte, sans date quand la page ne vient pas du cache", () => {
  navigator.onLine = false
  const { controller, text } = build()
  controller.connect()
  assert.equal(controller.element.hidden, false)
  assert.equal(text.textContent, "Hors ligne.")
})

test("page servie du cache : la date gardée est ajoutée au format jj/mm à hh:mm", () => {
  navigator.onLine = false
  served = new Date(2026, 10, 5, 9, 7).toISOString()
  const { controller, text } = build()
  controller.connect()
  assert.equal(text.textContent, "Hors ligne. Gardée le 05/11 à 09:07")
})

test("retour du réseau : caché ; perte du réseau : visible", () => {
  const { controller } = build()
  controller.connect()
  navigator.onLine = false
  listeners.offline()
  assert.equal(controller.element.hidden, false)
  navigator.onLine = true
  listeners.online()
  assert.equal(controller.element.hidden, true)
  controller.disconnect()
  assert.deepEqual(Object.keys(listeners), [])
})

test("une meta illisible est ignorée", () => {
  served = "pas une date"
  const { controller } = build()
  controller.connect()
  assert.equal(controller.element.hidden, true)
})
