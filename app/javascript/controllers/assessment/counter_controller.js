// ⚡ FRONT · assessment/counter_controller — compteur de caractères d'une réponse rédigée : « 1 234 / 2 000 »
// Rôle : met à jour le compteur à chaque frappe ; la zone refuse déjà plus de `max` caractères (maxlength)
// UDR  : 0140 §3 · sans JavaScript, le compteur reste caché et la zone marche quand même
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "output"]
  static values = { max: Number }

  connect() {
    this.outputTarget.hidden = false
    this.update()
  }

  update() {
    const format = (number) => number.toLocaleString("fr-FR")
    this.outputTarget.textContent = `${format(this.inputTarget.value.length)} / ${format(this.maxValue)}`
  }
}
