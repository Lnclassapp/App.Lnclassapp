// ADR-0051 : les contrôleurs hors ligne sortent du point d'entrée commun ; une attente par identifiant charge le morceau une seule fois.
// Lancer : node --test test/javascript/offline/lazy_controllers.test.js
import { test } from "node:test"
import assert from "node:assert/strict"
import { OFFLINE_IDENTIFIERS, registerOfflineControllers } from "../../../app/javascript/offline/lazy_controllers.js"

function fakeApplication() {
  const registered = new Map()
  return { registered, register(identifier, controller) { registered.set(identifier, controller) } }
}

function connectStub(application, identifier) {
  const stub = new (application.registered.get(identifier))({})
  Object.defineProperty(stub, "application", { value: application })
  stub.connect()
}

test("une attente par identifiant ; la première connexion charge le morceau une fois et enregistre les vrais contrôleurs", async () => {
  const application = fakeApplication()
  let loads = 0
  const real = Object.fromEntries(OFFLINE_IDENTIFIERS.map((identifier) => [ identifier, class {} ]))
  registerOfflineControllers(application, async () => { loads += 1; return { default: real } })

  assert.deepEqual([ ...application.registered.keys() ].sort(), [ ...OFFLINE_IDENTIFIERS ].sort())
  connectStub(application, "offline-session")
  connectStub(application, "offline-sync")
  await new Promise((resolve) => setTimeout(resolve, 0))

  assert.equal(loads, 1)
  OFFLINE_IDENTIFIERS.forEach((identifier) => assert.equal(application.registered.get(identifier), real[identifier]))
  assert.equal(typeof globalThis.__lnclassStimulusController, "function")
})
