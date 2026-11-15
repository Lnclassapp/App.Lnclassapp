// ⚡ FRONT · hash_redirect_controller — mène une ancienne adresse « page#ancre » vers la page qui porte désormais l'ancre
// Rôle : si l'adresse courante finit par `#<hash>`, remplace la visite par `url` (sans entrée d'historique en plus) ; sinon ne fait rien ; jamais de requête de plus que la navigation
//        borné : pas deux fois la même paire d'adresses en moins de WINDOW ms dans un onglet (marqueur daté en sessionStorage) ; un 301 resté en cache de l'ancienne « /fiche » ne reboucle plus (issue 635), une visite plus tardive redirige de nouveau
// UDR  : 0173 §3 (leçon : la fiche de révision a sa propre page ; « /courses/<slug>#fiche-de-revision » continue de marcher)
import { Controller } from "@hotwired/stimulus"

// Un 301 en cache referme son tour en quelques dizaines de millisecondes ; une visite voulue vient bien plus tard.
const WINDOW = 10000

export default class extends Controller {
  static values = { hash: String, url: String }

  connect() {
    if (window.location.hash !== `#${this.hashValue}`) return
    if (!this.claim()) return

    window.location.replace(this.urlValue)
  }

  // Pose le marqueur daté « cette paire d'adresses vient d'être remplacée dans cet onglet ». Faux si le précédent date de moins de WINDOW ms
  // (une horloge qui recule compte comme récent), ou si le marqueur ne peut pas être écrit (stockage refusé) : sans marqueur, rien ne borne
  // le remplacement, donc on ne remplace pas. L'ancre garde alors la page.
  claim() {
    const key = `hash-redirect:${this.hashValue}>${this.urlValue}`
    try {
      const now = Date.now()
      const previous = Number(window.sessionStorage.getItem(key))
      if (previous && now - previous < WINDOW) return false

      window.sessionStorage.setItem(key, String(now))
      return true
    } catch (_error) {
      return false
    }
  }
}
