// ⚡ FRONT · autosubmit_controller — envoie le formulaire, une seule fois, dès que la saisie correspond au motif
// Rôle : code du second facteur (6 chiffres), code de /join ; le bouton d'envoi reste (sans JavaScript, rien ne change)
// UDR  : 0054 (§3.6) · verrou : un envoi à la fois, qu'il vienne du contrôleur, d'Entrée ou du bouton
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "status"]
  static values = { pattern: String, message: String }

  connect() {
    this.sending = false
    this.ownSubmit = false
    this.lastValue = null
    this.check = this.check.bind(this)
    this.guard = this.guard.bind(this)
    this.lock = this.lock.bind(this)
    this.unlock = this.unlock.bind(this)
    this.element.addEventListener("input", this.check)
    this.element.addEventListener("submit", this.guard)
    this.element.addEventListener("turbo:submit-start", this.lock)
    this.element.addEventListener("turbo:submit-end", this.unlock)
  }

  disconnect() {
    this.element.removeEventListener("input", this.check)
    this.element.removeEventListener("submit", this.guard)
    this.element.removeEventListener("turbo:submit-start", this.lock)
    this.element.removeEventListener("turbo:submit-end", this.unlock)
  }

  // Valeur débarrassée des espaces et des tirets (« KFM-37 », « 123 456 »).
  check(event) {
    if (!this.inputTargets.includes(event.target)) return

    const value = event.target.value.replace(/[\s-]/g, "")
    if (this.sending || value === this.lastValue || !new RegExp(this.patternValue).test(value)) return

    this.lastValue = value
    this.sending = true
    this.ownSubmit = true
    if (this.hasStatusTarget) this.statusTarget.textContent = this.messageValue
    this.element.requestSubmit()
    // Le navigateur a refusé l'envoi (contrainte du champ non remplie) : aucun submit n'est parti, rien n'est verrouillé.
    if (this.ownSubmit) {
      this.ownSubmit = this.sending = false
      this.lastValue = null
    }
  }

  // Un envoi pendant qu'un autre court est annulé ; Turbo ignore un submit dont le défaut est empêché.
  guard(event) {
    if (this.ownSubmit) {
      this.ownSubmit = false
    } else if (this.sending) {
      event.preventDefault()
    }
  }

  lock() {
    this.sending = true
  }

  unlock() {
    this.sending = false
  }
}
