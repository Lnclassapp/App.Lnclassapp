// ⚡ FRONT · classroom/class_picker_controller — cascade DRENA → établissement → niveau → classe de l'inscription élève
// Rôle : chaque choix pose le src du frame suivant et vide ceux d'après ; « Créer mon compte » attend une classe cochée ; liste absente → erreur
// ADR  : 0051, 0083 · UDR : 0079 (§3.3), sur le modèle de school/drena_schools_controller
import { Controller } from "@hotwired/stimulus"

const DRENA = "__drena__"
const SCHOOL = "__school__"
const LEVEL = "__level__"

export default class extends Controller {
  static targets = ["schools", "levels", "classrooms", "submit", "loadError"]
  static values = { schoolsUrl: String, levelsUrl: String, classroomsUrl: String }

  // Un re-rendu 422 est un morphing : il remet le bouton du serveur (actif) sans reconnecter le contrôleur.
  connect() {
    this.sync()
    document.addEventListener("turbo:morph", this.refresh)
  }

  disconnect() {
    document.removeEventListener("turbo:morph", this.refresh)
  }

  refresh = () => this.sync()

  loadSchools({ target: { value } }) {
    this.clear(this.levelsTarget, this.classroomsTarget)
    if (!value) return this.clear(this.schoolsTarget)

    this.show(this.schoolsTarget, this.schoolsUrlValue.replace(DRENA, encodeURIComponent(value)))
  }

  // Changer d'établissement efface le niveau et la classe.
  loadLevels({ target: { value } }) {
    this.clear(this.classroomsTarget)
    if (!value) return this.clear(this.levelsTarget)

    this.show(this.levelsTarget, this.levelsUrlValue.replace(SCHOOL, encodeURIComponent(value)))
  }

  loadClassrooms({ target: { value } }) {
    const school = this.schoolsTarget.querySelector("select")?.value
    if (!value || !school) return this.clear(this.classroomsTarget)

    const url = this.classroomsUrlValue.replace(SCHOOL, encodeURIComponent(school)).replace(LEVEL, encodeURIComponent(value))
    this.show(this.classroomsTarget, url)
  }

  // Réponse sans son frame (404, 500) ou réseau coupé : l'état d'erreur, avec l'adresse du frame en reprise.
  missing(event) {
    event.preventDefault?.()
    const frame = event.currentTarget
    const error = this.loadErrorTarget.content.cloneNode(true)
    error.querySelectorAll("a").forEach((link) => link.setAttribute("href", frame.getAttribute("src") || ""))
    frame.replaceChildren(error)
    this.sync()
  }

  // Sans JavaScript, le bouton n'est jamais désactivé ; ici, il attend qu'une classe soit cochée. Par un lien, pas de cascade.
  sync() {
    if (!this.hasSubmitTarget || !this.hasClassroomsTarget) return

    this.submitTarget.disabled = !this.classroomsTarget.querySelector("input[type=radio]:checked:not(:disabled)")
  }

  show(frame, url) {
    if (frame.getAttribute("src") === url) frame.reload()
    else frame.src = url
    this.sync()
  }

  clear(...frames) {
    frames.forEach((frame) => {
      frame.removeAttribute("src")
      frame.replaceChildren()
    })
    this.sync()
  }
}
