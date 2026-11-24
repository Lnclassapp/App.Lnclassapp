// ⚡ FRONT · soon_controller — « Bientôt disponible » pour une entrée sans écran
// Rôle : `say` écrit le message dans la cible `status` (role=status, lu par les lecteurs d'écran), puis l'efface après 4 s
// UDR  : XXXX (accueil-eleve-grille-plus §3)
import { Controller } from "@hotwired/stimulus"

const CLEAR_AFTER_MS = 4000

export default class extends Controller {
  static targets = [ "status" ]
  static values = { message: String }

  disconnect() {
    clearTimeout(this.timer)
  }

  say() {
    clearTimeout(this.timer)
    this.statusTarget.textContent = this.messageValue
    this.timer = setTimeout(() => { this.statusTarget.textContent = "" }, CLEAR_AFTER_MS)
  }
}
