// ⚡ FRONT · toast_controller — cycle de vie d'une notification rendue par le serveur
// Rôle : fermeture manuelle ; auto-fermeture après `delay` ms (0 = reste affichée), suspendue au survol et au focus
// UDR  : 0006
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: Number }

  connect() {
    this.resume()
  }

  disconnect() {
    this.pause()
  }

  pause() {
    clearTimeout(this.timer)
  }

  resume() {
    this.pause()
    if (this.delayValue > 0) this.timer = setTimeout(() => this.dismiss(), this.delayValue)
  }

  dismiss() {
    this.element.remove()
  }
}
