// hors-connexion, Lot A, CA-3 (ADR §4.3, menace P2, P3, P6) : le programme d'arrière-plan, chargé dans un `vm` avec `caches` et `fetch` simulés.
// Lancer : node --test test/javascript/offline/page_cache.test.js
import { test, beforeEach } from "node:test"
import assert from "node:assert/strict"
import fs from "node:fs"
import vm from "node:vm"

const SOURCE = fs.readFileSync(new URL("../../../app/views/pwa/service-worker.js", import.meta.url), "utf8")
const ORIGIN = "https://lnclass.test"
const KEY = "0123456789abcdef"
const OTHER = "fedcba9876543210"
const DAY = 86_400_000

// Un Cache Storage minimal : l'ordre d'insertion est celui de Cache.keys(), remettre une URL la place en dernier.
function createCaches() {
  const stores = new Map()
  const idOf = (url) => new URL(String(url?.url ?? url), ORIGIN).href
  const cacheOf = (rows) => ({
    async match(url) { const hit = rows.get(idOf(url)); return hit ? hit.clone() : undefined },
    async put(url, response) { const id = idOf(url); rows.delete(id); rows.set(id, response) },
    async delete(url) { return rows.delete(idOf(url)) },
    async keys() { return [ ...rows.keys() ].map((url) => ({ url })) },
    async addAll(urls) { for (const url of urls) rows.set(ORIGIN + url, new Response(`file ${url}`)) },
  })
  return {
    stores,
    async open(name) { if (!stores.has(name)) stores.set(name, new Map()); return cacheOf(stores.get(name)) },
    async has(name) { return stores.has(name) },
    async delete(name) { return stores.delete(name) },
    async keys() { return [ ...stores.keys() ] },
  }
}

let caches, network, listeners, persistCalls, worker

// Charge le programme dans un contexte neuf, sur les `caches` donnés (un redémarrage du programme garde les caches).
function boot(sharedCaches = caches) {
  listeners = {}
  persistCalls = 0
  const self = {
    location: { origin: ORIGIN },
    addEventListener: (name, fn) => { listeners[name] = fn },
    skipWaiting: async () => {},
    clients: { claim: async () => {} },
    navigator: { storage: { persist: async () => { persistCalls += 1; return true } } },
  }
  const context = vm.createContext({ self, caches: sharedCaches, fetch: (request) => network(request), Response, Headers, URL, Date, console, Promise })
  vm.runInContext(SOURCE, context)
  return self
}

function dispatch(name, extra = {}) {
  const waits = []
  const event = { waitUntil: (promise) => waits.push(promise), ...extra }
  listeners[name]?.(event)
  return { event, settled: () => Promise.all(waits) }
}

function request(path, { method = "GET", mode = "cors", accept = "text/html", headers = {} } = {}) {
  return { url: ORIGIN + path, method, mode, headers: new Headers({ Accept: accept, ...headers }) }
}

async function visit(path, options) {
  let answer
  const { settled } = dispatch("fetch", { request: request(path, options), respondWith: (promise) => { answer = promise } })
  const response = answer ? await answer : undefined
  await settled()
  return { response, handled: Boolean(answer) }
}

const page = (key = KEY, title = "Leçon") => `<!DOCTYPE html><html><head><meta name="lnclass-offline-key" content="${key}"><title>${title}</title></head><body>${title}</body></html>`

function serve(path, body, { keep = "keep", status = 200, cacheControl = "max-age=0, private, must-revalidate", redirected = false } = {}) {
  network = async (req) => {
    if (req.url !== ORIGIN + path) throw new TypeError("unexpected")
    const headers = { "Content-Type": "text/html; charset=utf-8", "Cache-Control": cacheControl }
    if (keep) headers["Lnclass-Offline"] = keep
    const response = new Response(body, { status, headers })
    if (redirected) Object.defineProperty(response, "redirected", { value: true })
    return response
  }
}

const offlineNetwork = () => { network = async () => { throw new TypeError("Failed to fetch") } }
const sendKey = async (key) => { const { settled } = dispatch("message", { data: { type: "lnclass:key", key } }); await settled() }
const pagesOf = (key) => [ ...(caches.stores.get(`lnclass-pages-${key}`)?.keys() ?? []) ]

beforeEach(async () => {
  caches = createCaches()
  const cache = await caches.open("lnclass-offline-v2")
  await cache.put(ORIGIN + "/offline.html", new Response("<html>Pas de connexion</html>", { headers: { "Content-Type": "text/html" } }))
  boot()
})

test("une page gardable est gardée sous la clé reçue, puis servie hors ligne avec la meta et l'heure", async () => {
  await sendKey(KEY)
  serve("/courses/svt", page())
  const online = await visit("/courses/svt", { mode: "navigate" })

  assert.equal(online.response.status, 200)
  assert.deepEqual(pagesOf(KEY), [ ORIGIN + "/courses/svt" ])

  offlineNetwork()
  const offline = await visit("/courses/svt", { mode: "navigate" })
  const html = await offline.response.text()

  assert.match(html, /<meta name="lnclass-offline-served" content="\d{4}-\d{2}-\d{2}T[^"]+Z">/)
  assert.match(html, /<title>Leçon<\/title>/)
})

test("une visite Turbo (fetch, Accept text/html) est gardée et servie comme une navigation", async () => {
  await sendKey(KEY)
  serve("/exercises/e1", page(KEY, "Sujet"))
  await visit("/exercises/e1", { mode: "cors", accept: "text/html, application/xhtml+xml" })
  offlineNetwork()

  const { response, handled } = await visit("/exercises/e1", { mode: "cors", accept: "text/html, application/xhtml+xml" })

  assert.ok(handled)
  assert.match(await response.text(), /lnclass-offline-served/)
})

test("réseau d'abord : en ligne, la réponse du réseau est rendue telle quelle, sans meta servie", async () => {
  await sendKey(KEY)
  serve("/courses/svt", page())
  await visit("/courses/svt")
  serve("/courses/svt", page(KEY, "Nouvelle version"))

  const { response } = await visit("/courses/svt")
  const html = await response.text()

  assert.match(html, /Nouvelle version/)
  assert.doesNotMatch(html, /lnclass-offline-served/)
})

for (const [label, options] of [
  [ "sans en-tête keep", { keep: null } ],
  [ "avec no-store", { cacheControl: "no-store" } ],
  [ "redirigée", { redirected: true } ],
  [ "en 500", { status: 500 } ],
  [ "en 302", { status: 302 } ],
  [ "avec un autre mot que keep", { keep: "all" } ],
]) {
  test(`une réponse ${label} n'est jamais gardée`, async () => {
    await sendKey(KEY)
    serve("/courses/svt", page(), options)
    await visit("/courses/svt")

    assert.deepEqual(pagesOf(KEY), [])
    offlineNetwork()
    assert.match(await (await visit("/courses/svt", { mode: "navigate" })).response.text(), /Pas de connexion/)
  })
}

test("une page dont la meta porte une autre clé que la clé reçue n'est pas gardée", async () => {
  await sendKey(KEY)
  serve("/courses/svt", page(OTHER))
  await visit("/courses/svt")

  assert.deepEqual(pagesOf(KEY), [])
  assert.deepEqual(pagesOf(OTHER), [])
})

test("sans clé reçue, ou avec une clé illisible, rien n'est gardé", async () => {
  serve("/courses/svt", page())
  await visit("/courses/svt")
  await sendKey("pas-une-cle")
  await visit("/courses/svt")

  assert.equal([ ...caches.stores.keys() ].filter((name) => name.startsWith("lnclass-pages-")).length, 0)
})

test("une page gardée sous une autre clé n'est jamais servie", async () => {
  await sendKey(KEY)
  serve("/courses/svt", page())
  await visit("/courses/svt")
  await sendKey(OTHER)
  offlineNetwork()

  assert.match(await (await visit("/courses/svt", { mode: "navigate" })).response.text(), /Pas de connexion/)
})

test("une page de 31 jours n'est pas servie et est retirée ; à 29 jours elle l'est", async () => {
  await sendKey(KEY)
  const old = await caches.open(`lnclass-pages-${KEY}`)
  const kept = (days) => new Response(page(), { headers: { "Content-Type": "text/html", "X-Lnclass-Saved-At": new Date(Date.now() - days * DAY).toISOString() } })
  await old.put(ORIGIN + "/old", kept(31))
  await old.put(ORIGIN + "/recent", kept(29))
  offlineNetwork()

  assert.match(await (await visit("/old", { mode: "navigate" })).response.text(), /Pas de connexion/)
  assert.deepEqual(pagesOf(KEY), [ ORIGIN + "/recent" ])
  assert.match(await (await visit("/recent", { mode: "navigate" })).response.text(), /lnclass-offline-served/)
})

test("à la 61e page gardée, la plus ancienne sort", async () => {
  await sendKey(KEY)
  for (let index = 1; index <= 61; index += 1) {
    serve(`/courses/c${index}`, page())
    await visit(`/courses/c${index}`)
  }

  const kept = pagesOf(KEY)
  assert.equal(kept.length, 60)
  assert.ok(!kept.includes(ORIGIN + "/courses/c1"))
  assert.ok(kept.includes(ORIGIN + "/courses/c61"))
})

test("la clé survit au redémarrage du programme", async () => {
  await sendKey(KEY)
  serve("/courses/svt", page())
  await visit("/courses/svt")
  boot(caches)
  offlineNetwork()

  assert.match(await (await visit("/courses/svt", { mode: "navigate" })).response.text(), /lnclass-offline-served/)
})

test("jamais gardé ni intercepté : POST, autre origine, image, frame Turbo", async () => {
  await sendKey(KEY)
  serve("/courses/svt", page())

  assert.equal((await visit("/courses/svt", { method: "POST" })).handled, false)
  assert.equal((await visit("/courses/svt", { accept: "image/png" })).handled, false)
  assert.equal((await visit("/courses/svt", { headers: { "Turbo-Frame": "courses" } })).handled, false)
  let foreign = false
  dispatch("fetch", { request: { url: "https://autre.test/x", method: "GET", mode: "navigate", headers: new Headers({ Accept: "text/html" }) }, respondWith: () => { foreign = true } })
  assert.equal(foreign, false)
  assert.deepEqual(pagesOf(KEY), [])
})

test("navigator.storage.persist() est demandé une seule fois, à la première page gardée", async () => {
  await sendKey(KEY)
  assert.equal(persistCalls, 0)
  serve("/a", page())
  await visit("/a")
  serve("/b", page())
  await visit("/b")

  assert.equal(persistCalls, 1)
})

test("les assets digérés sont gardés à la première demande, cache d'abord ensuite", async () => {
  let calls = 0
  network = async () => { calls += 1; return new Response("body{}", { status: 200, headers: { "Content-Type": "text/css" } }) }
  const first = await visit("/assets/application-3f9a1c2b4d.css", { accept: "text/css" })
  const second = await visit("/assets/application-3f9a1c2b4d.css", { accept: "text/css" })

  assert.equal(await first.response.text(), "body{}")
  assert.equal(await second.response.text(), "body{}")
  assert.equal(calls, 1)
  assert.equal((await visit("/assets/sans-empreinte.css", { accept: "text/css" })).handled, false)
})

test("l'activation purge les anciennes versions et garde les caches de pages", async () => {
  await caches.open("lnclass-offline-v1")
  await caches.open("lnclass-assets-v0")
  await caches.open(`lnclass-pages-${KEY}`)
  const { settled } = dispatch("activate")
  await settled()

  const names = await caches.keys()
  assert.ok(!names.includes("lnclass-offline-v1"))
  assert.ok(!names.includes("lnclass-assets-v0"))
  assert.ok(names.includes("lnclass-offline-v2"))
  assert.ok(names.includes(`lnclass-pages-${KEY}`))
})

test("l'installation range la page « Pas de connexion » et ses deux fichiers", async () => {
  const fresh = createCaches()
  boot(fresh)
  const { settled } = dispatch("install")
  await settled()

  assert.deepEqual([ ...fresh.stores.get("lnclass-offline-v2").keys() ].sort(), [ ORIGIN + "/icon-192.png", ORIGIN + "/offline.css", ORIGIN + "/offline.html" ])
})
