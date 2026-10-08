// ⚡ FRONT · pwa/service-worker — réseau seul pour les pages ; seule la page « Pas de connexion » est gardée
// Rôle : installe la page hors ligne, purge les anciennes versions, répond hors ligne aux seules navigations
// ADR  : 0082, 0049, 0076
// <N> augmente à chaque modification de public/offline.html ou de public/offline.css (ADR-0082 §4.2).
const CACHE = "lnclass-offline-v1"
const OFFLINE_FILES = ["/offline.html", "/offline.css", "/icon-192.png"]

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(OFFLINE_FILES)).then(() => self.skipWaiting()))
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
  )
})

// Une réponse du réseau n'est jamais mise en cache : aucune page de compte ne reste sur le téléphone.
self.addEventListener("fetch", (event) => {
  const { request } = event
  if (request.method !== "GET" || request.mode !== "navigate") return

  event.respondWith(fetch(request).catch(() => caches.match("/offline.html")))
})
