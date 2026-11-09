// ⚡ FRONT · print — ouvre la boîte d'impression du navigateur depuis un bouton (rapport pédagogique, planche des cartes)
// Rôle : pas d'`onclick` (CSP stricte) ; un bouton cible reste caché tant que le contrôleur n'est pas connecté ; l'impression est mise en page par les classes `print:` des vues
// ADR  : 0126 (contexte billing, §4.2) · UDR : 0159 §3.4, XXXX (assistants du suivi, « Rapport pédagogique »)
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
