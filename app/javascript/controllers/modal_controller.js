// ⚡ FRONT · modal_controller — ouvre et ferme une <dialog> native
// Rôle : showModal() fournit le piège du focus et Échap ; un clic sur le fond ferme ; valeur `open` pour une modale servie ouverte
// UDR  : 0005
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  static values = { open: Boolean }

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
}
