// UDR-XXXX (assistants du suivi) : le contrôleur print montre son bouton une fois connecté et lance l'impression du navigateur.
// Lancer : node --test test/javascript/print_controller.test.js (aucun navigateur : les cibles Stimulus et window sont simulées).
import { test, mock } from "node:test"
import assert from "node:assert/strict"
import PrintController from "../../app/javascript/controllers/print_controller.js"

test("connect shows the print buttons", () => {
  const buttons = [{ hidden: true }, { hidden: true }]
  const controller = Object.create(PrintController.prototype)
  Object.defineProperty(controller, "buttonTargets", { value: buttons })

  controller.connect()

  assert.deepEqual(buttons.map((button) => button.hidden), [false, false])
})

test("print opens the browser print dialog", () => {
  const print = mock.fn()
  globalThis.window = { print }

  Object.create(PrintController.prototype).print()

  assert.equal(print.mock.callCount(), 1)
  delete globalThis.window
})
