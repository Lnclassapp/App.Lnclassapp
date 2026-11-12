// Aide de test (hors-connexion, Lot 0) : un IndexedDB en mémoire, juste assez pour offline/store.js (open, magasins à clé,
// get / put / delete / getAll / clear, deleteDatabase). Une transaction se termine quand les micro-tâches sont vidées.
export function createFakeIndexedDB() {
  const databases = new Map() // nom → { version, stores: Map(nom → { keyPath, rows: Map }) }
  const fake = {
    databases,
    failNextPut: null, // une erreur (DOMException) levée par le prochain put
    failOpen: null,
    open(name) {
      const request = {}
      queueMicrotask(() => {
        if (fake.failOpen) { request.error = fake.failOpen; request.onerror?.({ target: request }); return }
        let data = databases.get(name)
        const created = !data
        if (created) { data = { stores: new Map() }; databases.set(name, data) }
        const db = {
          objectStoreNames: { contains: (store) => data.stores.has(store) },
          createObjectStore(store, { keyPath }) { data.stores.set(store, { keyPath, rows: new Map() }) },
          transaction(names, mode) { return transaction(fake, data, [].concat(names), mode) },
          close() {},
        }
        request.result = db
        if (created) request.onupgradeneeded?.({ target: request })
        request.onsuccess?.({ target: request })
      })
      return request
    },
    deleteDatabase(name) {
      const request = {}
      queueMicrotask(() => { databases.delete(name); request.onsuccess?.({ target: request }) })
      return request
    },
  }
  return fake
}

function transaction(fake, data, names, mode) {
  const tx = { error: null }
  setTimeout(() => (tx.error ? tx.onerror?.({ target: tx }) : tx.oncomplete?.({ target: tx })), 0)
  tx.objectStore = (name) => {
    const store = data.stores.get(name)
    const ask = (work) => {
      const request = {}
      queueMicrotask(() => {
        try { request.result = work(); request.onsuccess?.({ target: request }) }
        catch (error) { request.error = error; tx.error = error; request.onerror?.({ target: request }) }
      })
      return request
    }
    return {
      get: (key) => ask(() => structuredClone(store.rows.get(key))),
      getAll: () => ask(() => [...store.rows.values()].map((row) => structuredClone(row))),
      put: (value) => ask(() => {
        if (fake.failNextPut) { const error = fake.failNextPut; fake.failNextPut = null; throw error }
        if (mode !== "readwrite") throw new DOMException("lecture seule", "ReadOnlyError")
        store.rows.set(value[store.keyPath], structuredClone(value)); return value[store.keyPath]
      }),
      delete: (key) => ask(() => { store.rows.delete(key) }),
      clear: () => ask(() => { store.rows.clear() }),
    }
  }
  return tx
}
