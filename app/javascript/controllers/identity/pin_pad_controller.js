// ⚡ FRONT · identity/pin_pad_controller — pavé numérique de « Nouveau sur Lnclass » : 4 cases, 10 touches, envoi au 4e chiffre
// Rôle : cache le champ natif (sans JavaScript il reste), montre le pavé ; au 4e chiffre, requestSubmit : le serveur compare, le premier code n'est jamais dans la page
// ADR  : 0141 · UDR : pave-numerique-confirmation-code (§2, §3.2)
import { Controller } from "@hotwired/stimulus"

const LENGTH = 4
const FILLED = "border-brand"
const IDLE = "border-line"

export default class extends Controller {
  static targets = ["field", "fieldBlock", "pad", "box", "status", "check", "submit", "mismatch", "key"]

  connect() {
    this.setup()
    this.onKeydown = this.onKeydown.bind(this)
    this.onSubmitEnd = this.onSubmitEnd.bind(this)
    this.onRender = this.setup.bind(this)
    document.addEventListener("keydown", this.onKeydown)
    // Le re-rendu 422 se fait par morphing : l'élément est gardé, le contrôleur ne se reconnecte pas, et le morphing
    // remet le champ natif visible et le pavé caché. On refait la mise en place après chaque rendu.
    document.addEventListener("turbo:render", this.onRender)
    this.element.addEventListener("turbo:submit-end", this.onSubmitEnd)
  }

  setup() {
    this.digits = ""
    this.fieldBlockTarget.hidden = true
    this.fieldTarget.removeAttribute("autofocus")
    this.fieldTarget.value = ""
    this.padTarget.hidden = false
    this.padTarget.removeAttribute("aria-busy")
    // Le message d'écart du serveur (422) reste visible au-dessus du pavé ; il est rendu caché pour le cas sans JavaScript.
    if (this.hasMismatchTarget) this.mismatchTarget.hidden = false
    if (this.hasCheckTarget) this.checkTarget.hidden = true
    this.render()
    if (this.hasKeyTarget) this.keyTargets[0].focus({ preventScroll: true })
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("turbo:render", this.onRender)
    this.element.removeEventListener("turbo:submit-end", this.onSubmitEnd)
  }

  press(event) {
    this.add(event.currentTarget.dataset.digit)
  }

  erase() {
    if (this.locked) return
    this.digits = this.digits.slice(0, -1)
    this.render()
  }

  onKeydown(event) {
    if (event.ctrlKey || event.metaKey || event.altKey) return
    if (/^[0-9]$/.test(event.key)) {
      event.preventDefault()
      this.add(event.key)
    } else if (event.key === "Backspace") {
      event.preventDefault()
      this.erase()
    }
  }

  add(digit) {
    if (this.locked || this.digits.length >= LENGTH) return
    this.digits += digit
    this.render()
    if (this.digits.length === LENGTH) this.send()
  }

  send() {
    this.padTarget.setAttribute("aria-busy", "true")
    this.fieldTarget.value = this.digits
    this.submitTarget.disabled = false
    this.element.requestSubmit(this.submitTarget)
  }

  // Succès : la coche, le pavé reste verrouillé (la redirection suit). Échec : le serveur re-rend la page (422) et
  // le contrôleur se reconnecte, cases vides ; un échec réseau rend le pavé.
  onSubmitEnd(event) {
    if (event.detail.success) {
      this.checkTarget.hidden = false
    } else {
      this.digits = ""
      this.fieldTarget.value = ""
      this.padTarget.removeAttribute("aria-busy")
      this.render()
    }
  }

  get locked() {
    return this.padTarget.getAttribute("aria-busy") === "true"
  }

  render() {
    const count = this.digits.length
    this.boxTargets.forEach((box, index) => {
      const filled = index < count
      box.textContent = filled ? "●" : ""
      box.classList.toggle(FILLED, filled || index === count)
      box.classList.toggle(IDLE, !(filled || index === count))
    })
    this.statusTarget.textContent = this.statusTarget.dataset.template.replace("%{count}", count)
    this.submitTarget.disabled = count < LENGTH
    this.submitTarget.setAttribute("aria-disabled", String(count < LENGTH))
  }
}
