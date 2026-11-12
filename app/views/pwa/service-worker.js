// ⚡ FRONT · pwa/service-worker — réseau d'abord ; garde les pages que le serveur marque « Lnclass-Offline: keep », par clé d'appareil
// Rôle : page « Pas de connexion », assets digérés, pages de compte déjà ouvertes (60 par clé, 30 jours) servies si le réseau échoue ; oubli de la clé (forget)
// ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.2, §4.3, menace P1, P2, P3, P6), 0082 (§4.2 amendé), 0049, 0076
// <N> augmente à chaque modification de public/offline.html ou de public/offline.css (ADR-0082 §4.2).
const CACHE = "lnclass-offline-v2"
const ASSETS = "lnclass-assets-v1"
const STATE = "lnclass-state-v1"
const PAGES_PREFIX = "lnclass-pages-"
const OFFLINE_FILES = ["/offline.html", "/offline.css", "/icon-192.png"]
const KEEP_HEADER = "Lnclass-Offline"
const SAVED_AT = "X-Lnclass-Saved-At"
const KEY_URL = "/__lnclass/key"
const KEY_PATTERN = /^[0-9a-f]{16}$/
const PAGE_KEY = /<meta name="lnclass-offline-key" content="([0-9a-f]{16})"/
const DIGESTED_ASSET = /^\/assets\/.+-[0-9a-f]{7,}\.[a-z0-9]+$/
const MAX_PAGES = 60
const MAX_ASSETS = 200
const MAX_AGE_MS = 30 * 24 * 3600 * 1000

let currentKey = null
// Clés oubliées (déconnexion, arrivée non connectée) : plus rien n'est gardé sous elles tant que la page ne les redonne pas.
const forgotten = new Set()
let persistAsked = false

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(OFFLINE_FILES)).then(() => self.skipWaiting()))
})

// Les versions anciennes sont purgées ; les caches de pages (un par clé) se purgent depuis la page (changement de clé), et par le programme lui-même (message ou en-tête « forget »).
self.addEventListener("activate", (event) => {
  const kept = [CACHE, ASSETS, STATE]
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => !kept.includes(key) && !key.startsWith(PAGES_PREFIX)).map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
  )
})

// La page dit quelle clé d'appareil est la sienne ; elle est rangée pour survivre à l'arrêt du programme.
self.addEventListener("message", (event) => {
  const data = event.data
  if (data?.type === "lnclass:forget" && typeof data.key === "string" && KEY_PATTERN.test(data.key)) return event.waitUntil(forget(data.key))
  if (data?.type !== "lnclass:key" || typeof data.key !== "string" || !KEY_PATTERN.test(data.key)) return

  forgotten.delete(data.key)
  currentKey = data.key
  event.waitUntil(
    caches.open(STATE).then((cache) => cache.put(KEY_URL, new Response(data.key))).catch((error) => console.error("lnclass: clé non rangée", error))
  )
})

self.addEventListener("fetch", (event) => {
  const { request } = event
  if (request.method !== "GET") return

  const url = new URL(request.url)
  if (url.origin !== self.location.origin) return

  if (DIGESTED_ASSET.test(url.pathname)) return event.respondWith(assetFirst(event))
  // Un frame Turbo rend un morceau de page : jamais gardé ni servi à la place de la page entière.
  if (!wantsHtml(request) || request.headers.get("Turbo-Frame")) return

  event.respondWith(networkFirst(event))
})

// Navigation ou visite Turbo (un fetch) : les deux demandent du HTML.
function wantsHtml(request) {
  return request.mode === "navigate" || (request.headers.get("Accept") || "").includes("text/html")
}

async function networkFirst(event) {
  const { request } = event
  let response
  try {
    response = await fetch(request)
  } catch {
    return (await cachedPage(request)) || offlineFallback()
  }
  if (response.headers.get(KEEP_HEADER) === "forget") event.waitUntil(forget().catch((error) => console.error("lnclass: oubli de la clé incomplet", error)))
  if (keepable(response)) event.waitUntil(keepPage(request, response.clone()).catch((error) => console.error("lnclass: page non gardée", error)))
  return response
}

// Oublier une clé (message de la page à la déconnexion, ou réponse « forget » d'un visiteur non connecté) : synchrone pour la mémoire,
// puis le cache de pages et la clé rangée sont supprimés. Sans clé donnée, c'est la clé courante.
async function forget(requested) {
  const key = requested || (await loadKey())
  if (!key) return

  forgotten.add(key)
  const wasCurrent = currentKey === key
  if (wasCurrent) currentKey = null
  await caches.delete(PAGES_PREFIX + key)
  const state = await caches.open(STATE)
  const stored = await state.match(KEY_URL)
  if (wasCurrent || (stored && (await stored.text()) === key)) await state.delete(KEY_URL)
  await caches.delete(PAGES_PREFIX + key)
}

// Le serveur décide seul (menace P6) : en-tête « keep », 200, non redirigée, sans no-store.
function keepable(response) {
  return response.status === 200 && !response.redirected && response.headers.get(KEEP_HEADER) === "keep" &&
    !/no-store/i.test(response.headers.get("Cache-Control") || "")
}

async function loadKey() {
  if (currentKey) return currentKey

  const cache = await caches.open(STATE)
  const stored = await cache.match(KEY_URL)
  const key = stored ? await stored.text() : null
  currentKey = key && KEY_PATTERN.test(key) && !forgotten.has(key) ? key : null
  return currentKey
}

// Gardée sous la clé courante seulement, et seulement si la meta de la page porte cette même clé (menace P2).
async function keepPage(request, response) {
  const key = await loadKey()
  if (!key) return

  const body = await response.text()
  if (body.match(PAGE_KEY)?.[1] !== key) return

  // La clé a pu être oubliée ou changée pendant la lecture du corps : on abandonne avant d'ouvrir (donc de recréer) le cache.
  if (!stillCurrent(key)) return

  const cache = await caches.open(PAGES_PREFIX + key)
  if (!stillCurrent(key)) return caches.delete(PAGES_PREFIX + key)

  const headers = { "Content-Type": response.headers.get("Content-Type") || "text/html; charset=utf-8", [SAVED_AT]: new Date().toISOString() }
  await cache.put(request.url, new Response(body, { status: 200, headers }))
  if (!stillCurrent(key)) return caches.delete(PAGES_PREFIX + key)

  await trim(cache, MAX_PAGES)
  askPersistence()
}

function stillCurrent(key) {
  return currentKey === key && !forgotten.has(key)
}

// L'ordre de Cache.keys() est celui de l'insertion : les premières sont les plus anciennes.
async function trim(cache, max) {
  const keys = await cache.keys()
  await Promise.all(keys.slice(0, Math.max(0, keys.length - max)).map((entry) => cache.delete(entry.url)))
}

// Une seule fois par démarrage du programme ; un refus ne change rien.
function askPersistence() {
  if (persistAsked) return

  persistAsked = true
  Promise.resolve(self.navigator?.storage?.persist?.()).catch(() => {})
}

async function cachedPage(request) {
  const key = await loadKey()
  if (!key || !(await caches.has(PAGES_PREFIX + key))) return null

  const cache = await caches.open(PAGES_PREFIX + key)
  const hit = await cache.match(request.url)
  if (!hit) return null

  const savedAt = Date.parse(hit.headers.get(SAVED_AT))
  if (Number.isNaN(savedAt) || Date.now() - savedAt > MAX_AGE_MS) {
    await cache.delete(request.url)
    return null
  }
  return served(hit, new Date(savedAt).toISOString())
}

// La page dit elle-même qu'elle vient du cache (bandeau « Hors ligne ») par une meta posée juste après <head>.
async function served(hit, savedAt) {
  const meta = `<meta name="lnclass-offline-served" content="${savedAt}">`
  const html = await hit.text()
  const body = /<head[^>]*>/i.test(html) ? html.replace(/<head[^>]*>/i, (head) => head + meta) : meta + html
  return new Response(body, { status: 200, headers: { "Content-Type": hit.headers.get("Content-Type") || "text/html; charset=utf-8" } })
}

async function offlineFallback() {
  const cache = await caches.open(CACHE)
  return (await cache.match("/offline.html")) || Response.error()
}

// Un asset digéré porte son empreinte dans son nom : cache d'abord, jamais périmé.
async function assetFirst(event) {
  const { request } = event
  const cache = await caches.open(ASSETS)
  const hit = await cache.match(request.url)
  if (hit) return hit

  const response = await fetch(request)
  if (response.status === 200 && !response.redirected) {
    event.waitUntil(cache.put(request.url, response.clone()).then(() => trim(cache, MAX_ASSETS)).catch((error) => console.error("lnclass: asset non gardé", error)))
  }
  return response
}
