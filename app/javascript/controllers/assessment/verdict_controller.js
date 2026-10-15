// ⚡ FRONT · assessment/verdict_controller — le verdict arrivé par Turbo Stream reçoit le focus
// Rôle : le bouton « Valider » a disparu avec la question ; le focus passe au titre du verdict, annoncé par son aria-live
// UDR  : 0087 §3.10 · sans JavaScript, la page rechargée commence par la croix, comme toute page de la séance
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["title"]

  connect() {
    this.titleTarget.focus({ preventScroll: true })
  }
}
