// ⚡ FRONT · info_tip_controller — ouvre l'infobulle (<details>) au survol de la souris, en bulle, et la referme au départ
// Rôle : au survol, le panneau flotte sous l'icône sans rien pousser ; un clic l'épingle et le remet dans le flux
// UDR  : 0054 (§3.4, amendement « survol ») · clic, toucher, Entrée, Espace et rendu sans JavaScript : <details> natif
import { Controller } from "@hotwired/stimulus"

const GUTTER = 16
const GAP = 4

export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.close = () => this.leave()
    this.follow = () => requestAnimationFrame(() => this.hovered && this.place())
  }

  disconnect() {
    this.leave()
  }

  // Souris seulement (pointerType) : au toucher, pointerenter précède le clic, qui doit rester seul à ouvrir. Une
  // infobulle déjà ouverte par un clic n'est pas reprise par le survol.
  enter(event) {
    if (event.pointerType !== "mouse" || this.element.open) return

    this.hovered = true
    this.element.dataset.floating = ""
    this.element.open = true
    this.place()
    // Une bulle fixe ne suit pas seule le défilement (page ou tableau défilant) : elle est replacée sous l'icône.
    window.addEventListener("scroll", this.follow, { capture: true, passive: true })
    document.addEventListener("turbo:before-cache", this.close)
  }

  leave() {
    if (!this.hovered) return

    this.element.open = false
    this.settle()
  }

  // Clic sur l'icône d'une bulle ouverte au survol : sans cela, le navigateur la refermerait sous la souris. Elle
  // devient une infobulle ouverte « au clic », dans le flux : le pointeur qui part ne la ferme plus, le clic suivant si.
  pin(event) {
    if (!this.hovered) return

    event.preventDefault()
    this.settle()
  }

  // Sous l'icône, bord gauche aligné, contenue dans la fenêtre à 16 px des bords ; au-dessus s'il manque la place.
  place() {
    const icon = this.element.querySelector("summary").getBoundingClientRect()
    const panel = this.panelTarget.getBoundingClientRect()
    const left = Math.max(GUTTER, Math.min(icon.left, window.innerWidth - panel.width - GUTTER))
    const below = icon.bottom + GAP
    const top = below + panel.height > window.innerHeight - GUTTER ? Math.max(GUTTER, icon.top - GAP - panel.height) : below

    this.panelTarget.style.left = `${left}px`
    this.panelTarget.style.top = `${top}px`
  }

  settle() {
    this.hovered = false
    delete this.element.dataset.floating
    this.panelTarget.style.removeProperty("left")
    this.panelTarget.style.removeProperty("top")
    window.removeEventListener("scroll", this.follow, { capture: true })
    document.removeEventListener("turbo:before-cache", this.close)
  }
}
