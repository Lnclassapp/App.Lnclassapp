// ⚡ FRONT · teams/import_status_controller — suivi d'un import sans WebSocket
// Rôle : recharge le frame « import_status » toutes les 3 s tant que l'import tourne ; s'arrête à la fin et à la déconnexion
// ADR  : 0039 · UDR : 0006
import { Controller } from "@hotwired/stimulus"

const RUNNING = ["queued", "validating", "importing"]
const INTERVAL = 3000

export default class extends Controller {
  static targets = ["state"]
  static values = { url: String }

  // Chaque rechargement remplace le contenu du frame : le nouvel état relance, ou non, le minuteur.
  stateTargetConnected(element) {
    this.stop()
    if (RUNNING.includes(element.dataset.status)) this.timer = setTimeout(() => this.reload(), INTERVAL)
  }

  // Le frame est servi sans src : le premier rechargement le pose (ce qui charge le frame), les suivants rechargent.
  reload() {
    if (this.element.src) this.element.reload()
    else this.element.src = this.urlValue
  }

  disconnect() {
    this.stop()
  }

  stop() {
    clearTimeout(this.timer)
  }
}
