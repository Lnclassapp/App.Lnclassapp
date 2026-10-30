// ⚡ FRONT · communication/audio_duration_controller — la durée de l'audio d'une annonce, lue avant l'envoi
// Rôle : au choix d'un fichier, lit sa durée (<audio> sur une URL d'objet) ; au-delà du maximum : message sous le champ et champ invalide
// UDR  : 0071 (§3.8, amendement du 2026-10-30) · ADR : 0118 · le serveur mesure toujours : durée illisible = rien de bloqué ici
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "status"]
  static values = { max: Number, message: String }

  connect() {
    this.stale = false
  }

  disconnect() {
    this.stale = true
  }

  check() {
    this.clear()
    const file = this.inputTarget.files[0]
    if (!file) return

    // Chaque contrôle a sa propre URL d'objet, révoquée par ses seuls écouteurs : un contrôle périmé ne révoque pas la suivante.
    const url = URL.createObjectURL(file)
    const player = document.createElement("audio")
    const release = () => URL.revokeObjectURL(url)
    player.preload = "metadata"
    player.addEventListener("loadedmetadata", () => {
      release()
      this.measured(player, file)
    })
    player.addEventListener("error", release)
    player.src = url
    player.load()
  }

  measured(player, file) {
    // Un autre fichier a été choisi entre-temps (ou le champ a quitté la page) : cette mesure est périmée.
    if (this.stale || this.inputTarget.files[0] !== file) return

    const seconds = player.duration
    if (!Number.isFinite(seconds) || seconds <= this.maxValue) return

    const shown = (Math.round(seconds * 10) / 10).toString().replace(".", ",")
    const message = this.messageValue.replace("%{duration}", shown)
    this.statusTarget.textContent = message
    this.inputTarget.setCustomValidity(message)
  }

  clear() {
    this.statusTarget.textContent = ""
    this.inputTarget.setCustomValidity("")
  }
}
