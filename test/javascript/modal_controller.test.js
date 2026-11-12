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

// assignation-catalogue-modale-jours : l'événement `close` arrive une tâche après dialog.close(). Si une autre modale a
// commencé à se charger dans le frame entre les deux (frame `busy`), closed() ne doit ni retirer `src` (Turbo annulerait
// la requête) ni vider le frame : la nouvelle modale n'arriverait jamais.
function buildInFrame({ busy }) {
  const frame = {
    removed: [], cleared: 0,
    hasAttribute: (name) => name === "busy" && busy,
    removeAttribute(name) { this.removed.push(name) },
    replaceChildren() { this.cleared++ },
  }
  const { controller, dialog } = build()
  dialog.open = false
  Object.defineProperty(controller, "element", { value: { closest: (selector) => (selector === "turbo-frame#modal" ? frame : null) } })
  return { controller, frame }
}

test("closed() frees the modal frame when nothing else is loading in it", () => {
  const { controller, frame } = buildInFrame({ busy: false })
  controller.closed()
  assert.deepEqual(frame.removed, [ "src" ])
  assert.equal(frame.cleared, 1)
})

test("closed() leaves the modal frame alone while the next modal is loading in it", () => {
  const { controller, frame } = buildInFrame({ busy: true })
  controller.closed()
  assert.deepEqual(frame.removed, [])
  assert.equal(frame.cleared, 0)
})
