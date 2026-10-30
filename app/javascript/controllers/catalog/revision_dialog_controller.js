// ⚡ FRONT · catalog/revision_dialog_controller — ouvre la fiche de révision plein écran quand l'adresse la vise
// Rôle : #fiche-de-revision (redirection de /fiche) ou l'ancre d'une notion de la fiche (cartes des leçons) ouvre la <dialog> et y fait défiler,
//        à l'arrivée comme quand l'adresse change sur la page
// UDR  : 0139 §3.3 · la <dialog> et son bouton sont rendus par ui_modal (contrôleur modal) ; sans ancre, la fiche reste fermée
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Le contrôleur modal du bouton se connecte après celui-ci : l'ouverture attend la frame suivante.
    this.frame = requestAnimationFrame(() => this.openFromHash())
    window.addEventListener("hashchange", this.openFromHash)
  }

  disconnect() {
    cancelAnimationFrame(this.frame)
    window.removeEventListener("hashchange", this.openFromHash)
  }

  openFromHash = () => {
    let id
    try {
      id = decodeURIComponent(window.location.hash.slice(1))
    } catch {
      return
    }
    if (!id) return

    const dialog = this.element.querySelector("dialog")
    const target = document.getElementById(id)
    if (!dialog || !target || (id !== "fiche-de-revision" && !dialog.contains(target))) return

    this.element.querySelector(`[aria-controls="${dialog.id}"]`)?.click()
    if (dialog.contains(target)) target.scrollIntoView({ block: "start" })
  }
}
