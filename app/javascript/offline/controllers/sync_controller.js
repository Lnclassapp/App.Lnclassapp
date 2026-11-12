// ⚡ FRONT · offline-sync — envoie la file des copies rendues hors ligne : à l'ouverture de la page, au retour du réseau, avant la déconnexion
// Rôle : porté par le layout sur chaque page ; ne fait rien sans clé d'appareil (déconnecté) ; un échec est écrit dans la console, jamais avalé
// ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.2, §4.5) · menace P4 (seule la file de la clé de la page part)
import { Controller } from "../controller_base.js"
import { registerBeforePurge } from "../store.js"
import { flush } from "../sync.js"

export default class extends Controller {
  connect() {
    this.send = () => flush().then((summary) => {
      if (summary?.error) console.warn("Envoi des copies hors ligne impossible", summary.error)
    }).catch((error) => console.error("Envoi des copies hors ligne", error))
    window.addEventListener("online", this.send)
    // La déconnexion attend l'envoi (store.runBeforePurge) : la file part avant que l'appareil soit vidé.
    // Elle bloque la déconnexion si l'envoi a échoué ou si des copies restent en attente : mieux vaut rester connecté que perdre une copie.
    this.unregister = registerBeforePurge(async () => {
      const summary = await flush()
      if (summary.error || summary.pending > 0) throw new Error(`Copies hors ligne non envoyées (${summary.error || `${summary.pending} en attente`})`)
    })
    this.send()
  }

  disconnect() {
    window.removeEventListener("online", this.send)
    this.unregister?.()
  }
}
