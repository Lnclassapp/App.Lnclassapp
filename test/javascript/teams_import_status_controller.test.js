// Règle « contrôleur Stimulus borné » (docs/guide/conventions.md §7) : teams/import-status recharge le frame toutes les secondes, 600 fois au plus (10 min), puis s'arrête.
// Lancer : node --test test/javascript/teams_import_status_controller.test.js (aucun navigateur : le frame, les valeurs Stimulus et l'horloge sont simulés).
import { test, mock, afterEach } from "node:test"
import assert from "node:assert/strict"
import ImportStatusController from "../../app/javascript/controllers/teams/import_status_controller.js"

const MAX_POLLS = 600
afterEach(() => mock.timers.reset())

// Un frame qui, à chaque requête (src posé, puis reload), se remplace par le contenu servi : `status` dit l'état de l'import à ce moment-là.
function build({ status = () => "importing" } = {}) {
  const requests = []
  const state = { dataset: {} }
  const controller = Object.create(ImportStatusController.prototype)
  const frame = {
    src: null,
    reload() { requests.push("reload"); render() },
  }
  Object.defineProperty(frame, "src", {
    get() { return this._src ?? null },
    set(value) { this._src = value; requests.push("src"); render() },
  })
  const render = () => { state.dataset.status = status(requests.length); controller.stateTargetConnected(state) }
  Object.defineProperties(controller, { element: { value: frame }, urlValue: { value: "/teams/imports/abc" } })
  return { controller, requests, state, render }
}

const tick = (times) => { for (let i = 0; i < times; i++) mock.timers.tick(1000) }

test("polls exactly 600 times while the import keeps running, then stops and leaves the last state", () => {
  mock.timers.enable({ apis: ["setTimeout"] })
  const { controller, requests, state, render } = build()
  render() // premier état affiché par le serveur
  tick(MAX_POLLS)
  assert.equal(requests.length, MAX_POLLS)

  tick(MAX_POLLS * 2)
  assert.equal(requests.length, MAX_POLLS, "aucune requête de plus après l'échéance")
  assert.equal(state.dataset.status, "importing", "le dernier état reste affiché")
  controller.disconnect()
})

test("the first poll sets the frame source, the next ones reload it", () => {
  mock.timers.enable({ apis: ["setTimeout"] })
  const { controller, requests, render } = build()
  render()
  tick(3)
  assert.deepEqual(requests, ["src", "reload", "reload"])
  controller.disconnect()
})

test("stops as soon as the import is finished, long before the ceiling", () => {
  mock.timers.enable({ apis: ["setTimeout"] })
  const { controller, requests, render } = build({ status: (count) => (count >= 5 ? "done" : "importing") })
  render()
  tick(50)
  assert.equal(requests.length, 5)
  controller.disconnect()
})

test("disconnect cancels the pending timer", () => {
  mock.timers.enable({ apis: ["setTimeout"] })
  const { controller, requests, render } = build()
  render()
  controller.disconnect()
  tick(10)
  assert.equal(requests.length, 0)
})
