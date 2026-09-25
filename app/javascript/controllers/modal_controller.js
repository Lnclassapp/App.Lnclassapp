// ⚡ FRONT · modal_controller — ouvre et ferme une <dialog> native, y compris chargée dans le frame « modal »
// Rôle : showModal() fournit le piège du focus et Échap ; fond cliquable ; fermeture après un envoi réussi ; frame vidé à la fermeture
// UDR  : 0005, 0006
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  static values = { open: Boolean }

  // Une modale servie ouverte (open: true) s'ouvre dès son arrivée : c'est le cas du contenu chargé dans le frame « modal ».
  connect() {
    if (this.openValue) this.open()
  }

  open() {
    if (!this.dialogTarget.open) this.dialogTarget.showModal()
  }

  close() {
    if (this.dialogTarget.open) this.dialogTarget.close()
  }

  // Le clic tombe sur la <dialog> elle-même seulement hors de son contenu, c'est-à-dire sur le fond.
  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  // Envoi réussi (réponse Turbo Stream) : on ferme. Un 422 re-rend la modale dans le frame, qui se rouvre avec ses erreurs.
  submitEnd(event) {
    if (event.detail.success) this.close()
  }

  // Chargée dans le frame « modal », la modale fermée libère le frame : le même lien pourra la recharger.
  closed() {
    const frame = this.element.closest("turbo-frame#modal")
    if (!frame) return

    frame.removeAttribute("src")
    frame.replaceChildren()
  }
}
