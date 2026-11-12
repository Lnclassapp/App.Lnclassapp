// ⚡ FRONT · offline/store — la base locale du téléphone, une base IndexedDB par clé d'appareil (paquets de corrigé, copies en file)
// Rôle : API gelée au Lot 0 ; tout accès au stockage est sous try/catch et l'échec remonte en OfflineStoreError (jamais avalé)
// ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.2, §4.5, menace P1, P2, P4) · contrat du plan « Contrats JavaScript gelés »

const KEY_PATTERN = /^[0-9a-f]{16}$/
const DB_PREFIX = "lnclass-offline-"
const PAGES_CACHE_PREFIX = "lnclass-pages-"
const REMEMBERED_KEY = "lnclass-offline-key"
const META_SELECTOR = 'meta[name="lnclass-offline-key"]'
const DB_VERSION = 1
const MAX_AGE_MS = 30 * 24 * 3600 * 1000

// code : unavailable (IndexedDB absent ou refusé), quota (stockage plein), invalid_key, invalid, not_found, purge_failed, before_purge.
export class OfflineStoreError extends Error {
  constructor(code, message, { cause, errors } = {}) {
    super(message, cause ? { cause } : undefined)
    this.name = "OfflineStoreError"
    this.code = code
    if (errors) this.errors = errors
  }
}

const fromError = (error, fallback = "unavailable") => {
  if (error instanceof OfflineStoreError) return error
  const quota = error?.name === "QuotaExceededError"
  return new OfflineStoreError(quota ? "quota" : fallback, error?.message || String(error), { cause: error })
}

const assertKey = (key) => {
  if (typeof key !== "string" || !KEY_PATTERN.test(key)) throw new OfflineStoreError("invalid_key", "Clé d'appareil illisible")
}

const asPromise = (request) => new Promise((resolve, reject) => {
  request.onsuccess = () => resolve(request.result)
  request.onerror = () => reject(fromError(request.error))
})

const finished = (tx) => new Promise((resolve, reject) => {
  tx.oncomplete = () => resolve()
  tx.onerror = () => reject(fromError(tx.error))
  tx.onabort = () => reject(fromError(tx.error))
})

// La clé de la page courante (meta posée par le serveur), ou null sans connexion.
export function currentKey() {
  return globalThis.document?.querySelector(META_SELECTOR)?.content || null
}

// Range la clé courante sur l'appareil et rend la précédente (null la première fois) : un changement déclenche la purge de l'ancienne.
export function rememberKey(key) {
  assertKey(key)
  try {
    const previous = globalThis.localStorage.getItem(REMEMBERED_KEY)
    globalThis.localStorage.setItem(REMEMBERED_KEY, key)
    return previous
  } catch (error) {
    throw fromError(error)
  }
}

export async function openDb(key) {
  assertKey(key)
  const factory = globalThis.indexedDB
  if (!factory) throw new OfflineStoreError("unavailable", "IndexedDB n'est pas disponible")
  try {
    const request = factory.open(`${DB_PREFIX}${key}`, DB_VERSION)
    request.onupgradeneeded = () => {
      const db = request.result
      if (!db.objectStoreNames.contains("packs")) db.createObjectStore("packs", { keyPath: "exercise_public_id" })
      if (!db.objectStoreNames.contains("copies")) db.createObjectStore("copies", { keyPath: "client_copy_id" })
    }
    return await asPromise(request)
  } catch (error) {
    throw fromError(error)
  }
}

// Une transaction : `work(stores)` pose ses requêtes et rend leur résultat ; la base est refermée dans tous les cas.
async function inTransaction(key, names, mode, work) {
  const db = await openDb(key)
  try {
    const tx = db.transaction(names, mode)
    const stores = Object.fromEntries(names.map((name) => [name, tx.objectStore(name)]))
    const done = finished(tx)
    done.catch(() => {}) // si `work` échoue d'abord, cette erreur-ci n'est pas une seconde alerte : la première remonte
    const result = await work(stores)
    await done
    return result
  } catch (error) {
    throw fromError(error)
  } finally {
    db.close()
  }
}

// pack : { exercise_public_id, token, digest, issued_at, questions, … } tel que rendu par le serveur ; stored_at est posé ici.
export function putPack(key, pack) {
  if (!pack?.exercise_public_id) return Promise.reject(new OfflineStoreError("invalid", "Paquet sans exercice"))
  return inTransaction(key, [ "packs" ], "readwrite", ({ packs }) => asPromise(packs.put({ ...pack, stored_at: new Date(Date.now()).toISOString() })))
    .then(() => undefined)
}

// → le paquet, ou null s'il est absent ou vieux de plus de 30 jours (alors retiré).
export async function getPack(key, exercisePublicId) {
  const pack = await inTransaction(key, [ "packs" ], "readonly", ({ packs }) => asPromise(packs.get(exercisePublicId)))
  if (!pack) return null
  if (Date.now() - Date.parse(pack.stored_at) <= MAX_AGE_MS) return pack

  await inTransaction(key, [ "packs" ], "readwrite", ({ packs }) => asPromise(packs.delete(exercisePublicId)))
  return null
}

// copy : { client_copy_id, exercise_public_id, pack_token, started_at, submitted_at, answers, provisional_percent, status?, reason? }
export function putCopy(key, copy) {
  if (!copy?.client_copy_id) return Promise.reject(new OfflineStoreError("invalid", "Copie sans identifiant"))
  return inTransaction(key, [ "copies" ], "readwrite", ({ copies }) => asPromise(copies.put({ status: "pending", ...copy })))
    .then(() => undefined)
}

// → les copies de la clé, les plus anciennes d'abord ; { status } ne garde que ce statut.
export async function listCopies(key, { status } = {}) {
  const all = await inTransaction(key, [ "copies" ], "readonly", ({ copies }) => asPromise(copies.getAll()))
  return all.filter((copy) => !status || copy.status === status)
    .sort((a, b) => String(a.submitted_at).localeCompare(String(b.submitted_at)))
}

// → la copie mise à jour ; l'identifiant ne change jamais.
export function updateCopy(key, id, patch) {
  return inTransaction(key, [ "copies" ], "readwrite", async ({ copies }) => {
    const current = await asPromise(copies.get(id))
    if (!current) throw new OfflineStoreError("not_found", `Copie ${id} absente`)

    const next = { ...current, ...patch, client_copy_id: current.client_copy_id }
    await asPromise(copies.put(next))
    return next
  })
}

export function deleteCopy(key, id) {
  return inTransaction(key, [ "copies" ], "readwrite", ({ copies }) => asPromise(copies.delete(id))).then(() => undefined)
}

// Vide ce que Lnclass garde pour la clé : le cache de pages, puis la base. keepQueue : la base reste, réduite aux copies en attente
// (jamais envoyées sous une autre clé). Chaque étape est tentée ; la première erreur remonte ensuite, avec toutes les autres.
export async function purgeKey(key, { keepQueue = false } = {}) {
  assertKey(key)
  const errors = []
  const attempt = async (step) => { try { await step() } catch (error) { errors.push(error) } }

  await attempt(async () => { if (globalThis.caches) await globalThis.caches.delete(`${PAGES_CACHE_PREFIX}${key}`) })
  await attempt(async () => {
    if (!keepQueue) return deleteDatabase(key)

    await inTransaction(key, [ "packs", "copies" ], "readwrite", async ({ packs, copies }) => {
      await asPromise(packs.clear())
      const all = await asPromise(copies.getAll())
      await Promise.all(all.filter((copy) => copy.status !== "pending").map((copy) => asPromise(copies.delete(copy.client_copy_id))))
    })
  })
  if (errors.length) throw new OfflineStoreError("purge_failed", errors[0].message, { cause: errors[0], errors })
}

async function deleteDatabase(key) {
  const factory = globalThis.indexedDB
  if (!factory) throw new OfflineStoreError("unavailable", "IndexedDB n'est pas disponible")

  await asPromise(factory.deleteDatabase(`${DB_PREFIX}${key}`))
}

// Les fonctions à jouer avant une purge (l'envoi de la file avant la déconnexion). registerBeforePurge rend de quoi se désinscrire.
const beforePurge = []

export function registerBeforePurge(fn) {
  beforePurge.push(fn)
  return () => {
    const index = beforePurge.indexOf(fn)
    if (index >= 0) beforePurge.splice(index, 1)
  }
}

// Joue toutes les fonctions dans l'ordre ; si l'une échoue, les autres tournent quand même, puis l'erreur remonte.
export async function runBeforePurge() {
  const errors = []
  for (const fn of [ ...beforePurge ]) {
    try { await fn() } catch (error) { errors.push(error) }
  }
  if (errors.length) throw new OfflineStoreError("before_purge", errors[0].message, { cause: errors[0], errors })
}
