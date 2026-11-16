// Règle « contrôleur Stimulus borné » (docs/guide/conventions.md §7) : math ne se relance pas à l'infini quand deux éléments `math` s'imbriquent.
// Constat : PR 628 (un MutationObserver par instance, deux instances imbriquées se renvoyaient leurs mutations : la tâche de CI `lecons` a dépassé 5 minutes deux fois).
// Lancer : node --test test/javascript/math_controller.test.js (aucun navigateur : MutationObserver et DOM sont simulés, KaTeX est le vrai).
import { test, beforeEach, afterEach } from "node:test"
import assert from "node:assert/strict"
import MathController from "../../app/javascript/controllers/math_controller.js"

// MutationObserver minimal mais fidèle sur ce qui compte ici : les enregistrements s'accumulent par observateur, `takeRecords()` les vide,
// la livraison au rappel est asynchrone (micro-tâche) et ne livre rien si la file est vide.
const observers = new Set()
class FakeMutationObserver {
  constructor(callback) { this.callback = callback; this.queue = []; this.scheduled = false }
  observe(target) { this.target = target; observers.add(this) }
  disconnect() { observers.delete(this); this.queue = [] }
  takeRecords() { const records = this.queue; this.queue = []; return records }
  enqueue(record) {
    this.queue.push(record)
    if (this.scheduled) return
    this.scheduled = true
    setImmediate(() => { this.scheduled = false; const records = this.takeRecords(); if (records.length > 0) this.callback(records) })
  }
}

// Un nœud muté est vu par tout observateur dont l'élément le contient (sous-arbre commun).
function mutate(node) {
  for (const observer of observers) if (observer.target.contains(node)) observer.enqueue({ target: node })
}

let renderedElements
let documentListeners

beforeEach(() => {
  observers.clear()
  renderedElements = []
  documentListeners = []
  globalThis.MutationObserver = FakeMutationObserver
  globalThis.document = { addEventListener: (name) => documentListeners.push(name), removeEventListener: () => {} }
})
afterEach(() => { delete globalThis.MutationObserver; delete globalThis.document })

const flush = async (turns = 30) => { for (let i = 0; i < turns; i++) await new Promise((resolve) => setImmediate(resolve)) }

function build(element) {
  const controller = Object.create(MathController.prototype)
  Object.defineProperty(controller, "element", { value: element })
  return controller
}

// Deux éléments `math` imbriqués autour d'une même feuille : l'extérieur contient l'intérieur, qui contient la feuille.
function nested() {
  const leaf = { name: "feuille" }
  const inner = { nodeType: 1, leaf }
  const outer = { nodeType: 1, leaf }
  for (const element of [inner, outer]) {
    element.contains = (node) => node === element || node === leaf || (element === outer && node === inner)
    Object.defineProperty(element, "childNodes", { get() { renderedElements.push(element); mutate(leaf); return [] } })
  }
  return { leaf, inner, outer }
}

test("two nested instances render exactly once each, whatever the mutations their own renders produce", async () => {
  const { inner, outer } = nested()
  const first = build(inner)
  const second = build(outer)
  first.connect()
  second.connect()
  await flush()

  assert.equal(renderedElements.length, 2, "un rendu par instance, aucun rendu en cascade")
  assert.deepEqual(renderedElements, [inner, outer])
  first.disconnect()
  second.disconnect()
})

test("content arriving under the inner element is rendered once, by the inner instance that holds it", async () => {
  const { leaf, inner, outer } = nested()
  const first = build(inner)
  const second = build(outer)
  first.connect()
  second.connect()
  await flush()
  renderedElements.length = 0

  mutate(leaf)
  await flush()

  // L'instance intérieure rend le contenu arrivé ; ses mutations (vues aussi par l'extérieur) sont écartées : l'extérieur ne rend pas, rien ne boucle.
  assert.deepEqual(renderedElements, [inner])
  first.disconnect()
  second.disconnect()
})

test("a mutation outside the rendering element still renders its own controller (the bound does not swallow real content)", async () => {
  const leaf = { name: "feuille" }
  const elsewhere = { name: "ailleurs" }
  const solo = { nodeType: 1, contains: (node) => node === solo || node === leaf, get childNodes() { renderedElements.push(solo); mutate(leaf); return [] } }
  const neighbour = { nodeType: 1, contains: (node) => node === neighbour || node === elsewhere, get childNodes() { renderedElements.push(neighbour); mutate(elsewhere); return [] } }
  const a = build(solo)
  const b = build(neighbour)
  a.connect()
  b.connect()
  await flush()
  renderedElements.length = 0

  mutate(elsewhere)
  await flush()

  assert.deepEqual(renderedElements, [neighbour])
  a.disconnect()
  b.disconnect()
})

test("disconnect stops the observer and further mutations render nothing", async () => {
  const { leaf, inner } = nested()
  const controller = build(inner)
  controller.connect()
  await flush()
  controller.disconnect()
  renderedElements.length = 0

  mutate(leaf)
  await flush()
  assert.equal(renderedElements.length, 0)
})
