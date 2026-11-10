// ⚡ FRONT · generation-poll — recharge le frame d'une génération toutes les 2 s, 45 s au plus
// Rôle : le contenu final (prête ou en échec) n'a plus ce contrôleur : il se déconnecte et s'arrête ; à l'échéance, montre l'état « trop long »
// ADR  : XXXX (modèles de langage) · UDR : XXXX (assistants du suivi)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["waiting", "timedOut"]
  static values = { url: String, interval: { type: Number, default: 2000 }, timeout: { type: Number, default: 45000 } }

  connect() {
    this.ticker = setInterval(() => this.tick(), this.intervalValue)
    this.deadline = setTimeout(() => this.expire(), this.timeoutValue)
  }

  disconnect() {
    this.stop()
  }

  tick() {
    const frame = this.element.closest("turbo-frame")
    if (!frame) return
    // Le frame n'a pas de src à l'affichage : le premier tour le fixe (Turbo le charge), les suivants le rechargent.
    if (frame.getAttribute("src") === this.urlValue) frame.reload()
    else frame.setAttribute("src", this.urlValue)
  }

  expire() {
    this.stop()
    if (this.hasWaitingTarget) this.waitingTarget.hidden = true
    if (this.hasTimedOutTarget) this.timedOutTarget.hidden = false
    const frame = this.element.closest("turbo-frame")
    if (frame) frame.removeAttribute("aria-busy")
  }

  stop() {
    clearInterval(this.ticker)
    clearTimeout(this.deadline)
  }
}
