// ⚡ FRONT · course_sheet/simple_toggle_controller — bascule « Explications simples : oui / non » de la fiche de cours
// Rôle : pose data-simple sur l'écran (le CSS masque les reformulations) et met à jour le bouton ; sans JavaScript, tout reste visible
// ADR  : 0110-fiche-de-cours-en-donnees-importees · UDR : 0137-fiche-de-cours-a-l-identique-des-maquettes
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "button" ]
  static values = { labelOn: String, labelOff: String }

  toggle() {
    const on = this.element.dataset.simple !== "true"
    this.element.dataset.simple = String(on)
    this.buttonTarget.setAttribute("aria-pressed", String(on))
    this.buttonTarget.textContent = on ? this.labelOnValue : this.labelOffValue
  }
}
