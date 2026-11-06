// UDR-XXXX (assistants du suivi) : le contrôleur whatsapp-link garde le lien wa.me, le texte à copier et le compteur d'accord avec le brouillon.
// Lancer : node --test test/javascript/whatsapp_link_controller.test.js (aucun navigateur : les valeurs Stimulus et le DOM sont simulés).
import { test } from "node:test"
import assert from "node:assert/strict"
import WhatsappLinkController from "../../app/javascript/controllers/whatsapp_link_controller.js"

function build({ text = "Bonjour", phone = "0701020304", withLink = true, withRecipient = true, withCounter = true } = {}) {
  const copy = { dataset: {} }
  const link = { attrs: {}, setAttribute(name, value) { this.attrs[name] = value } }
  const counter = { textContent: "" }
  const controller = Object.create(WhatsappLinkController.prototype)
  Object.defineProperties(controller, {
    element: { value: { querySelectorAll: () => [copy] } },
    baseValue: { value: "https://wa.me/" },
    prefixValue: { value: "225" },
    maxValue: { value: 600 },
    counterTemplateValue: { value: "%{count} / %{max} caractères" },
    textTarget: { value: { value: text } },
    hasRecipientTarget: { value: withRecipient }, recipientTarget: { value: { value: phone } },
    hasLinkTarget: { value: withLink }, linkTarget: { value: link },
    hasCounterTarget: { value: withCounter }, counterTarget: { value: counter },
  })
  return { controller, copy, link, counter }
}

test("builds the wa.me link towards the chosen contact with the encoded text", () => {
  const { controller, link } = build({ text: "Bonjour & merci, à bientôt ?" })
  controller.update()
  assert.equal(link.attrs.href, `https://wa.me/2250701020304?text=${encodeURIComponent("Bonjour & merci, à bientôt ?")}`)
})

test("follows the edited text and the chosen recipient", () => {
  const { controller, link } = build({ text: "Un" })
  controller.textTarget.value = "Deux lignes\nici"
  controller.recipientTarget.value = "0501020304"
  controller.update()
  assert.equal(link.attrs.href, "https://wa.me/2250501020304?text=Deux%20lignes%0Aici")
})

test("hands the edited text to the copy button and updates the counter", () => {
  const { controller, copy, counter } = build({ text: "Bonjour" })
  controller.update()
  assert.equal(copy.dataset.clipboardTextValue, "Bonjour")
  assert.equal(counter.textContent, "7 / 600 caractères")
})

test("connect brings everything in line with the server-rendered text", () => {
  const { controller, copy } = build({ text: "Salut" })
  controller.connect()
  assert.equal(copy.dataset.clipboardTextValue, "Salut")
})

test("without contact, link or counter, only the copy text is kept", () => {
  const { controller, copy } = build({ text: "Seul", withLink: false, withRecipient: false, withCounter: false })
  controller.update()
  assert.equal(copy.dataset.clipboardTextValue, "Seul")
  assert.equal(controller.href("x"), "https://wa.me/225?text=x")
})
