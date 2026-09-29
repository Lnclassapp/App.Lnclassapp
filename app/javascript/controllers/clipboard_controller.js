// ⚡ FRONT · clipboard_controller — seul contrôleur de copie : écrit la valeur rendue par le serveur dans le presse-papiers
// Rôle : montre le bouton (caché sans JavaScript), copie, pose le toast « copié » ou l'échec ; émet clipboard:copied
// UDR  : 0054 (§3.5) · ADR : 0049, 0051 · remplace classroom--join-code-copy et la copie d'identity--share
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "copied", "failed"]
  static values = { text: String }

  connect() {
    this.buttonTargets.forEach((button) => { button.hidden = false })
  }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.textValue)
    } catch {
      // Presse-papiers absent (page hors HTTPS) ou refusé par le navigateur.
      return this.toast(this.failedTarget)
    }
    this.toast(this.copiedTarget)
    this.dispatch("copied", { detail: { text: this.textValue } })
  }

  // Chaque toast est permanent pour Turbo, donc porte un id unique : le clone en reçoit un neuf.
  toast(template) {
    const toast = template.content.firstElementChild.cloneNode(true)
    toast.id = `toast-${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`
    document.getElementById("toasts").append(toast)
  }
}
