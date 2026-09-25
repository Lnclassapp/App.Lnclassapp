// ⚡ FRONT · rich_text_editor_controller — éditeur riche (Trix) des cours et des fiches, sans pièce jointe
// Rôle : charge Trix à la demande, hors du bundle commun ; refuse tout fichier ; la page d'édition pose le CSS « trix »
// ADR  : 0047, 0049, 0051 · usage : content_for :head, stylesheet_link_tag("trix") ; <div data-controller="rich-text-editor"> + rich_text_area
import { Controller } from "@hotwired/stimulus"

// V1 accepts no attachment: nothing reaches the bucket from the editor, so there is no
// direct upload and @rails/actiontext is not loaded. The file button is hidden by CSS.
const refuseFile = (event) => event.preventDefault()
const dropAttachment = (event) => event.attachment.remove()

export default class extends Controller {
  async connect() {
    this.element.addEventListener("trix-file-accept", refuseFile)
    this.element.addEventListener("trix-attachment-add", dropAttachment)
    await import("trix")
  }

  disconnect() {
    this.element.removeEventListener("trix-file-accept", refuseFile)
    this.element.removeEventListener("trix-attachment-add", dropAttachment)
  }
}
