// ⚡ FRONT · identity/pin_pad_controller — le code secret en 4 cases et 10 touches, partout où l'on tape un code (partiel shared/pin_pad)
// Rôle : cache le champ natif (sans JavaScript il reste), montre le pavé ; au 4e chiffre, mode « submit » : requestSubmit, le code part au serveur ; mode « step » : le champ est rempli et le bouton de l'étape (Continuer) cliqué
// ADR  : 0141, 0148-connexion-revele-un-numero-inscrit · UDR : 0180-pave-numerique-confirmation-code (§2, §3.2 ; hors ligne : message, chiffres gardés, renvoi possible), 0189-connexion-numero-d-abord (§3.4, amendement §3.6)
import { Controller } from "@hotwired/stimulus"

const LENGTH = 4
const FILLED = "border-brand"
const IDLE = "border-line"

export default class extends Controller {
  static targets = ["field", "fieldBlock", "pad", "box", "status", "check", "submit", "mismatch", "offline", "key"]
  static values = { mode: { type: String, default: "submit" } }

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
    if (this.hasKeyTarget && this.visible) this.keyTargets[0].focus({ preventScroll: true })
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

  // Le clavier physique ne nourrit que le pavé visible, et jamais à la place d'un autre champ (le numéro, le nom).
  onKeydown(event) {
    if (event.ctrlKey || event.metaKey || event.altKey || !this.visible) return
    if (["INPUT", "TEXTAREA", "SELECT"].includes(event.target?.tagName)) return
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
    if (this.hasOfflineTarget) this.offlineTarget.hidden = true
    this.render()
    if (this.digits.length === LENGTH) this.send()
  }

  send() {
    this.fieldTarget.value = this.digits
    if (this.modeValue === "step") return this.submitTarget.click()

    this.padTarget.setAttribute("aria-busy", "true")
    this.submitTarget.disabled = false
    this.element.requestSubmit(this.submitTarget)
  }

  // Succès : la coche, le pavé reste verrouillé (la redirection suit). Échec avec re-rendu serveur (422) : le contrôleur
  // se reconnecte, cases vides. Échec sans re-rendu (hors ligne) : on garde les 4 chiffres, on dit pourquoi et on rend le pavé.
  onSubmitEnd(event) {
    if (event.detail.success) {
      this.checkTarget.hidden = false
    } else if (event.detail.error || !event.detail.fetchResponse) {
      this.padTarget.removeAttribute("aria-busy")
      if (this.hasOfflineTarget) this.offlineTarget.hidden = false
      this.render()
      this.submitTarget.disabled = false
      this.submitTarget.setAttribute("aria-disabled", "false")
    } else {
      this.digits = ""
      this.fieldTarget.value = ""
      this.padTarget.removeAttribute("aria-busy")
      this.render()
    }
  }

  get visible() {
    return !this.padTarget.hidden && this.padTarget.getClientRects().length > 0
  }

  get locked() {
    return this.padTarget.getAttribute("aria-busy") === "true"
  }

  render() {
    const count = this.digits.length
    this.fieldTarget.value = count === LENGTH ? this.digits : ""
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
