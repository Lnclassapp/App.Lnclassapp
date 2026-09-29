// ⚡ FRONT · info_tip_controller — ouvre l'infobulle (<details>) au survol de la souris, la referme quand elle part
// Rôle : clic, toucher, Entrée et Espace restent au navigateur ; un clic pendant le survol garde l'infobulle ouverte
// UDR  : 0054 (§3.4, amendement du 2026-09-29 « survol ») · rien au toucher ni sans JavaScript : le <details> suffit
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Souris seulement (pointerType) : au toucher, pointerenter précède le clic, qui doit rester seul à ouvrir. Une
  // infobulle déjà ouverte par un clic n'est pas reprise par le survol.
  enter(event) {
    if (event.pointerType !== "mouse" || this.element.open) return

    this.hovered = true
    this.element.open = true
  }

  leave() {
    if (!this.hovered) return

    this.hovered = false
    this.element.open = false
  }

  // Clic sur l'icône d'une infobulle ouverte par le survol : sans cela, le navigateur la refermerait sous la souris.
  // Elle devient ouverte « au clic » : le clic suivant la ferme, la souris qui part ne la ferme plus.
  pin(event) {
    if (!this.hovered) return

    event.preventDefault()
    this.hovered = false
  }
}
