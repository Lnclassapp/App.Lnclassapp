// UDR-0189 §3.7 (amendement du 2026-11-27) : un numéro ou un code secret ne garde que des chiffres pendant la frappe, borné à maxlength.
// Lancer : node --test test/javascript/digits_only_controller.test.js (aucun navigateur : le champ est simulé).
import { test } from "node:test"
import assert from "node:assert/strict"
import DigitsOnlyController from "../../app/javascript/controllers/digits_only_controller.js"

function field({ value = "", maxLength = -1, type = "tel" } = {}) {
  const listeners = {}
  return {
    value, maxLength, type, caret: null,
    addEventListener: (name, fn) => { listeners[name] = fn },
    removeEventListener: (name) => { delete listeners[name] },
    setSelectionRange(start, end) { this.caret = [ start, end ] },
    type_(text) { this.value = text; listeners.input?.() },
    listeners,
  }
}

function connect(element) {
  globalThis.document = { activeElement: element }
  const controller = Object.create(DigitsOnlyController.prototype)
  Object.defineProperty(controller, "element", { value: element })
  controller.connect()
  return controller
}

test("à la frappe et au collage, tout ce qui n'est pas un chiffre tombe", () => {
  const input = connect(field({ maxLength: 10 }))

  input.element.type_("07 01-02a03.04")
  assert.equal(input.element.value, "0701020304")
  assert.deepEqual(input.element.caret, [ 10, 10 ])
})

test("la longueur est bornée à maxlength ; sans maxlength, rien n'est coupé", () => {
  const pin = connect(field({ maxLength: 4, type: "password" }))
  pin.element.type_("12a345")
  assert.equal(pin.element.value, "1234")
  assert.equal(pin.element.caret, null, "le curseur d'un champ masqué n'est pas déplacé")

  const free = connect(field())
  free.element.type_("+225 07 01 02 03 04")
  assert.equal(free.element.value, "2250701020304")
})

test("une valeur déjà propre n'est pas réécrite ; à la déconnexion, la saisie n'est plus filtrée", () => {
  const input = connect(field({ value: "0701", maxLength: 10 }))
  assert.equal(input.element.caret, null)

  input.disconnect()
  assert.equal(input.element.listeners.input, undefined)
})
