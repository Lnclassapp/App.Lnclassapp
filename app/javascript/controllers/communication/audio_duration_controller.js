// ⚡ FRONT · communication/audio_duration_controller — la durée de l'audio d'une annonce, lue avant l'envoi
// Rôle : au choix d'un fichier, lit sa durée (<audio> sur une URL d'objet) ; au-delà du maximum : message sous le champ et champ invalide
// UDR  : 0071 (§3.8, amendement du 2026-10-30) · ADR : XXXX-annonces-audio-dix-secondes · le serveur mesure toujours : durée illisible = rien de bloqué ici
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "status"]
  static values = { max: Number, message: String }

  disconnect() {
    this.release()
  }

  check() {
    this.release()
    this.clear()
    const file = this.inputTarget.files[0]
    if (!file) return

    this.url = URL.createObjectURL(file)
    const player = document.createElement("audio")
    player.preload = "metadata"
    player.addEventListener("loadedmetadata", () => this.measured(player, file))
    player.addEventListener("error", () => this.release())
    player.src = this.url
  }

  measured(player, file) {
    // Un autre fichier a été choisi entre-temps : cette mesure est périmée.
    if (this.inputTarget.files[0] !== file) return

    const seconds = player.duration
    this.release()
    if (!Number.isFinite(seconds) || seconds <= this.maxValue) return

    const shown = (Math.round(seconds * 10) / 10).toString().replace(".", ",")
    const message = this.messageValue.replace("%{duration}", shown)
    this.statusTarget.textContent = message
    this.inputTarget.setCustomValidity(message)
    this.inputTarget.reportValidity()
  }

  clear() {
    this.statusTarget.textContent = ""
    this.inputTarget.setCustomValidity("")
  }

  release() {
    if (this.url) URL.revokeObjectURL(this.url)
    this.url = null
  }
}
