// ⚡ FRONT · assessment/matching_controller — relier : toucher un élément à gauche, puis un à droite
// Rôle : une paire porte le même numéro des deux côtés ; toucher une paire la défait ; recopie chaque paire dans les listes
//        de repli (attempt[display_order][] : pour chaque élément de gauche, l'indice d'affichage de droite, jamais un id)
// UDR  : 0087 §3.4, §3.10 · ADR : 0091 §4.4 · boutons aria-pressed, tout au clavier ; sans JavaScript, une liste de choix par élément
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["left", "right", "select", "fallback", "board"]
  static values = { linked: String }

  connect() {
    this.fallbackTarget.hidden = true
    this.boardTarget.hidden = false
    this.pairs = new Map(this.selectTargets.flatMap((select, left) => (select.value === "" ? [] : [[left, Number(select.value)]])))
    this.active = null
    this.render()
  }

  pickLeft(event) {
    const left = this.leftTargets.indexOf(event.currentTarget)
    if (this.pairs.has(left)) {
      this.pairs.delete(left)
      this.active = null
    } else {
      this.active = this.active === left ? null : left
    }
    this.render()
  }

  pickRight(event) {
    const right = this.rightTargets.indexOf(event.currentTarget)
    const owner = [...this.pairs].find(([, value]) => value === right)?.[0]
    if (this.active === null) {
      if (owner !== undefined) this.pairs.delete(owner)
    } else {
      if (owner !== undefined) this.pairs.delete(owner)
      this.pairs.set(this.active, right)
      this.active = null
    }
    this.render()
  }

  render() {
    this.leftTargets.forEach((button, left) => {
      const right = this.pairs.get(left)
      this.mark(button, left === this.active || right !== undefined, right === undefined ? null : left + 1)
      button.querySelector("[data-linked]").textContent =
        right === undefined ? "" : this.linkedValue.replace("%{x}", this.rightTargets[right].dataset.label)
      this.selectTargets[left].value = right === undefined ? "" : String(right)
    })
    this.rightTargets.forEach((button, right) => {
      const left = [...this.pairs].find(([, value]) => value === right)?.[0]
      this.mark(button, left !== undefined, left === undefined ? null : left + 1)
    })
    this.element.dispatchEvent(new Event("input", { bubbles: true }))
  }

  mark(button, pressed, number) {
    button.setAttribute("aria-pressed", String(pressed))
    const badge = button.querySelector("[data-pair]")
    badge.textContent = number ?? ""
    badge.hidden = number === null
  }
}
