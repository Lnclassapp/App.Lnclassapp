// ⚡ FRONT · dropdown_controller — menu déroulant au motif WAI-ARIA « menu button »
// Rôle : bascule, flèches / Début / Fin, Échap rend le focus au bouton, clic extérieur et Tab ferment ; ouvre une <dialog>
// UDR  : 0005, 0042, 0054 · émet modal:opened sur la <dialog> ouverte par `openDialog`
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "menu"]
  static values = { fixed: Boolean }

  toggle() {
    this.menuTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.menuTarget.hidden = false
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.place()
    this.items[0]?.focus({ preventScroll: true })
  }

  close() {
    this.menuTarget.hidden = true
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  // Ferme le menu et rend le focus au bouton : une modale ouverte ensuite le lui rendra à sa fermeture.
  dismiss() {
    this.close()
    this.buttonTarget.focus()
  }

  // Entrée `dialog:` d'ui_dropdown_item (UDR-0042) : la confirmation d'une ligne s'ouvre en showModal(), puis émet
  // `modal:opened` comme le contrôleur modal : l'auto-focus de la boîte vise « Annuler » (UDR-0054 §3.3).
  openDialog({ params: { dialog } }) {
    this.dismiss()
    const element = document.getElementById(dialog)
    if (!element) return

    element.showModal()
    this.dispatch("opened", { target: element, prefix: "modal" })
  }

  // Menu `fixed` (UDR-0042) : placé sous le bouton, ou au-dessus s'il manque de place en bas, jamais hors de l'écran.
  // Un menu en position fixe échappe au défilement horizontal d'un tableau, qui rognerait un menu absolu.
  place() {
    if (!this.fixedValue || this.menuTarget.hidden) return

    const gap = 8
    const menu = this.menuTarget
    const button = this.buttonTarget.getBoundingClientRect()
    const { clientWidth, clientHeight } = document.documentElement
    const width = menu.offsetWidth
    const height = menu.offsetHeight
    const alignEnd = menu.classList.contains("right-0")
    const left = alignEnd ? button.right - width : button.left
    const below = button.bottom + gap
    const top = below + height > clientHeight && button.top - gap - height >= 0 ? button.top - gap - height : below

    Object.assign(menu.style, {
      position: "fixed",
      margin: "0",
      right: "auto",
      top: `${top}px`,
      left: `${Math.min(Math.max(gap, left), clientWidth - width - gap)}px`
    })
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
