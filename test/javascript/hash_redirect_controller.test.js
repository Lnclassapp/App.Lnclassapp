// Règle « contrôleur Stimulus borné » (docs/guide/conventions.md §7) : hash-redirect ne remplace pas deux fois la même paire d'adresses dans la fenêtre de 10 s (marqueur daté), mais redirige de nouveau après.
// Constat : issue #635 (un 301 resté en cache rebouclait : /fiche → 301 → page#ancre → replace → /fiche → …).
// Lancer : node --test test/javascript/hash_redirect_controller.test.js (aucun navigateur : window et sessionStorage sont simulés).
import { test, mock, beforeEach, afterEach } from "node:test"
import assert from "node:assert/strict"
import HashRedirectController from "../../app/javascript/controllers/hash_redirect_controller.js"

const HASH = "fiche-de-revision"
const URL_VALUE = "/courses/maths/fiche"

function fakeStorage({ broken = false } = {}) {
  const data = new Map()
  const guard = () => { if (broken) throw new Error("stockage refusé") }
  return { getItem: (key) => { guard(); return data.get(key) ?? null }, setItem: (key, value) => { guard(); data.set(key, String(value)) } }
}

function setWindow({ hash = `#${HASH}`, storage = fakeStorage() } = {}) {
  const replaced = []
  globalThis.window = { location: { hash, replace: (url) => replaced.push(url) }, sessionStorage: storage }
  return replaced
}

function connect(values = {}) {
  const controller = Object.create(HashRedirectController.prototype)
  Object.defineProperties(controller, {
    hashValue: { value: values.hash ?? HASH },
    urlValue: { value: values.url ?? URL_VALUE },
  })
  controller.connect()
}

beforeEach(() => { delete globalThis.window; mock.timers.enable({ apis: ["Date"], now: 1_000_000 }) })
afterEach(() => mock.timers.reset())

test("replaces the visit once when the address ends with the anchor", () => {
  const replaced = setWindow()
  connect()
  assert.deepEqual(replaced, [URL_VALUE])
})

test("successive connects inside the window replace only once (cached 301 loop is instantaneous)", () => {
  const replaced = setWindow()
  connect()
  mock.timers.tick(30)
  connect()
  mock.timers.tick(30)
  connect()
  assert.deepEqual(replaced, [URL_VALUE])
})

test("a legitimate second visit once the window has elapsed replaces again", () => {
  const replaced = setWindow()
  connect()
  mock.timers.tick(9_999)
  connect()
  assert.deepEqual(replaced, [URL_VALUE], "encore dans la fenêtre")
  mock.timers.tick(1)
  connect()
  assert.deepEqual(replaced, [URL_VALUE, URL_VALUE], "fenêtre écoulée : redirige de nouveau")
  connect()
  assert.deepEqual(replaced, [URL_VALUE, URL_VALUE], "et la nouvelle fenêtre protège de nouveau")
})

test("a clock that goes backwards counts as recent: no replacement", () => {
  const replaced = setWindow()
  connect()
  mock.timers.setTime(500_000)
  connect()
  assert.deepEqual(replaced, [URL_VALUE])
})

test("another pair of addresses still replaces once", () => {
  const replaced = setWindow()
  connect()
  connect({ hash: HASH, url: "/courses/physique/fiche" })
  assert.deepEqual(replaced, [URL_VALUE, "/courses/physique/fiche"])
})

test("does nothing when the address has no matching anchor", () => {
  const replaced = setWindow({ hash: "#autre" })
  connect()
  assert.deepEqual(replaced, [])
})

test("never redirects when the marker cannot be written (storage refused): bounded rather than looping", () => {
  const replaced = setWindow({ storage: fakeStorage({ broken: true }) })
  connect()
  connect()
  assert.deepEqual(replaced, [])
})
