// ⚡ FRONT · course_sheet/writing_controller — coquille Stimulus de « Ma rédaction » : la logique est dans lib/course_sheet/writing
// Rôle : charge `lib/course_sheet/writing` par import(), à la demande, pour tenir le budget du JS commun ; sans lui la zone de texte reste un champ libre
// ADR  : 0114 (budget du JS commun), 0110 · UDR : 0137 · modèle : assessment/copy_controller · rien n'est envoyé au serveur · reset avant le cache de Turbo
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async connect() {
    let module
    try {
      module = await import("../../lib/course_sheet/writing")
    } catch (error) {
      // Chargement refusé : le champ reste utilisable, sans liste de vérification.
      console.warn("rédaction : vérifications indisponibles", error)
      return
    }
    if (!this.element.isConnected) return

    // Pas de try/catch ici : une erreur du constructeur remonte dans la console (rejet non intercepté), elle n'est jamais avalée.
    this.view?.destroy()
    this.view = new module.Writing(this.element)
  }

  // Avant que Turbo ne garde la page en cache : la liste revient à zéro, comme la zone de texte que le cache ne restitue pas.
  reset() {
    this.view?.destroy()
    this.view = null
  }

  disconnect() {
    this.reset()
  }
}
