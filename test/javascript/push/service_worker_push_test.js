// notifications-push, Lot B (ADR §4.4, UDR §3.3) : les écouteurs `push` et `notificationclick` ajoutés au programme d'arrière-plan,
// sans toucher à ceux de hors-connexion. Chargé dans un `vm` avec `registration` et `clients` simulés.
// Lancer : node --test test/javascript/push/service_worker_push_test.js
import { test, beforeEach } from "node:test"
import assert from "node:assert/strict"
import fs from "node:fs"
import vm from "node:vm"

const SOURCE = fs.readFileSync(new URL("../../../app/views/pwa/service-worker.js", import.meta.url), "utf8")
const ORIGIN = "https://lnclass.test"

let listeners, shown, windows, opened, focused

beforeEach(() => {
  listeners = {}
  shown = []
  opened = []
  focused = []
  windows = []
  const self = {
    location: { origin: ORIGIN },
    addEventListener: (name, fn) => { listeners[name] = fn },
    skipWaiting: async () => {},
    registration: { showNotification: async (title, options) => { shown.push({ title, options }) } },
    clients: {
      claim: async () => {},
      matchAll: async () => windows.map((url) => ({ url, focus: async () => { focused.push(url) } })),
      openWindow: async (url) => { opened.push(url) },
    },
  }
  vm.runInContext(SOURCE, vm.createContext({ self, caches: {}, fetch: async () => {}, Response, Headers, URL, Date, console, Promise }))
})

function dispatch(name, extra = {}) {
  const waits = []
  listeners[name]({ waitUntil: (promise) => waits.push(promise), ...extra })
  return Promise.all(waits)
}

const pushOf = (payload) => ({ data: { json: () => (typeof payload === "string" ? JSON.parse(payload) : payload) } })
const clickOn = (url) => {
  const closed = []
  const notification = { close: () => closed.push(true), data: url === undefined ? undefined : { url } }
  return { notification, closed }
}

test("les écouteurs de hors-connexion sont toujours là, et les deux nouveaux aussi", () => {
  assert.deepEqual(Object.keys(listeners).sort(), [ "activate", "fetch", "install", "message", "notificationclick", "push" ])
})

test("les noms de caches et la logique de hors-connexion sont inchangés", () => {
  for (const line of [ 'const CACHE = "lnclass-offline-v3"', 'const ASSETS = "lnclass-assets-v1"', 'const STATE = "lnclass-state-v1"',
    'const PAGES_PREFIX = "lnclass-pages-"', 'const OFFLINE_FILES = ["/offline.html", "/offline.css", "/icon-192.png"]' ]) {
    assert.ok(SOURCE.includes(line), line)
  }
  for (const name of [ "install", "activate", "message", "fetch" ]) assert.equal(SOURCE.split(`addEventListener("${name}"`).length - 1, 1, name)
})

test("push affiche titre, texte, icône de l'app et tag, avec l'URL de la même origine", async () => {
  await dispatch("push", pushOf({ title: "Lnclass", body: "Ta classe avance", url: "/", tag: "inactive" }))

  assert.deepEqual(JSON.parse(JSON.stringify(shown)), [ { title: "Lnclass", options: { body: "Ta classe avance", icon: "/icon-192.png", tag: "inactive", data: { url: ORIGIN + "/" } } } ])
})

test("push sans charge, illisible ou sans titre ni texte n'affiche rien", async () => {
  await dispatch("push", { data: null })
  await dispatch("push", { data: { json: () => { throw new SyntaxError("x") } } })
  await dispatch("push", pushOf({ title: "Lnclass" }))
  await dispatch("push", pushOf({ body: "x" }))

  assert.deepEqual(shown, [])
})

test("push dont l'URL est d'une autre origine ou invalide pointe vers l'accueil", async () => {
  await dispatch("push", pushOf({ title: "L", body: "b", url: "https://evil.test/x", tag: "t" }))
  await dispatch("push", pushOf({ title: "L", body: "b", url: "http://[bad", tag: "t" }))
  await dispatch("push", pushOf({ title: "L", body: "b", tag: "t" }))

  assert.deepEqual(shown.map((one) => one.options.data.url), [ ORIGIN + "/", ORIGIN + "/", ORIGIN + "/" ])
})

test("notificationclick ferme la notification et ouvre l'URL de la même origine", async () => {
  const click = clickOn(ORIGIN + "/courses")
  await dispatch("notificationclick", click)

  assert.equal(click.closed.length, 1)
  assert.deepEqual(opened, [ ORIGIN + "/courses" ])
})

test("notificationclick met au premier plan un onglet déjà ouvert sur l'URL plutôt que d'en ouvrir un second", async () => {
  windows = [ ORIGIN + "/autre", ORIGIN + "/courses" ]
  await dispatch("notificationclick", clickOn(ORIGIN + "/courses"))

  assert.deepEqual(focused, [ ORIGIN + "/courses" ])
  assert.deepEqual(opened, [])
})

test("notificationclick n'ouvre jamais une autre origine ni une URL absente, mais ferme la notification", async () => {
  for (const url of [ "https://evil.test/x", "javascript:alert(1)", "http://[bad", undefined ]) {
    const click = clickOn(url)
    await dispatch("notificationclick", click)
    assert.equal(click.closed.length, 1, String(url))
  }

  assert.deepEqual(opened, [])
  assert.deepEqual(focused, [])
})
