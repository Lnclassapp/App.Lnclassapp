// Règle « contrôleur Stimulus borné » (docs/guide/conventions.md §7) : hash-redirect remplace l'adresse une seule fois par paire d'adresses.
// Constat : issue #635 (un 301 resté en cache rebouclait : /fiche → 301 → page#ancre → replace → /fiche → …).
// Lancer : node --test test/javascript/hash_redirect_controller.test.js (aucun navigateur : window et sessionStorage sont simulés).
import { test, beforeEach } from "node:test"
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

beforeEach(() => { delete globalThis.window })

test("replaces the visit once when the address ends with the anchor", () => {
  const replaced = setWindow()
  connect()
  assert.deepEqual(replaced, [URL_VALUE])
})

test("two successive connects on the same pair of addresses replace only once (cached 301 loop)", () => {
  const replaced = setWindow()
  connect()
  connect()
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
