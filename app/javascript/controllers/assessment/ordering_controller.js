// ⚡ FRONT · assessment/ordering_controller — remettre dans l'ordre avec « Monter » et « Descendre », sans glisser-déposer
// Rôle : déplace l'étape, renumérote, désactive les flèches aux extrémités, garde le focus sur l'étape et annonce sa place ;
//        recopie l'ordre dans les listes de repli (copy[answers][<id>][display_order][] : un indice d'affichage par rang, jamais un id)
//        une instance par question (la copie en porte plusieurs) ; `load` relit les listes (brouillon restauré, copie réaffichée en 422)
// UDR  : 0087 §3.4, §3.10, 0138 §3.2 · ADR : 0091 §4.4, 0112 · sans JavaScript, une liste de choix par rang
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "item", "select", "fallback", "status"]
  static values = { up: String, down: String, moved: String }

  connect() {
    this.fallbackTarget.hidden = true
    this.listTarget.hidden = false
    this.load()
  }

  // L'ordre des étapes suit les listes de repli quand elles forment une permutation (valeurs restaurées), sinon l'ordre de départ.
  load() {
    const byIndex = new Map(this.itemTargets.map((item) => [item.dataset.index, item]))
    const order = this.selectTargets.map((select) => select.value)
    if (new Set(order).size === byIndex.size && order.every((value) => byIndex.has(value))) {
      order.forEach((value) => this.listTarget.append(byIndex.get(value)))
    }
    this.sync()
  }

  up(event) {
    this.move(event, -1)
  }

  down(event) {
    this.move(event, 1)
  }

  move(event, delta) {
    const item = event.currentTarget.closest("[data-assessment--ordering-target~='item']")
    const items = this.itemTargets
    const to = items.indexOf(item) + delta
    if (to < 0 || to >= items.length) return

    if (delta < 0) items[to].before(item)
    else items[to].after(item)
    this.sync()
    const button = item.querySelector(`[data-direction='${delta < 0 ? "up" : "down"}']`)
    ;(button.disabled ? item.querySelector("button:not(:disabled)") : button)?.focus()
    this.statusTarget.textContent = this.movedValue.replace("%{n}", to + 1)
  }

  sync() {
    const last = this.itemTargets.length - 1
    this.itemTargets.forEach((item, rank) => {
      item.querySelector("[data-rank]").textContent = rank + 1
      const up = item.querySelector("[data-direction='up']")
      const down = item.querySelector("[data-direction='down']")
      up.disabled = rank === 0
      down.disabled = rank === last
      up.setAttribute("aria-label", this.upValue.replace("%{n}", rank + 1))
      down.setAttribute("aria-label", this.downValue.replace("%{n}", rank + 1))
      this.selectTargets[rank].value = item.dataset.index
    })
    this.element.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
