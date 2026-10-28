// ⚡ FRONT · course_sheet/writing_controller — coquille Stimulus de « Ma rédaction » : la logique est dans lib/course_sheet/writing
// Rôle : charge `lib/course_sheet/writing` par import(), à la demande, pour tenir le budget du JS commun ; sans lui la zone de texte reste un champ libre
// ADR  : 0114 (budget du JS commun), 0110 · UDR : 0137 · modèle : assessment/copy_controller · rien n'est envoyé au serveur
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async connect() {
    try {
      const { Writing } = await import("../../lib/course_sheet/writing")
      if (!this.element.isConnected) return

      this.view?.destroy()
      this.view = new Writing(this.element)
    } catch (error) {
      // Chargement refusé : le champ reste utilisable, sans liste de vérification.
      console.warn("rédaction : vérifications indisponibles", error)
    }
  }

  disconnect() {
    this.view?.destroy()
    this.view = null
  }
}
