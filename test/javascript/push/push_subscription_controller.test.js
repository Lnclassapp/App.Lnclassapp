// notifications-push (UDR §3.1, §3.2) : seul « denied » vaut « bloquées » ; une erreur est écrite dans la console avant l'affichage du message.
// Lancer : node --test test/javascript/push/push_subscription_controller.test.js (aucun navigateur : Stimulus et le DOM sont simulés).
import { test, beforeEach } from "node:test"
import assert from "node:assert/strict"
import PushSubscriptionController from "../../../app/javascript/push/push_subscription_controller.js"

const MESSAGES = { blocked: "Bloquées", error: "Oups", loading: "…", activated: "Activées", other_device: "Autre appareil", blocked_detail: "Détail" }

let warned

beforeEach(() => {
  warned = []
  console.warn = (...args) => warned.push(args)
  globalThis.window = { PushManager: {} }
  globalThis.document = { querySelector: () => null }
})

function build({ permission, requestPermission, mode = "card", subscribeFails = false } = {}) {
  globalThis.Notification = { permission, requestPermission: requestPermission || (async () => permission) }
  globalThis.window.Notification = globalThis.Notification
  const registration = { pushManager: { getSubscription: async () => null, subscribe: async () => { if (subscribeFails) throw new Error("boom"); return { toJSON: () => ({ endpoint: "https://fcm.googleapis.com/x", keys: {} }) } } } }
  Object.defineProperty(globalThis, "navigator", { value: { serviceWorker: { ready: Promise.resolve(registration) } }, configurable: true })
  globalThis.fetch = async () => ({ ok: true })
  const status = { textContent: "", classList: { added: [], add(name) { this.added.push(name) } } }
  const accept = { hidden: false, disabled: false, textContent: "Oui", toggleAttribute() {} }
  const controller = Object.create(PushSubscriptionController.prototype)
  Object.defineProperties(controller, {
    modeValue: { value: mode }, stateValue: { value: "on", writable: true }, messagesValue: { value: MESSAGES },
    vapidKeyValue: { value: "AQAB" }, subscriptionsUrlValue: { value: "/push_subscriptions" }, preferenceUrlValue: { value: "/push_preference" },
    statusTarget: { value: status }, hasAcceptTarget: { value: true }, acceptTarget: { value: accept },
    hasValueTarget: { value: true }, valueTarget: { value: { textContent: "" } },
    contentTarget: { value: { hidden: false } }, successTarget: { value: { hidden: true } }
  })
  return { controller, status, accept }
}

test("a closed permission box (default) is not shown as blocked and leaves the button usable", async () => {
  const { controller, status, accept } = build({ permission: "default" })
  await controller.accept()
  assert.equal(status.textContent, "")
  assert.equal(accept.hidden, false)
  assert.equal(accept.disabled, false)
})

test("a denied permission is shown as blocked", async () => {
  const { controller, status, accept } = build({ permission: "denied" })
  await controller.accept()
  assert.equal(status.textContent, MESSAGES.blocked)
  assert.equal(accept.hidden, true)
})

test("a failure is written to the console before the error message is shown", async () => {
  const { controller, status } = build({ permission: "granted", subscribeFails: true })
  await controller.accept()
  assert.equal(warned.length, 1)
  assert.equal(warned[0][0].message, "boom")
  assert.equal(status.textContent, MESSAGES.error)
})

test("the profile reconciliation also writes a failure to the console", async () => {
  const { controller, status } = build({ permission: "granted", mode: "row", subscribeFails: true })
  await controller.reconcile()
  assert.equal(warned.length, 1)
  assert.equal(status.textContent, MESSAGES.error)
})

test("reactivating writes a failed request to the console", async () => {
  const { controller, status } = build({ permission: "granted", mode: "row" })
  globalThis.fetch = async () => ({ ok: false, status: 500 })
  await controller.reactivate({ preventDefault() {} })
  assert.equal(warned.length, 1)
  assert.equal(status.textContent, MESSAGES.error)
})
