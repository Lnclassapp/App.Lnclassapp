// ⚡ FRONT · classroom/signup_steps_controller — l'inscription élève découpée en trois étapes dans un seul formulaire
// Rôle : un seul fieldset visible ; la liste des étapes du panneau d'ordinateur suit l'étape ; le code de classe reconnu, une classe de la cascade touchée ou les quatre champs valides font avancer seuls ; retour sans perte ; annonce aria-live
// ADR  : 0109 (§4.4, §4.5) · UDR : 0135 (§3.1 à §3.8, §3.5 bis)
import { Controller } from "@hotwired/stimulus"

const CODE_LENGTH = 6
const CODE_URL_PLACEHOLDER = "__code__"
const CLASSROOM_FIELD = /\[classroom_public_id\]$/
const PHONE = /^\d{10}$/

export default class extends Controller {
  static targets = [
    "step", "segment", "counter", "live", "back", "welcome",
    "code", "codeField", "codeFrame", "checking", "checkFailed", "noCode", "cascade", "recap", "recapName", "recapSchool",
    "panelStep", "panelRecap", "panelRecapName", "panelRecapSchool"
  ]
  static values = {
    start: Number, counter: String, announce: String, codeUrl: String,
    delay: { type: Number, default: 1000 }
  }

  connect() {
    this.current = this.startValue
    this.render()
    this.syncCode()
    document.addEventListener("turbo:morph", this.refresh)
  }

  disconnect() {
    clearTimeout(this.timer)
    document.removeEventListener("turbo:morph", this.refresh)
  }

  // Un re-rendu 422 est un morphing : le contrôleur reste branché, le serveur a dit quelle étape ouvrir.
  refresh = () => {
    this.current = this.startValue
    this.render()
    this.syncCode()
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

  // Étape 1 : le code, au 6e caractère, est vérifié par le serveur (Turbo Frame) ; reconnu, on passe à l'étape 2.
  checkCode() {
    const code = this.normalized(this.codeTarget.value)
    if (this.codeTarget.value !== code) this.codeTarget.value = code
    this.resetCodeState()
    if (code.length < CODE_LENGTH) return

    this.checkingTarget.hidden = false
    const url = this.codeUrlValue.replace(CODE_URL_PLACEHOLDER, encodeURIComponent(code))
    if (this.codeFrameTarget.getAttribute("src") === url) this.codeFrameTarget.reload()
    else this.codeFrameTarget.src = url
  }

  // La réponse du frame : trouvée → étape 2 avec le rappel ; inconnue, complète ou trop de tentatives → on reste, le message est dans le frame.
  codeChecked() {
    const code = this.normalized(this.codeTarget.value)
    const pending = this.codeFrameTarget.getAttribute("src") || ""
    // Une réponse en retard, pour un code déjà modifié, n'avance personne.
    if (code.length < CODE_LENGTH || !pending.endsWith(encodeURIComponent(code))) return

    this.checkingTarget.hidden = true
    const found = this.codeFrameTarget.querySelector("#classroom-code-found")
    const full = this.codeFrameTarget.querySelector("#classroom-code-full")
    if (found && !full) {
      this.showRecap(found.dataset.classroomName, found.dataset.schoolLabel)
      return this.goTo(2)
    }
    if (this.codeFrameTarget.querySelector("#classroom-code-unknown")) this.markCodeInvalid()
  }

  // Requête en échec (`turbo:fetch-request-error`, réseau coupé) ou réponse sans le frame (`turbo:frame-missing`, 5xx), toutes deux
  // sur le frame : plus de « Vérification… », un message court relié au champ, et le `src` retiré pour qu'une nouvelle saisie relance.
  codeCheckFailed(event) {
    if (event.type === "turbo:frame-missing") event.preventDefault()
    // Une erreur en retard, pour un code déjà modifié ou vidé, ne dit rien.
    if (!this.codeFrameTarget.getAttribute("src")) return

    this.codeFrameTarget.removeAttribute("src")
    this.checkingTarget.hidden = true
    this.codeFrameTarget.replaceChildren(this.checkFailedTarget.content.cloneNode(true))
    this.describeCode(true)
  }

  // « Je n'ai pas de code » : la cascade s'ouvre (CSS), le champ code se vide et ne part plus avec le formulaire.
  toggleCascade() {
    if (this.noCodeTarget.checked) {
      this.codeTarget.value = ""
      this.resetCodeState()
    }
    this.syncCode()
    if (!this.noCodeTarget.checked) this.codeTarget.focus()
  }

  // Une classe disponible touchée dans la cascade fait passer à l'étape 2 (une classe complète est désactivée).
  cascadeChanged({ target }) {
    if (target.type !== "radio" || target.disabled || !CLASSROOM_FIELD.test(target.name)) return

    this.hideRecap()
    this.goTo(2)
  }

  // « Ce n'est pas ta classe ? » : code vidé, case décochée, retour à l'étape 1.
  restart(event) {
    event.preventDefault()
    this.noCodeTarget.checked = false
    this.codeTarget.value = ""
    this.resetCodeState()
    this.syncCode()
    this.hideRecap()
    this.goTo(1)
  }

  // « Entrée » ne crée pas le compte avant l'étape 3 : la création reste un geste volontaire (le bouton y est).
  enter(event) {
    if (this.current >= this.lastStep || ["BUTTON", "A", "TEXTAREA"].includes(event.target.tagName)) return

    event.preventDefault()
    if (this.current === 2 && this.personComplete()) this.goTo(3)
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
      segment.classList.toggle("bg-brand-strong", reached)
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
    mark.classList.toggle("border-white", !done && !active)

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
    this.liveTarget.textContent = ""
    requestAnimationFrame(() => { this.liveTarget.textContent = text })
  }

  // Le rappel de classe : au-dessus du champ de l'étape 2 sur téléphone, dans le panneau sous l'étape 1 sur ordinateur (CA-C9).
  showRecap(name, school) {
    if (this.hasRecapTarget) {
      this.recapNameTarget.textContent = name || ""
      this.recapSchoolTarget.textContent = school || ""
      this.recapTarget.hidden = false
    }
    if (this.hasPanelRecapTarget) {
      this.panelRecapNameTarget.textContent = name || ""
      this.panelRecapSchoolTarget.textContent = school || ""
      this.panelRecapTarget.hidden = false
    }
  }

  hideRecap() {
    if (this.hasRecapTarget) this.recapTarget.hidden = true
    if (this.hasPanelRecapTarget) this.panelRecapTarget.hidden = true
  }

  // Sans JavaScript le code et la cascade sont tous deux dans la page ; ici, la case en choisit un : l'autre est caché, et le
  // code, désactivé, ne part plus avec le formulaire.
  syncCode() {
    if (!this.hasCodeTarget || !this.hasNoCodeTarget) return

    const cascade = this.noCodeTarget.checked
    this.codeTarget.disabled = cascade
    this.codeFieldTarget.hidden = cascade
    this.cascadeTarget.hidden = !cascade
  }

  resetCodeState() {
    if (!this.hasCodeFrameTarget) return

    this.codeFrameTarget.removeAttribute("src")
    this.codeFrameTarget.replaceChildren()
    this.checkingTarget.hidden = true
    this.codeTarget.removeAttribute("aria-invalid")
    this.describeCode(false)
    this.hideRecap()
  }

  markCodeInvalid() {
    this.codeTarget.setAttribute("aria-invalid", "true")
    this.describeCode(true)
  }

  // Le message du frame (code inconnu) décrit le champ tant qu'il est là.
  describeCode(on) {
    const id = this.codeFrameTarget.id
    const described = (this.codeTarget.getAttribute("aria-describedby") || "").split(" ").filter((part) => part && part !== id)
    if (on) described.push(id)
    if (described.length) this.codeTarget.setAttribute("aria-describedby", described.join(" "))
    else this.codeTarget.removeAttribute("aria-describedby")
  }

  normalized(raw) {
    return raw.toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, CODE_LENGTH)
  }

  get firstStep() { return Math.min(...this.stepTargets.map((step) => Number(step.dataset.step))) }
  get lastStep() { return Math.max(...this.stepTargets.map((step) => Number(step.dataset.step))) }
}
