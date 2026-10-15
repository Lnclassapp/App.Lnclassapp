// ⚡ FRONT · teams/question_kind_controller — le choix du type d'une question montre les champs de ce type, et seulement eux
// Rôle : un panneau par famille de types (choix, trous, nombre, ordre, relier) ; les autres sont cachés et désactivés, donc pas envoyés
// UDR  : 0017, 0087 §3.7 · ADR : 0091 §4.5 · sans JavaScript, le panneau du type enregistré reste le seul actif
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "panel"]
  static values = { kinds: Object }

  switch() {
    const kind = this.kindsValue[this.selectTarget.value]
    this.panelTargets.forEach((panel) => {
      const active = panel.dataset.kind === kind
      panel.hidden = !active
      panel.disabled = !active
    })
  }
}
