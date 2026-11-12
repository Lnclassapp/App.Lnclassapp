// ⚡ FRONT · offline-sync — envoie la file des copies rendues hors ligne : à l'ouverture de la page, au retour du réseau, avant la déconnexion
// Rôle : porté par le layout sur chaque page ; ne fait rien sans clé d'appareil (déconnecté) ; un échec est écrit dans la console, jamais avalé
// ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.2, §4.5) · menace P4 (seule la file de la clé de la page part)
import { Controller } from "@hotwired/stimulus"
import { registerBeforePurge } from "../offline/store.js"
import { flush } from "../offline/sync.js"

export default class extends Controller {
  connect() {
    this.send = () => flush().catch((error) => console.error("Envoi des copies hors ligne", error))
    window.addEventListener("online", this.send)
    // La déconnexion attend l'envoi (store.runBeforePurge) : la file part avant que l'appareil soit vidé.
    this.unregister = registerBeforePurge(() => flush())
    this.send()
  }

  disconnect() {
    window.removeEventListener("online", this.send)
    this.unregister?.()
  }
}
