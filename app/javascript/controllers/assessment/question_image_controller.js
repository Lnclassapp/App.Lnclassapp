// ⚡ FRONT · assessment/question_image_controller — l'image d'une question dans le formulaire d'exercice (UDR-0129 §3.2)
// Rôle : choisir, alléger (300 Ko, 1200 px) et envoyer l'image ; la description annoncée devient son texte de remplacement ; retirer l'image ou la description
// ADR  : 0060, 0104 · UDR : 0129 · lib/image_upload chargé par import(), à la demande
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["publicId", "description", "preview", "img", "alt", "missing", "expected", "addPlain", "file", "status"]
  static values = { uploadUrl: String, accept: Array, maxSide: Number, maxBytes: Number, messages: Object }

  pick() {
    this.fileTarget.click()
  }

  async upload() {
    const file = this.fileTarget.files[0]
    if (!file) return
    this.fileTarget.value = ""
    this.say(this.messagesValue.uploading)
    try {
      const { prepareImage, uploadImage } = await import("../../lib/image_upload")
      const ready = await prepareImage(file, { accept: this.acceptValue, maxSide: this.maxSideValue, maxBytes: this.maxBytesValue, squeeze: true })
      const image = await uploadImage(ready, { url: this.uploadUrlValue, field: "question_image[file]" })
      this.publicIdTarget.value = image.public_id
      this.imgTarget.src = image.url
      // The description announced by the import says what the image shows: it becomes its alternative text.
      if (!this.altTarget.value.trim()) this.altTarget.value = this.descriptionTarget.value
      this.say("")
      this.show()
      this.mark()
      this.altTarget.focus()
    } catch (error) {
      this.say(this.reason(error), true)
    }
  }

  remove() {
    this.publicIdTarget.value = ""
    this.altTarget.value = ""
    this.show()
  }

  // « Cette question n'a pas besoin d'image » : the announced image is dropped, the question publishes without it.
  dropDescription() {
    this.descriptionTarget.value = ""
    this.show()
  }

  mark() {
    this.missingTarget.hidden = this.altTarget.value.trim() !== ""
  }

  show() {
    const hasImage = this.publicIdTarget.value !== ""
    const announced = this.descriptionTarget.value !== ""
    this.previewTarget.hidden = !hasImage
    this.expectedTarget.hidden = hasImage || !announced
    this.addPlainTarget.hidden = hasImage || announced
  }

  say(text, error = false) {
    this.statusTarget.textContent = text
    this.statusTarget.classList.toggle("text-error", error)
    this.statusTarget.classList.toggle("text-mute", !error)
    if (error) this.statusTarget.setAttribute("role", "alert")
    else this.statusTarget.removeAttribute("role")
  }

  // Refusal reasons of lib/image_upload: a key of the messages, or « server » with the French text of the server.
  reason(error) {
    const messages = this.messagesValue
    const detail = error?.reason === "server" ? error.detail : messages[error?.reason] || messages.failed
    return messages.refused.replace("%{reason}", detail)
  }
}
