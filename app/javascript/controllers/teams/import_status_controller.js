// ⚡ FRONT · teams/import_status_controller — suivi d'un import sans WebSocket
// Rôle : recharge le frame « import_status » toutes les secondes tant que l'import tourne ; s'arrête à la fin, à la déconnexion et au plafond de MAX_POLLS rechargements (10 min) : le dernier état reste affiché
// ADR  : 0039, 0068 · UDR : 0006, 0055
import { Controller } from "@hotwired/stimulus"

const RUNNING = ["queued", "validating", "importing"]
const INTERVAL = 1000
// Plafond de durée (conventions §7, point 1) : un import resté « importing » (job mort) ne fait pas interroger le serveur sans fin. 600 × 1 s = 10 min,
// puis le minuteur ne se réarme plus et le dernier état reste affiché, sans écran ni message de plus.
const MAX_POLLS = 600

export default class extends Controller {
  static targets = ["state"]
  static values = { url: String }

  // Chaque rechargement remplace le contenu du frame : le nouvel état relance, ou non, le minuteur.
  stateTargetConnected(element) {
    this.stop()
    if (!RUNNING.includes(element.dataset.status)) return
    if ((this.polls ||= 0) >= MAX_POLLS) return

    this.polls += 1
    this.timer = setTimeout(() => this.reload(), INTERVAL)
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
