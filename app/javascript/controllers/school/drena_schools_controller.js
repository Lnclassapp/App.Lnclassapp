// ⚡ FRONT · school/drena_schools_controller — établissements de la DRENA choisie, dans le frame « schools »
// Rôle : au changement de DRENA, pose le src du frame ; Turbo ne sait pas lier un <select> à un frame sans cette ligne
// ADR  : 0051 · UDR : 0024
import { Controller } from "@hotwired/stimulus"

const PLACEHOLDER = "__drena__"

export default class extends Controller {
  static targets = ["frame"]
  static values = { url: String }

  load({ target: { value } }) {
    if (!value) return this.disable()

    const url = this.urlValue.replace(PLACEHOLDER, encodeURIComponent(value))
    if (this.frameTarget.getAttribute("src") === url) this.frameTarget.reload()
    else this.frameTarget.src = url
  }

  // DRENA effacée : la liste affichée n'est plus envoyée, le serveur redemandera la DRENA et l'établissement.
  disable() {
    this.frameTarget.querySelectorAll("select, input").forEach((field) => { field.disabled = true })
  }
}
