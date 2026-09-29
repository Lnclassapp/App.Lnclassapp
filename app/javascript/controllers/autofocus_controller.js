// ⚡ FRONT · autofocus_controller — une seule règle d'auto-focus, sur <body> (mode page) et sur chaque <dialog> (mode dialog)
// Rôle : premier champ en erreur, sinon la cible `field` ; dans une modale, son premier champ, sinon « Annuler » du pied, jamais la croix
// UDR  : 0054 (§3.3) · remplace l'attribut `autofocus` des vues ; suit aussi `turbo:morph` ; `[data-autofocus-skip]` : démonstration
import { Controller } from "@hotwired/stimulus"

const FIELDS = "input:not([type=hidden]):not([readonly]):not([disabled]), select, textarea, trix-editor"

export default class extends Controller {
  static targets = ["field", "fallback"]
  static values = { mode: { type: String, default: "page" } }

  // Page : un rendu Turbo Drive reconnecte <body> ; un rendu fusionné (morph : re-rendu 422, rafraîchissement) ne le
  // reconnecte pas, d'où l'écoute de `turbo:morph`. Dialog : une modale déjà ouverte en vraie modale à l'arrivée du
  // contrôleur (re-rendu 422 dans le frame « modal ») a émis `modal:opened` avant lui.
  connect() {
    if (this.dialog) {
      if (this.element.open && this.element.matches(":modal")) this.focus()
    } else {
      this.morphed = () => this.focus()
      document.addEventListener("turbo:morph", this.morphed)
      this.focus()
    }
  }

  disconnect() {
    if (this.morphed) document.removeEventListener("turbo:morph", this.morphed)
  }

  // Aussi l'action de `modal:opened` (émis par le contrôleur modal juste après showModal()).
  focus() {
    this.target?.focus({ preventScroll: false })
  }

  get dialog() {
    return this.modeValue === "dialog"
  }

  get target() {
    const invalid = this.inScope(this.element.querySelectorAll('[aria-invalid="true"]'))[0]
    if (invalid) return invalid

    const field = this.inScope(this.fieldTargets)[0]
    if (!this.dialog) return field

    return field ||
      this.inScope(this.element.querySelectorAll(FIELDS))[0] ||
      this.fallbackTargets[0] ||
      this.element.querySelector('[data-autofocus-footer] [data-action~="modal#close"]')
  }

  // Mode page : ce qui est dans une <dialog> (elle a son propre auto-focus) ou dans une zone `data-autofocus-skip` est ignoré.
  inScope(elements) {
    if (this.dialog) return Array.from(elements)

    return Array.from(elements).filter((element) => !element.closest("dialog, [data-autofocus-skip]"))
  }
}
