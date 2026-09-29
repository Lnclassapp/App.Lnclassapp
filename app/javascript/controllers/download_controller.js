// ⚡ FRONT · download_controller — enregistre un texte rendu par le serveur dans un fichier, ou imprime la page
// Rôle : codes de secours (Blob text/plain, lien de téléchargement cliqué par le geste de la personne, jamais automatique)
// UDR  : 0054 (§3.7) · les boutons restent cachés tant que le contrôleur n'est pas connecté
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "saved"]
  static values = { content: String, filename: String }

  connect() {
    this.buttonTargets.forEach((button) => { button.hidden = false })
  }

  save() {
    const url = URL.createObjectURL(new Blob([this.contentValue], { type: "text/plain;charset=utf-8" }))
    const link = Object.assign(document.createElement("a"), { href: url, download: this.filenameValue })
    link.click()
    URL.revokeObjectURL(url)
    if (this.hasSavedTarget) this.toast(this.savedTarget)
  }

  print() {
    window.print()
  }

  // Même motif que le contrôleur clipboard : le toast est rendu par le serveur, cloné avec un id neuf.
  toast(template) {
    const toast = template.content.firstElementChild.cloneNode(true)
    toast.id = `toast-${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`
    document.getElementById("toasts").append(toast)
  }
}
