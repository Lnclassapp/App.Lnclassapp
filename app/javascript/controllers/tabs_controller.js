// ⚡ FRONT · tabs_controller — onglets au motif WAI-ARIA « tabs »
// Rôle : aria-selected, tabindex itinérant, panneaux hidden ; flèches gauche/droite, Début, Fin
// UDR  : 0005
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  select(event) {
    this.activate(this.tabTargets.indexOf(event.currentTarget))
  }

  keydown(event) {
    const index = this.tabTargets.indexOf(document.activeElement)
    const last = this.tabTargets.length - 1
    const target = { ArrowRight: index === last ? 0 : index + 1, ArrowLeft: index === 0 ? last : index - 1, Home: 0, End: last }[event.key]
    if (index === -1 || target === undefined) return

    event.preventDefault()
    this.activate(target)
    this.tabTargets[target].focus()
  }

  activate(index) {
    this.tabTargets.forEach((tab, i) => {
      const active = i === index
      tab.setAttribute("aria-selected", active)
      tab.tabIndex = active ? 0 : -1
      this.panelTargets[i].hidden = !active
    })
  }
}
