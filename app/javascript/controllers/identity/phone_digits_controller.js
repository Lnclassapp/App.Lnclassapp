// ⚡ FRONT · identity/phone_digits_controller — numéro ivoirien nettoyé pendant la frappe et au collage
// Rôle : chiffres seuls, indicatif 225 / 00225 retiré, 10 chiffres au plus ; le serveur fait de même sans JavaScript
// ADR  : 0050, 0051, 0082 · UDR : 0078 (§3.4)
import { Controller } from "@hotwired/stimulus"

const MAX_DIGITS = 10

export default class extends Controller {
  static targets = ["input"]

  // Une valeur re-rendue en 422 est nettoyée aussi, au chargement comme après un morphing.
  connect() {
    this.clean()
    document.addEventListener("turbo:morph", this.refresh)
  }

  disconnect() {
    document.removeEventListener("turbo:morph", this.refresh)
  }

  refresh = () => this.clean()

  clean() {
    const value = this.constructor.normalize(this.inputTarget.value)
    if (value === this.inputTarget.value) return

    this.inputTarget.value = value
    this.inputTarget.setSelectionRange(value.length, value.length)
  }

  // Un numéro ivoirien commence par 0 : un 225 en tête est toujours l'indicatif.
  static normalize(raw) {
    let digits = raw.replace(/\D/g, "")
    if (digits.startsWith("00225")) digits = digits.slice(5)
    else if (digits.startsWith("225")) digits = digits.slice(3)
    return digits.slice(0, MAX_DIGITS)
  }
}
