// notifications-push : le contrôleur d'abonnement est chargé à la demande, une seule fois, et une erreur de chargement se réessaie.
import { test, beforeEach } from "node:test"
import assert from "node:assert/strict"

globalThis.window = globalThis
const { registerPushController, loadPushController, PUSH_IDENTIFIER } = await import("../../../app/javascript/push/lazy_controller.js").catch(async () => {
  // @hotwired/stimulus s'importe sans navigateur ; en cas d'échec, le test échoue plus bas avec un message clair.
  throw new Error("lazy_controller.js doit se charger sous Node")
})

const fakeApplication = () => ({ registered: {}, register(name, controller) { this.registered[name] = controller } })

test("l'attente est enregistrée sous l'identifiant du vrai contrôleur", () => {
  const application = fakeApplication()
  registerPushController(application)

  assert.equal(PUSH_IDENTIFIER, "push-subscription")
  assert.equal(typeof application.registered[PUSH_IDENTIFIER], "function")
})

test("le vrai contrôleur remplace l'attente, et n'est importé qu'une fois", async () => {
  const application = fakeApplication()
  class Real {}
  let calls = 0
  const load = async () => { calls += 1; return { default: Real } }

  await Promise.all([ loadPushController(application, load), loadPushController(application, load) ])

  assert.equal(application.registered[PUSH_IDENTIFIER], Real)
  assert.equal(calls, 1)
})
