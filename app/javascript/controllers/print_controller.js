// ⚡ FRONT · print_controller — ouvre la boîte d'impression du navigateur depuis un bouton
// Rôle : le bouton « Imprimer » de la planche des cartes d'activation appelle window.print() ; masqué à l'impression par la vue
// ADR  : 0126 (contexte billing, §4.2) · UDR : 0159 §3.4
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  print() {
    window.print()
  }
}
