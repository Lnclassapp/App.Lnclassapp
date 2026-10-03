// ⚡ FRONT · reveal_controller — « Voir plus » : révèle les lignes d'une liste déjà rendues mais masquées, sans requête
// Rôle : affiche les éléments `hidden` (par paquets de `step`, ou tous), masque le bouton à la fin, annonce le nombre ajouté
// UDR  : 0057 §3 (R3 : 3 lignes, puis « Voir plus ») · le serveur rend les lignes en trop avec `hidden` (ui_reveal_item)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item", "button", "status"]
  static values = { step: Number, one: String, other: String }

  connect() {
    this.sync()
  }

  more() {
    const hidden = this.itemTargets.filter((item) => item.hidden)
    const batch = this.stepValue > 0 ? hidden.slice(0, this.stepValue) : hidden
    batch.forEach((item) => { item.hidden = false })
    this.announce(batch.length)
    this.sync()
    // Le bouton disparaît quand tout est visible : le focus passe à la première ligne révélée, jamais dans le vide.
    if (this.hasButtonTarget && this.buttonTarget.hidden) batch[0]?.querySelector("a, button")?.focus()
  }

  sync() {
    if (this.hasButtonTarget) this.buttonTarget.hidden = !this.itemTargets.some((item) => item.hidden)
  }

  announce(count) {
    if (!this.hasStatusTarget) return

    const template = count === 1 ? this.oneValue : this.otherValue
    this.statusTarget.textContent = template.replace("{count}", count)
  }
}
