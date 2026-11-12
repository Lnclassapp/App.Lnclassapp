// UDR-0005 (modale) : submitEnd ferme la modale après un envoi réussi, sauf sous un conteneur [data-modal-keep-open] (brouillon WhatsApp, dictée).
// Lancer : node --test test/javascript/modal_controller.test.js (aucun navigateur : les valeurs Stimulus et le DOM sont simulés).
import { test } from "node:test"
import assert from "node:assert/strict"
import ModalController from "../../app/javascript/controllers/modal_controller.js"

function build() {
  const dialog = { open: true, closes: 0, close() { this.closes++ } }
  const controller = Object.create(ModalController.prototype)
  Object.defineProperty(controller, "dialogTarget", { value: dialog })
  return { controller, dialog }
}

// Un formulaire dont `closest` ne trouve le conteneur « garder ouverte » que s'il en a un.
const submitted = ({ success, keepOpen = false }) => ({
  detail: { success },
  target: { closest: (selector) => (keepOpen && selector === "[data-modal-keep-open]" ? {} : null) },
})

test("closes the dialog after a successful submit by default", () => {
  const { controller, dialog } = build()
  controller.submitEnd(submitted({ success: true }))
  assert.equal(dialog.closes, 1)
})

test("stays open after a successful submit inside [data-modal-keep-open]", () => {
  const { controller, dialog } = build()
  controller.submitEnd(submitted({ success: true, keepOpen: true }))
  assert.equal(dialog.closes, 0)
})

test("stays open after a failed submit", () => {
  const { controller, dialog } = build()
  controller.submitEnd(submitted({ success: false }))
  assert.equal(dialog.closes, 0)
})
