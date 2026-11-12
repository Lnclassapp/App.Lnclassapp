// hors-connexion, Lot 0 (ADR §4.2 et §4.5, menace P1, P2, P4) : la base locale par clé d'appareil. Lancer :
// node --test test/javascript/offline/store.test.js (aucun navigateur : IndexedDB, localStorage, caches et document simulés).
import { test, beforeEach } from "node:test"
import assert from "node:assert/strict"
import { createFakeIndexedDB } from "./fake_indexeddb.js"
import * as store from "../../../app/javascript/offline/store.js"

const KEY = "0123456789abcdef"
const OTHER = "fedcba9876543210"
const DAY = 86_400_000

let fake, deletedCaches, local

beforeEach(() => {
  fake = createFakeIndexedDB()
  deletedCaches = []
  local = new Map()
  globalThis.indexedDB = fake
  globalThis.caches = { delete: async (name) => { deletedCaches.push(name); return true } }
  globalThis.localStorage = { getItem: (k) => local.get(k) ?? null, setItem: (k, v) => local.set(k, String(v)) }
  globalThis.document = { querySelector: (selector) => (selector === 'meta[name="lnclass-offline-key"]' && globalThis.metaKey ? { content: globalThis.metaKey } : null) }
  globalThis.metaKey = null
})

const copy = (id, extra = {}) => ({ client_copy_id: id, exercise_public_id: "ex1", pack_token: "tok", started_at: "2026-11-12T10:00:00Z",
  submitted_at: "2026-11-12T10:10:00Z", answers: {}, provisional_percent: 50, ...extra })

test("currentKey lit la meta de la page, null sans meta", () => {
  assert.equal(store.currentKey(), null)
  globalThis.metaKey = KEY
  assert.equal(store.currentKey(), KEY)
})

test("rememberKey range la clé et rend la précédente (null la première fois)", () => {
  assert.equal(store.rememberKey(KEY), null)
  assert.equal(store.rememberKey(OTHER), KEY)
  assert.equal(store.rememberKey(OTHER), OTHER)
})

test("openDb ouvre lnclass-offline-<clé> avec les magasins packs et copies ; une clé illisible est refusée", async () => {
  const db = await store.openDb(KEY)
  assert.ok(db.objectStoreNames.contains("packs"))
  assert.ok(db.objectStoreNames.contains("copies"))
  assert.ok(fake.databases.has(`lnclass-offline-${KEY}`))
  await assert.rejects(store.openDb("../x"), { name: "OfflineStoreError", code: "invalid_key" })
  await assert.rejects(store.openDb(null), { code: "invalid_key" })
})

test("un paquet se range et se relit ; absent : null", async () => {
  assert.equal(await store.getPack(KEY, "ex1"), null)
  await store.putPack(KEY, { exercise_public_id: "ex1", token: "tok", digest: "d", questions: [ { id: 1 } ] })
  const pack = await store.getPack(KEY, "ex1")
  assert.equal(pack.token, "tok")
  assert.deepEqual(pack.questions, [ { id: 1 } ])
})

test("un paquet de plus de 30 jours n'est pas rendu et est retiré", async (t) => {
  const now = Date.now()
  await store.putPack(KEY, { exercise_public_id: "ex1", token: "tok" })
  t.mock.method(Date, "now", () => now + 31 * DAY)
  assert.equal(await store.getPack(KEY, "ex1"), null)
  t.mock.method(Date, "now", () => now)
  assert.equal(await store.getPack(KEY, "ex1"), null, "retiré, pas seulement masqué")
})

test("une copie sans identifiant ou un paquet sans exercice est refusé", async () => {
  await assert.rejects(store.putCopy(KEY, { exercise_public_id: "ex1" }), { code: "invalid" })
  await assert.rejects(store.putPack(KEY, { token: "t" }), { code: "invalid" })
})

test("putCopy garde la copie en attente, listCopies filtre par statut, updateCopy et deleteCopy", async () => {
  await store.putCopy(KEY, copy("a"))
  await store.putCopy(KEY, copy("b", { submitted_at: "2026-11-12T09:00:00Z" }))
  const all = await store.listCopies(KEY)
  assert.deepEqual(all.map((c) => c.client_copy_id), [ "b", "a" ], "triées par heure de rendu")
  assert.ok(all.every((c) => c.status === "pending"))

  const updated = await store.updateCopy(KEY, "a", { status: "rejected", reason: "stale" })
  assert.equal(updated.status, "rejected")
  assert.equal(updated.client_copy_id, "a")
  assert.deepEqual((await store.listCopies(KEY, { status: "pending" })).map((c) => c.client_copy_id), [ "b" ])
  assert.deepEqual((await store.listCopies(KEY, { status: "rejected" })).map((c) => c.reason), [ "stale" ])

  await store.deleteCopy(KEY, "b")
  assert.equal((await store.listCopies(KEY)).length, 1)
})

test("updateCopy ne change jamais l'identifiant et refuse une copie absente", async () => {
  await store.putCopy(KEY, copy("a"))
  const updated = await store.updateCopy(KEY, "a", { client_copy_id: "zzz", status: "synced" })
  assert.equal(updated.client_copy_id, "a")
  await assert.rejects(store.updateCopy(KEY, "nope", { status: "synced" }), { name: "OfflineStoreError", code: "not_found" })
})

test("chaque clé a sa base : les copies d'une clé ne sont jamais vues par l'autre", async () => {
  await store.putCopy(KEY, copy("a"))
  assert.deepEqual(await store.listCopies(OTHER), [])
})

test("purgeKey vide la base et le cache de pages de la clé, pas ceux d'une autre", async () => {
  await store.putCopy(KEY, copy("a"))
  await store.putCopy(OTHER, copy("z"))
  await store.purgeKey(KEY)
  assert.ok(!fake.databases.has(`lnclass-offline-${KEY}`))
  assert.ok(fake.databases.has(`lnclass-offline-${OTHER}`))
  assert.deepEqual(deletedCaches, [ `lnclass-pages-${KEY}` ])
})

test("purgeKey keepQueue garde les copies en attente seulement", async () => {
  await store.putPack(KEY, { exercise_public_id: "ex1", token: "t" })
  await store.putCopy(KEY, copy("a"))
  await store.putCopy(KEY, copy("b", { status: "synced" }))
  await store.putCopy(KEY, copy("c", { status: "rejected" }))
  await store.purgeKey(KEY, { keepQueue: true })
  assert.deepEqual((await store.listCopies(KEY)).map((c) => c.client_copy_id), [ "a" ])
  assert.equal(await store.getPack(KEY, "ex1"), null)
  assert.deepEqual(deletedCaches, [ `lnclass-pages-${KEY}` ])
})

test("stockage plein : l'erreur remonte en OfflineStoreError « quota », avec sa cause", async () => {
  const cause = new DOMException("plein", "QuotaExceededError")
  await store.openDb(KEY)
  fake.failNextPut = cause
  await assert.rejects(store.putCopy(KEY, copy("a")), (error) => error.name === "OfflineStoreError" && error.code === "quota" && error.cause === cause)
})

test("IndexedDB absent ou qui refuse de s'ouvrir : « unavailable », jamais avalé", async () => {
  delete globalThis.indexedDB
  await assert.rejects(store.listCopies(KEY), { name: "OfflineStoreError", code: "unavailable" })
  globalThis.indexedDB = fake
  fake.failOpen = new DOMException("refusé", "SecurityError")
  await assert.rejects(store.putPack(KEY, { exercise_public_id: "ex1" }), { code: "unavailable" })
})

test("purgeKey tente tout puis remonte l'erreur du cache", async () => {
  globalThis.caches = { delete: async () => { throw new Error("caches en panne") } }
  await store.putCopy(KEY, copy("a"))
  await assert.rejects(store.purgeKey(KEY), { name: "OfflineStoreError", code: "purge_failed" })
  assert.ok(!fake.databases.has(`lnclass-offline-${KEY}`), "la base est tout de même vidée")
})

test("runBeforePurge joue les fonctions dans l'ordre ; une qui échoue remonte après les autres ; on peut se désinscrire", async () => {
  const calls = []
  const off = store.registerBeforePurge(async () => { calls.push("un") })
  store.registerBeforePurge(() => { calls.push("deux"); throw new Error("envoi impossible") })
  store.registerBeforePurge(() => { calls.push("trois") })
  await assert.rejects(store.runBeforePurge(), (error) => error.code === "before_purge" && error.errors.length === 1)
  assert.deepEqual(calls, [ "un", "deux", "trois" ])
  off()
  calls.length = 0
  await assert.rejects(store.runBeforePurge())
  assert.deepEqual(calls, [ "deux", "trois" ])
})

test("deletePack retire le paquet d'un exercice, sans toucher aux autres ; absent : sans erreur", async () => {
  await store.putPack(KEY, { exercise_public_id: "ex1", token: "a", questions: [] })
  await store.putPack(KEY, { exercise_public_id: "ex2", token: "b", questions: [] })
  await store.deletePack(KEY, "ex1")
  await store.deletePack(KEY, "absent")

  assert.equal(await store.getPack(KEY, "ex1"), null)
  assert.equal((await store.getPack(KEY, "ex2")).token, "b")
})
