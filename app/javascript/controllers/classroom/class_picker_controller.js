// ⚡ FRONT · classroom/class_picker_controller — cascade établissement → niveau → classe de l'inscription élève
// Rôle : l'établissement trouvé (school--school-search:picked) pose le src des niveaux, chaque choix vide ce qui suit ; l'envoi attend une classe cochée ; liste absente → erreur
// ADR  : 0051, 0085, 0142-recherche-etablissement · UDR : 0081 (§3.3), 0177-champ-etablissement
import { Controller } from "@hotwired/stimulus"

const SCHOOL = "__school__"
const LEVEL = "__level__"

export default class extends Controller {
  static targets = ["levels", "classrooms", "submit", "loadError"]
  static values = { levelsUrl: String, classroomsUrl: String }

  // Un re-rendu 422 est un morphing : il remet le bouton du serveur (actif) sans reconnecter le contrôleur.
  connect() {
    this.sync()
    document.addEventListener("turbo:morph", this.refresh)
  }

  disconnect() {
    document.removeEventListener("turbo:morph", this.refresh)
  }

  refresh = () => this.sync()

  // Un établissement coché dans la recherche (UDR champ établissement) : ses niveaux ; le niveau et la classe se vident.
  loadLevels({ detail: { publicId } }) {
    this.clear(this.classroomsTarget)
    if (!publicId) return this.clear(this.levelsTarget)

    this.show(this.levelsTarget, this.levelsUrlValue.replace(SCHOOL, encodeURIComponent(publicId)))
  }

  // Une nouvelle saisie a retiré l'établissement : plus de niveau ni de classe.
  clearSchool() {
    this.clear(this.levelsTarget, this.classroomsTarget)
  }

  loadClassrooms({ target: { value } }) {
    const school = this.element.querySelector("input[name$='[school_public_id]']:checked")?.value
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
