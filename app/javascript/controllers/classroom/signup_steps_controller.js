// ⚡ FRONT · classroom/signup_steps_controller — une inscription (élève ou enseignant) découpée en trois étapes dans un seul formulaire
// Rôle : un seul fieldset visible ; la liste des étapes du panneau d'ordinateur suit l'étape ; une classe de la cascade touchée, les quatre champs valides ou « Continuer » (étape data-continue, champs valides) font avancer ; retour sans perte ; annonce aria-live
// ADR  : 0109 (§4.4, §4.5) · UDR : 0135 (§3.1 à §3.8, §3.5 bis), XXXX-connexion-numero-d-abord (§3.5)
import { Controller } from "@hotwired/stimulus"

const CLASSROOM_FIELD = /\[classroom_public_id\]$/
const PHONE = /^\d{10}$/

export default class extends Controller {
  static targets = [
    "step", "segment", "counter", "live", "back", "welcome",
    "recap", "recapName", "recapSchool",
    "panelStep", "panelRecap", "panelRecapName", "panelRecapSchool"
  ]
  static values = {
    start: Number, counter: String, announce: String,
    delay: { type: Number, default: 1000 }
  }

  connect() {
    this.current = this.startValue
    this.render()
    document.addEventListener("turbo:morph", this.refresh)
  }

  disconnect() {
    clearTimeout(this.timer)
    document.removeEventListener("turbo:morph", this.refresh)
  }

  // Un re-rendu 422 est un morphing : le contrôleur reste branché, le serveur a dit quelle étape ouvrir. Un passage à
  // l'étape 3 encore en attente (le « change » du numéro au départ du focus) ne repasse pas par-dessus son erreur.
  refresh = () => {
    clearTimeout(this.timer)
    this.current = this.startValue
    this.render()
  }

  next() { this.goTo(this.current + 1) }
  back() { this.goTo(this.current - 1) }

  go({ params: { step } }) { this.goTo(step) }

  goTo(step, { focus = true } = {}) {
    clearTimeout(this.timer)
    this.current = Math.min(Math.max(step, this.firstStep), this.lastStep)
    this.render()
    if (focus) this.focusTitle()
    this.announce()
  }

  // Une classe disponible touchée dans la cascade fait passer à l'étape 2 (une classe complète est désactivée).
  cascadeChanged({ target }) {
    if (target.type !== "radio" || target.disabled || !CLASSROOM_FIELD.test(target.name)) return

    this.hideRecap()
    this.goTo(2)
  }

  // « Ce n'est pas ta classe ? » : cascade rouverte, retour à l'étape 1.
  restart(event) {
    event.preventDefault()
    this.hideRecap()
    this.goTo(1)
  }

  // « Entrée » ne crée pas le compte avant l'étape 3 : la création reste un geste volontaire (le bouton y est). Sur une
  // étape « Continuer » (data-continue), Entrée vaut Continuer.
  enter(event) {
    if (this.current >= this.lastStep || ["BUTTON", "A", "TEXTAREA"].includes(event.target.tagName)) return

    event.preventDefault()
    if (this.currentStep?.hasAttribute("data-continue")) this.continue()
    else if (this.current === 2 && this.personComplete()) this.goTo(3)
  }

  // « Continuer » : le premier champ invalide de l'étape dit pourquoi (bulle du navigateur) et garde le focus ; sinon, l'étape suivante.
  // Sans data-invalid-message, un message de repli non vide : le numéro reste invalide (jamais une chaîne vide, qui le validerait).
  // Un numéro (type tel) n'a pas de pattern (collé sans JavaScript, le serveur le nettoie) : ses 10 chiffres se vérifient ici.
  continue() {
    const fields = [...(this.currentStep?.querySelectorAll("input, select") || [])].filter((field) => field.type !== "hidden")
    fields.filter((field) => field.type === "tel").forEach((field) => {
      field.setCustomValidity(field.value === "" || PHONE.test(field.value) ? "" : field.dataset.invalidMessage || field.title || "✕")
    })
    const invalid = fields.find((field) => !field.checkValidity())
    if (invalid) {
      invalid.reportValidity()
      invalid.focus()
      return
    }

    this.goTo(this.current + 1)
  }

  // Étape 2 : environ une seconde après la dernière frappe, si les quatre champs sont valides.
  personChanged() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.advanceIfPersonComplete(), this.delayValue)
  }

  advanceIfPersonComplete() {
    if (this.current !== 2 || !this.personComplete()) return

    this.goTo(3)
  }

  personComplete() {
    const step = this.stepTargets.find((element) => Number(element.dataset.step) === 2)
    if (!step) return false

    const texts = [...step.querySelectorAll("input:not([type=radio])")]
    const gender = step.querySelector("input[type=radio]:checked")
    const phone = step.querySelector("input[type=tel]")
    // La matière de l'enseignant est une liste obligatoire : sans valeur, on reste à l'étape 2.
    const lists = [...step.querySelectorAll("select[required]")]
    return texts.every((input) => input.value.trim() !== "" && input.checkValidity()) && lists.every((list) => list.value !== "") &&
           !!gender && PHONE.test(phone?.value || "")
  }

  render() {
    this.stepTargets.forEach((step) => { step.hidden = Number(step.dataset.step) !== this.current })
    this.counterTarget.textContent = this.counterValue.replace("%{n}", this.current)
    this.segmentTargets.forEach((segment, index) => {
      const reached = index < this.current
      segment.classList.toggle("bg-brand", reached)
      segment.classList.toggle("bg-line", !reached)
    })
    this.backTarget.hidden = this.current <= this.firstStep
    this.welcomeTargets.forEach((element) => { element.hidden = this.current !== this.firstStep })
    this.panelStepTargets.forEach((item) => this.renderPanelStep(item))
  }

  // Panneau d'ordinateur (UDR §3.5 bis) : étape faite = rond blanc à coche, en cours = rond blanc numéroté en 16 px, 500 et
  // aria-current="step", à venir = rond en contour.
  renderPanelStep(item) {
    const number = Number(item.dataset.step)
    const done = number < this.current
    const active = number === this.current
    if (active) item.setAttribute("aria-current", "step")
    else item.removeAttribute("aria-current")

    const mark = item.querySelector("[data-mark]")
    mark.textContent = done ? "\u2713" : String(number)
    mark.classList.toggle("bg-white", done || active)
    mark.classList.toggle("text-brand-strong", done || active)
    mark.classList.toggle("border", !done && !active)
    mark.classList.toggle("border-on-brand", !done && !active)

    const label = item.querySelector("[data-label]")
    label.classList.toggle("text-base", active)
    label.classList.toggle("font-medium", active)
    label.classList.toggle("text-sm", !active)
    const doneNote = item.querySelector("[data-done]")
    if (doneNote) doneNote.hidden = !done
  }

  focusTitle() {
    document.activeElement?.blur?.()
    this.stepTargets.find((step) => Number(step.dataset.step) === this.current)?.querySelector("legend")?.focus({ preventScroll: false })
  }

  // La région aria-live dit le changement d'étape, après coup (le sous-titre l'avait annoncé avant).
  announce() {
    const legend = this.stepTargets.find((step) => Number(step.dataset.step) === this.current)?.querySelector("legend")
    const text = this.announceValue.replace("%{n}", this.current).replace("%{title}", legend?.textContent.trim() || "")
    this.say(text)
  }

  say(text) {
    this.liveTarget.textContent = ""
    requestAnimationFrame(() => { this.liveTarget.textContent = text })
  }

  hideRecap() {
    if (this.hasRecapTarget) this.recapTarget.hidden = true
    if (this.hasPanelRecapTarget) this.panelRecapTarget.hidden = true
  }

  get currentStep() { return this.stepTargets.find((step) => Number(step.dataset.step) === this.current) }
  get firstStep() { return Math.min(...this.stepTargets.map((step) => Number(step.dataset.step))) }
  get lastStep() { return Math.max(...this.stepTargets.map((step) => Number(step.dataset.step))) }
}
