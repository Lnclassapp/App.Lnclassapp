// ⚡ FRONT · communication/carousel_controller — les points du carrousel d'annonces, et le focus après un masquage
// Rôle : montre les points dès 2 cartes et suit la carte en vue au défilement (passif) ; refocus : titre de la section
// UDR  : 0071 (§3.5) · sans JavaScript, la bande défile et les points restent cachés
import { Controller } from "@hotwired/stimulus"

// Classes écrites en entier pour que Tailwind les compile.
const ACTIVE = ["w-4", "bg-brand-strong"]
const IDLE = ["w-1.5", "bg-line"]

export default class extends Controller {
  static targets = ["track", "pager", "dot"]
  static values = { refocus: Boolean }

  connect() {
    if (this.refocusValue) this.element.querySelector("#student_home_announcements_title")?.focus()
    if (!this.hasTrackTarget || this.dotTargets.length < 2) return

    this.pagerTarget.classList.replace("hidden", "flex")
    // La bande et l'écouteur sont gardés : toutes les cartes masquées, la bande n'existe plus au débranchement.
    this.track = this.trackTarget
    this.listener = () => this.update()
    this.track.addEventListener("scroll", this.listener, { passive: true })
    this.update()
  }

  disconnect() {
    this.track?.removeEventListener("scroll", this.listener)
  }

  // La carte active est celle dont le bord gauche est le plus près de celui de la bande ; au bout, la dernière.
  update() {
    const track = this.trackTarget
    const cards = Array.from(track.children)
    const left = track.getBoundingClientRect().left
    const distances = cards.map((card) => Math.abs(card.getBoundingClientRect().left - left))
    const atEnd = track.scrollLeft + track.clientWidth >= track.scrollWidth - 1
    const active = atEnd ? cards.length - 1 : distances.indexOf(Math.min(...distances))

    this.dotTargets.forEach((dot, index) => {
      const on = index === active
      dot.classList.remove(...(on ? IDLE : ACTIVE))
      dot.classList.add(...(on ? ACTIVE : IDLE))
    })
  }
}
