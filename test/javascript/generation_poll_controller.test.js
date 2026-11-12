// UDR-XXXX (assistants du suivi) : le contrôleur generation-poll recharge le frame toutes les 2 s, 45 s au plus, puis montre l'état d'attente dépassé.
// Lancer : node --test test/javascript/generation_poll_controller.test.js (aucun navigateur : les valeurs Stimulus et le DOM sont simulés).
import { test, mock, afterEach } from "node:test"
import assert from "node:assert/strict"
import GenerationPollController from "../../app/javascript/controllers/generation_poll_controller.js"

afterEach(() => mock.timers.reset())

function build({ interval = 2000, timeout = 45000, src = null } = {}) {
  const frame = { reloads: 0, attrs: { src }, reload() { this.reloads++ }, getAttribute(n) { return this.attrs[n] ?? null }, setAttribute(n, v) { this.attrs[n] = v }, removeAttribute(n) { delete this.attrs[n] } }
  const waiting = { hidden: false }
  const timedOut = { hidden: true }
  const controller = Object.create(GenerationPollController.prototype)
  Object.defineProperties(controller, {
    element: { value: { closest: () => frame } },
    urlValue: { value: "/teams/generations/abc" },
    intervalValue: { value: interval },
    timeoutValue: { value: timeout },
    hasWaitingTarget: { value: true }, waitingTarget: { value: waiting },
    hasTimedOutTarget: { value: true }, timedOutTarget: { value: timedOut },
  })
  return { controller, frame, waiting, timedOut }
}

test("sets the frame source on the first tick, then reloads it every interval", () => {
  mock.timers.enable({ apis: ["setInterval", "setTimeout"] })
  const { controller, frame } = build()
  controller.connect()

  mock.timers.tick(2000)
  assert.equal(frame.attrs.src, "/teams/generations/abc")
  assert.equal(frame.reloads, 0)
  mock.timers.tick(2000)
  assert.equal(frame.reloads, 1)
  controller.disconnect()
  mock.timers.reset()
})

test("stops at the deadline and reveals the timed-out state", () => {
  mock.timers.enable({ apis: ["setInterval", "setTimeout"] })
  const { controller, frame, waiting, timedOut } = build({ src: "/teams/generations/abc" })
  controller.connect()

  mock.timers.tick(45000)
  assert.equal(timedOut.hidden, false)
  assert.equal(waiting.hidden, true)
  const reloads = frame.reloads
  mock.timers.tick(10000)
  assert.equal(frame.reloads, reloads)
  mock.timers.reset()
})

test("disconnect stops the polling", () => {
  mock.timers.enable({ apis: ["setInterval", "setTimeout"] })
  const { controller, frame } = build({ src: "/teams/generations/abc" })
  controller.connect()
  controller.disconnect()

  mock.timers.tick(10000)
  assert.equal(frame.reloads, 0)
  mock.timers.reset()
})
