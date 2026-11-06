// ⚡ FRONT · print — imprime la page (rapport pédagogique) ; le bouton reste caché tant que le contrôleur n'est pas connecté
// Rôle : pas d'`onclick` (CSP stricte) ; la mise en page d'impression est portée par les classes `print:` des vues
// UDR  : XXXX (assistants du suivi, « Rapport pédagogique »)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.buttonTargets.forEach((button) => { button.hidden = false })
  }

  print() {
    window.print()
  }
}
