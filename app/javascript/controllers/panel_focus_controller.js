// ⚡ FRONT · panel_focus_controller — après chaque chargement du Turbo Frame d'un panneau, le focus va au titre du nouvel écran
// Rôle : l'écran remplacé disparaît avec le focus ; on focalise `[data-panel-focus-title]`, sinon le premier h1/h2 du contenu chargé
// UDR  : 0054 (§3.3) : pas d'attribut `autofocus` · branché sur le frame de « Mon compte » (turbo:frame-load) ; le focus reste dans le <dialog>
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  focus() {
    const title = this.element.querySelector("[data-panel-focus-title]") || this.element.querySelector("h1, h2")
    if (!title) return

    // Titre focalisable par programme seulement (hors ordre de tabulation), sans contour au clic.
    if (!title.hasAttribute("tabindex")) title.setAttribute("tabindex", "-1")
    title.classList.add("outline-none")
    title.focus({ preventScroll: false })
  }
}
