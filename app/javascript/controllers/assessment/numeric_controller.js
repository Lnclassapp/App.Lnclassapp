// ⚡ FRONT · assessment/numeric_controller — réponse en nombre : bouton « ± » et refus d'une saisie illisible
// Rôle : « ± » ajoute ou retire le moins (le clavier Android n'en a pas toujours) ; un nombre illisible rend le champ invalide,
//        virgule ou point, moins ASCII ou Unicode, espaces des milliers ; le refus s'écrit sous le champ, à sa sortie et à l'envoi
// UDR  : 0087 §3.4, §3.10, XXXX-premier-exercice-ux §3.2 · ADR : 0091 §4.3 (Numeric.parse, la même lecture côté serveur) · sans JavaScript, un champ simple
import { Controller } from "@hotwired/stimulus"

const NUMBER = /^-?\d+(?:\.\d+)?$/

export default class extends Controller {
  static targets = ["input", "error"]
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
    if (this.inputTarget.validity.valid) this.show(false)
  }

  // Sortie du champ, ou « invalid » envoyé par la copie à l'envoi : une saisie illisible se dit sous le champ.
  reveal(event) {
    if (event?.type === "invalid") event.preventDefault() // jamais la bulle du navigateur
    if (!this.inputTarget.validity.valid) this.show(true)
  }

  show(visible) {
    if (!this.hasErrorTarget) return

    const input = this.inputTarget
    const id = this.errorTarget.id
    const described = (input.getAttribute("aria-describedby") ?? "").split(" ").filter((token) => token && token !== id)
    this.errorTarget.hidden = !visible
    input.setAttribute("aria-describedby", (visible ? [id, ...described] : described).join(" "))
    if (visible) input.setAttribute("aria-invalid", "true")
    else input.removeAttribute("aria-invalid")
  }
}
