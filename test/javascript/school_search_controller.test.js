// ADR-XXXX-recherche-etablissement, UDR-XXXX-champ-etablissement (§3 Comportement) : le champ « Ton établissement » cherche
// 300 ms après la dernière frappe, jamais sous 2 lettres ni chiffres ; Entrée cherche tout de suite sans envoyer le formulaire ;
// une nouvelle frappe retire le choix fait (« cleared ») ; un résultat coché replie la liste sur lui et émet « picked ».
// Lancer : node --test test/javascript/school_search_controller.test.js (aucun navigateur : le frame et ses options sont simulés).
import { test, mock, beforeEach, afterEach } from "node:test"
import assert from "node:assert/strict"
import SchoolSearchController from "../../app/javascript/controllers/school/school_search_controller.js"

const URL_VALUE = "/schools/search?scope=teacher_registration"

function fakeFrame({ checked = null, options = [] } = {}) {
  const attributes = new Map()
  const frame = {
    reloads: 0,
    children: ["ancienne liste"],
    more: { removed: false, remove() { this.removed = true } },
    getAttribute: (name) => attributes.get(name) ?? null,
    removeAttribute: (name) => attributes.delete(name),
    reload() { frame.reloads += 1 },
    replaceChildren(...nodes) { frame.children = nodes },
    querySelector(selector) {
      if (selector.includes("radio")) return checked
      if (selector.includes("more")) return frame.more
      return null
    },
    querySelectorAll: () => options,
  }
  Object.defineProperty(frame, "src", { get: () => attributes.get("src"), set: (url) => attributes.set("src", url) })
  return frame
}

function connect({ value = "", frame = fakeFrame(), error = null } = {}) {
  const controller = Object.create(SchoolSearchController.prototype)
  const dispatched = []
  Object.defineProperties(controller, {
    inputTarget: { value: { value } },
    frameTarget: { value: frame },
    errorTarget: { value: error },
    urlValue: { value: URL_VALUE },
    delayValue: { value: 300 },
    dispatch: { value: (name, options = {}) => dispatched.push([ name, options.detail ]) },
  })
  return { controller, frame, dispatched }
}

beforeEach(() => {
  globalThis.document = { baseURI: "https://lnclass.test/register" }
  mock.timers.enable({ apis: ["setTimeout"] })
})
afterEach(() => { mock.timers.reset(); delete globalThis.document })

test("cherche 300 ms après la dernière frappe, avec la saisie dans q", () => {
  const { controller, frame } = connect({ value: "  ND paix tiassalé " })
  controller.queue()
  mock.timers.tick(299)
  assert.equal(frame.src, undefined)
  controller.queue()
  mock.timers.tick(299)
  assert.equal(frame.src, undefined, "le délai repart à chaque frappe")
  mock.timers.tick(1)
  const url = new URL(frame.src)
  assert.equal(url.pathname, "/schools/search")
  assert.equal(url.searchParams.get("scope"), "teacher_registration")
  assert.equal(url.searchParams.get("q"), "ND paix tiassalé")
})

test("sous 2 lettres ou chiffres (espaces et ponctuation ne comptent pas), le frame se vide sans requête", () => {
  for (const value of ["", "a", " é ", "a-.'"]) {
    const frame = fakeFrame()
    frame.src = "https://lnclass.test/schools/search?q=ancien"
    const { controller } = connect({ value, frame })
    controller.search()
    assert.equal(frame.getAttribute("src"), null, value)
    assert.deepEqual(frame.children, [], value)
  }
})

test("la même recherche relance le frame au lieu de reposer son src", () => {
  const { controller, frame } = connect({ value: "lycee" })
  controller.search()
  controller.search()
  assert.equal(frame.reloads, 1)
})

test("Entrée cherche tout de suite, sans envoyer le formulaire hôte", () => {
  const { controller, frame } = connect({ value: "cocody" })
  controller.queue()
  let prevented = false
  controller.now({ preventDefault: () => { prevented = true } })
  assert.ok(prevented)
  assert.match(frame.src, /q=cocody/)
  const src = frame.src
  mock.timers.tick(300)
  assert.equal(frame.reloads, 0, "la recherche en attente est annulée")
  assert.equal(frame.src, src)
})

test("une nouvelle frappe retire le choix fait et émet « cleared » une fois", () => {
  const radio = { checked: true }
  const { controller, dispatched } = connect({ value: "lyc", frame: fakeFrame({ checked: radio }) })
  controller.queue()
  assert.equal(radio.checked, false)
  assert.deepEqual(dispatched, [[ "cleared", undefined ]])

  const { controller: other, dispatched: none } = connect({ value: "lyc" })
  other.queue()
  assert.deepEqual(none, [], "rien à retirer, rien d'émis")
})

test("un résultat coché replie la liste sur lui, retire « Plus de 20 » et émet « picked » avec son identifiant", () => {
  const target = { value: "sch_abc123" }
  const option = (own) => ({ removed: false, contains: (node) => own && node === target, remove() { this.removed = true } })
  const options = [ option(false), option(true), option(false) ]
  const frame = fakeFrame({ options })
  const { controller, dispatched } = connect({ frame })
  controller.pick({ target })
  assert.deepEqual(options.map((o) => o.removed), [ true, false, true ])
  assert.ok(frame.more.removed)
  assert.deepEqual(dispatched, [[ "picked", { publicId: "sch_abc123" } ]])
})

test("Entrée après un choix le retire aussi : les hôtes vident niveaux et classes", () => {
  const radio = { checked: true }
  const { controller, dispatched } = connect({ value: "lycee", frame: fakeFrame({ checked: radio }) })
  controller.now({ preventDefault() {} })
  assert.equal(radio.checked, false)
  assert.deepEqual(dispatched, [[ "cleared", undefined ]])
})

test("un frame qui ne revient pas : le choix se retire, l'état d'erreur s'affiche, « Réessayer » relance la même recherche", () => {
  const radio = { checked: true }
  const link = { href: null, setAttribute(name, value) { this[name] = value } }
  const content = { querySelectorAll: () => [ link ] }
  const error = { content: { cloneNode: () => content } }
  const frame = fakeFrame({ checked: radio })
  frame.src = "https://lnclass.test/schools/search?q=paix"
  const { controller, dispatched } = connect({ frame, error })
  let prevented = false
  controller.missing({ preventDefault: () => { prevented = true } })
  assert.ok(prevented)
  assert.equal(radio.checked, false)
  assert.deepEqual(dispatched, [[ "cleared", undefined ]])
  assert.equal(link.href, "https://lnclass.test/schools/search?q=paix")
  assert.deepEqual(frame.children, [ content ])
})

test("disconnect annule la recherche en attente", () => {
  const { controller, frame } = connect({ value: "lycee" })
  controller.queue()
  controller.disconnect()
  mock.timers.tick(300)
  assert.equal(frame.src, undefined)
})
