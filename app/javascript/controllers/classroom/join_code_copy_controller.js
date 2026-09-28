// ⚡ FRONT · classroom/join_code_copy_controller — copie un code tel qu'affiché (classe, établissement) ou un lien
// Rôle : écrit le code dans le presse-papiers, puis pose le toast rendu par le serveur (« Code copié », ou l'échec) ; Turbo ne copie pas
// ADR  : 0051, 0057 · UDR : 0027, 0044
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["copied", "failed"]
  static values = { code: String }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.codeValue)
      this.toast(this.copiedTarget)
    } catch {
      // Presse-papiers absent (page hors HTTPS) ou refusé par le navigateur.
      this.toast(this.failedTarget)
    }
  }

  // Chaque toast est permanent pour Turbo, donc porte un id unique : le clone en reçoit un neuf.
  toast(template) {
    const toast = template.content.firstElementChild.cloneNode(true)
    toast.id = `toast-${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`
    document.getElementById("toasts").append(toast)
  }
}
