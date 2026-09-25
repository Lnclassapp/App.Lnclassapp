// ⚡ FRONT · dropdown_controller — menu déroulant au motif WAI-ARIA « menu button »
// Rôle : bascule, flèches / Début / Fin, Échap rend le focus au bouton, clic extérieur et Tab ferment
// UDR  : 0005
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "menu"]

  toggle() {
    this.menuTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.menuTarget.hidden = false
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.items[0]?.focus()
  }

  close() {
    this.menuTarget.hidden = true
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  outside(event) {
    if (!this.menuTarget.hidden && !this.element.contains(event.target)) this.close()
  }

  keydown(event) {
    if (this.menuTarget.hidden) return

    const items = this.items
    const index = items.indexOf(document.activeElement)
    const moves = { ArrowDown: index + 1, ArrowUp: index - 1, Home: 0, End: items.length - 1 }

    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
      this.buttonTarget.focus()
    } else if (event.key === "Tab") {
      this.close()
    } else if (event.key in moves && items.length > 0) {
      event.preventDefault()
      items.at(moves[event.key] % items.length).focus()
    }
  }

  get items() {
    return [...this.menuTarget.querySelectorAll('[role="menuitem"]:not([aria-disabled="true"])')]
  }
}
