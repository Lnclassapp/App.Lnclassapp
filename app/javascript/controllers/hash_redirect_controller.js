// ⚡ FRONT · hash_redirect_controller — mène une ancienne adresse « page#ancre » vers la page qui porte désormais l'ancre
// Rôle : si l'adresse courante finit par `#<hash>`, remplace la visite par `url` (sans entrée d'historique en plus) ; sinon ne fait rien ; jamais de requête de plus que la navigation
//        borné : une seule fois par onglet et par paire d'adresses (marqueur en sessionStorage) ; un 301 resté en cache de l'ancienne « /fiche » ne reboucle plus (issue 635)
// UDR  : 0173 §3 (leçon : la fiche de révision a sa propre page ; « /courses/<slug>#fiche-de-revision » continue de marcher)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { hash: String, url: String }

  connect() {
    if (window.location.hash !== `#${this.hashValue}`) return
    if (!this.claim()) return

    window.location.replace(this.urlValue)
  }

  // Pose le marqueur « cette paire d'adresses a déjà été remplacée dans cet onglet ». Faux s'il est déjà posé, ou s'il ne peut pas
  // l'être (stockage refusé) : sans marqueur, rien ne borne le remplacement, donc on ne remplace pas. L'ancre garde alors la page.
  claim() {
    const key = `hash-redirect:${this.hashValue}>${this.urlValue}`
    try {
      if (window.sessionStorage.getItem(key)) return false

      window.sessionStorage.setItem(key, "1")
      return true
    } catch (_error) {
      return false
    }
  }
}
