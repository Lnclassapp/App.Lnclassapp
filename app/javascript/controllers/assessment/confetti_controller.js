// ⚡ FRONT · assessment/confetti_controller — confettis du résultat réussi, pendant 3 s
// Rôle : lance des confettis depuis les deux bords, sans bibliothèque (Web Animations) ; rien si prefers-reduced-motion
// ADR  : 0051 · UDR : 0023 · aucun attribut style : la position et la chute passent par element.animate
import { Controller } from "@hotwired/stimulus"

const DURATION = 3000
const FALL = 2500
const BURST_EVERY = 150
const COLORS = ["bg-brand", "bg-success", "bg-gold", "bg-teacher", "bg-team"]

export default class extends Controller {
  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    this.layer = document.createElement("div")
    this.layer.id = "confetti"
    this.layer.setAttribute("aria-hidden", "true")
    this.layer.className = "pointer-events-none fixed inset-0 z-50 overflow-hidden"
    document.body.append(this.layer)

    this.timer = setInterval(() => this.burst(), BURST_EVERY)
    this.stopTimer = setTimeout(() => this.stop(), DURATION)
    this.removeTimer = setTimeout(() => this.disconnect(), DURATION + FALL)
    this.burst()
  }

  disconnect() {
    clearInterval(this.timer)
    clearTimeout(this.stopTimer)
    clearTimeout(this.removeTimer)
    this.layer?.remove()
    this.layer = null
  }

  stop() {
    clearInterval(this.timer)
  }

  // Deux confettis par bord, comme l'ancienne application : l'un part de la gauche, l'autre de la droite.
  burst() {
    for (let index = 0; index < 4; index++) this.piece(index % 2 === 0 ? 0 : 100)
  }

  piece(origin) {
    const piece = document.createElement("span")
    piece.className = `absolute left-0 top-0 h-3 w-2 ${COLORS[Math.floor(Math.random() * COLORS.length)]}`
    this.layer.append(piece)

    const direction = origin === 0 ? 1 : -1
    const drift = direction * (15 + Math.random() * 35)
    const turns = (Math.random() * 3 + 1) * 360
    piece.animate(
      [
        { transform: `translate(${origin}vw, 40vh) rotate(0deg)`, opacity: 1 },
        { transform: `translate(${origin + drift * 0.6}vw, ${10 + Math.random() * 20}vh) rotate(${turns / 2}deg)`, opacity: 1, offset: 0.3 },
        { transform: `translate(${origin + drift}vw, 105vh) rotate(${turns}deg)`, opacity: 0.8 }
      ],
      { duration: FALL, easing: "cubic-bezier(0.25, 0.1, 0.25, 1)", fill: "forwards" }
    ).finished.then(() => piece.remove(), () => {})
  }
}
