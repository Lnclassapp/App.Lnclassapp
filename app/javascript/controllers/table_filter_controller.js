// ⚡ FRONT · controllers/table_filter_controller.js — filtre les lignes d'un tableau dans le navigateur, sans appel serveur
// Rôle : montre le champ (masqué sans JavaScript), masque les lignes dont data-filter-text ne contient pas la saisie, annonce le nombre
// UDR  : 0068 (§3.5) · saisie comparée sans casse ni accents ; data-filter-text est déjà normalisé par le serveur
import { Controller } from "@hotwired/stimulus"

const normalize = (text) => text.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/\s+/g, " ").trim()

export default class extends Controller {
  static targets = ["field", "input", "row", "empty", "status"]
  // Messages du statut, « %{count} » remplacé par le nombre de lignes affichées.
  static values = { one: String, other: String }

  connect() {
    if (this.hasFieldTarget) this.fieldTarget.hidden = false
  }

  filter() {
    const query = normalize(this.inputTarget.value)
    let shown = 0
    this.rowTargets.forEach((row) => {
      row.hidden = !(row.dataset.filterText || "").includes(query)
      if (!row.hidden) shown += 1
    })
    if (this.hasEmptyTarget) this.emptyTarget.hidden = shown > 0
    if (this.hasStatusTarget) {
      const message = new Intl.PluralRules("fr").select(shown) === "one" ? this.oneValue : this.otherValue
      this.statusTarget.textContent = message.replace("%{count}", shown)
    }
  }
}
