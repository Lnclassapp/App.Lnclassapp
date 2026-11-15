// ⚡ FRONT · hash_redirect_controller — mène une ancienne adresse « page#ancre » vers la page qui porte désormais l'ancre
// Rôle : si l'adresse courante finit par `#<hash>`, remplace la visite par `url` (sans entrée d'historique en plus) ; sinon ne fait rien ; jamais de requête de plus que la navigation
// UDR  : 0173 §3 (leçon : la fiche de révision a sa propre page ; « /courses/<slug>#fiche-de-revision » continue de marcher)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { hash: String, url: String }

  connect() {
    if (window.location.hash !== `#${this.hashValue}`) return

    window.location.replace(this.urlValue)
  }
}
