// ⚡ FRONT · assessment/numeric_controller — réponse en nombre : bouton « ± » et refus d'une saisie illisible
// Rôle : « ± » ajoute ou retire le moins (le clavier Android n'en a pas toujours) ; un nombre illisible rend le champ invalide,
//        donc « Valider » reste désactivé (assessment--answer) ; virgule ou point, moins ASCII ou Unicode, espaces des milliers
// UDR  : 0087 §3.4, §3.10 · ADR : 0091 §4.3 (Numeric.parse, la même lecture côté serveur) · sans JavaScript, un champ simple
import { Controller } from "@hotwired/stimulus"

const NUMBER = /^-?\d+(?:\.\d+)?$/

export default class extends Controller {
  static targets = ["input"]
  static values = { invalid: String }

  connect() {
    this.validate()
  }

  toggleSign() {
    const value = this.inputTarget.value.trim()
    this.inputTarget.value = /^[-−]/.test(value) ? value.slice(1) : `-${value}`
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.inputTarget.focus()
  }

  validate() {
    const value = this.inputTarget.value.trim().replace("−", "-").replace(/(\d)[   ](?=\d)/g, "$1").replace(",", ".")
    this.inputTarget.setCustomValidity(value === "" || NUMBER.test(value) ? "" : this.invalidValue)
  }
}
