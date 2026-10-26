// ⚡ FRONT · panel_focus_controller — le Turbo Frame du panneau « Mon compte » : focus sur le titre de l'écran chargé, et ses échecs
// Rôle : l'écran remplacé disparaît avec le focus ; on focalise `[data-panel-focus-title]`, sinon le premier h1/h2 du contenu chargé ;
//        une réponse sans le frame (erreur, connexion expirée) s'affiche en pleine page ; une requête coupée se dit dans le panneau
// UDR  : 0054 (§3.3) : pas d'attribut `autofocus` · branché sur le frame de « Mon compte » (turbo:frame-load, turbo:frame-missing,
//        turbo:fetch-request-error) ; le focus reste dans le <dialog> · le message vient du serveur (<template> `failed`)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["failed"]

  focus() {
    const title = this.element.querySelector("[data-panel-focus-title]") || this.element.querySelector("h1, h2")
    if (!title) return

    // Titre focalisable par programme seulement (hors ordre de tabulation), sans contour au clic.
    if (!title.hasAttribute("tabindex")) title.setAttribute("tabindex", "-1")
    title.classList.add("outline-none")
    title.focus({ preventScroll: false })
  }

  // Réponse sans le frame du panneau (404 d'un établissement déjà quitté, 500, connexion expirée) : sans cela Turbo y écrirait
  // « Content missing ». La vraie page (erreur en français, ou connexion) s'affiche en pleine page, le panneau et son focus quittés.
  missing(event) {
    event.preventDefault()
    event.detail.visit(event.detail.response)
  }

  // Requête en échec (réseau coupé) : rien n'est parti, l'écran reste tel quel. Une confirmation ouverte (« Retirer » d'un
  // établissement) se ferme, sinon elle cacherait le message ; le message tient en tête du panneau, une seule fois.
  requestFailed() {
    if (!this.hasFailedTarget) return

    this.element.querySelectorAll("dialog[open]").forEach((dialog) => dialog.close())
    this.element.querySelector("[data-panel-failed]")?.remove()
    const message = this.failedTarget.content.cloneNode(true)
    this.element.prepend(message)
    this.element.querySelector("[data-panel-failed]")?.scrollIntoView({ block: "nearest" })
  }
}
