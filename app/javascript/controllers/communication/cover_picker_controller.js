// ⚡ FRONT · communication/cover_picker_controller — couverture d'un article : réduite, envoyée à l'endpoint de l'équipe, montrée
// Rôle : lib/image_upload à la demande ; pose cover_public_id, jamais le fichier dans le formulaire ; refus nommé ; l'enregistrement attend
// ADR  : 0049, 0051, 0060, 0074 · UDR : 0067 (§3.4.1, §3.4.3)
import { Controller } from "@hotwired/stimulus"

const fill = (template, values) => template.replace(/%\{(\w+)\}/g, (token, key) => values[key] ?? token)

export default class extends Controller {
  static targets = ["input", "preview", "placeholder", "remove", "status", "spinner", "error", "id"]
  // uploadTimeout: delay before an upload that never answers is given up, in ms; absent, lib/image_upload's (60 s).
  static values = { uploadUrl: String, maxSide: Number, maxBytes: Number, accept: Array, messages: Object, uploadTimeout: Number }

  connect() {
    this.form = this.element.closest("form")
    this.form?.addEventListener("submit", this.hold)
  }

  disconnect() {
    this.form?.removeEventListener("submit", this.hold)
  }

  // « Enregistrer » during the upload: the article is saved once the cover is sent. Refused or failed, the article is not
  // saved (it would leave without the cover, the refusal hidden by the closing modal): the refusal says so and takes the focus.
  hold = (event) => {
    if (!this.pending) return

    event.preventDefault()
    event.stopImmediatePropagation()
    this.showStatus(this.messagesValue.waiting)
    const { submitter } = event
    this.pending.then((sent) => {
      if (sent) return this.form.requestSubmit(submitter)

      this.showError(`${this.errorTarget.querySelector("span").textContent} ${this.messagesValue.not_saved}`)
      this.errorTarget.focus()
    })
  }

  pick() {
    const file = this.inputTarget.files[0]
    if (!file) return

    this.showError(null)
    this.element.setAttribute("aria-busy", "true")
    this.showStatus(this.messagesValue.uploading)
    this.pending = this.send(file).finally(() => {
      this.pending = null
      this.inputTarget.value = ""
      this.element.removeAttribute("aria-busy")
      this.showStatus(null)
    })
  }

  // The previous cover stays in place on a refusal. → true if the cover is sent, false if it was refused or failed.
  async send(file) {
    const messages = this.messagesValue
    try {
      const { prepareImage, uploadImage } = await import("../../lib/image_upload")
      const ready = await prepareImage(file, { accept: this.acceptValue, maxSide: this.maxSideValue, maxBytes: this.maxBytesValue })
      const image = await uploadImage(ready, { url: this.uploadUrlValue, timeout: this.uploadTimeoutValue || undefined })
      this.idTarget.value = image.public_id
      this.previewTarget.src = image.url
      this.show(true)
      return true
    } catch ({ reason, detail }) {
      this.showError(fill(messages.refused, { name: file.name, reason: detail || messages[reason] || messages.failed }))
      return false
    }
  }

  clear() {
    this.idTarget.value = ""
    this.previewTarget.removeAttribute("src")
    this.show(false)
    this.inputTarget.focus()
  }

  show(cover) {
    this.previewTarget.hidden = !cover
    this.removeTarget.hidden = !cover
    this.placeholderTarget.hidden = cover
  }

  showStatus(text) {
    this.statusTarget.replaceChildren()
    if (text) this.statusTarget.append(this.spinnerTarget.content.cloneNode(true), text)
  }

  // The refusal is linked to the file field; the server's error on the cover, if any, keeps it invalid.
  showError(text) {
    const id = this.errorTarget.id
    const describedBy = (this.inputTarget.getAttribute("aria-describedby") || "").split(" ").filter((token) => token && token !== id)
    this.errorTarget.hidden = !text
    this.errorTarget.querySelector("span").textContent = text || ""
    if (text) describedBy.push(id)
    this.inputTarget.setAttribute("aria-describedby", describedBy.join(" "))
    if (text) this.inputTarget.setAttribute("aria-invalid", "true")
    else if (!describedBy.some((token) => token.endsWith("_error"))) this.inputTarget.removeAttribute("aria-invalid")
  }
}
