// ⚡ FRONT · course_sheet/argument_highlighter_controller — coquille Stimulus des surligneurs : la logique est dans lib/course_sheet/argument_highlighter
// Rôle : charge `lib/course_sheet/argument_highlighter` par import(), à la demande, pour tenir le budget du JS commun ; sans lui le texte se lit non surligné
// ADR  : 0114 (budget du JS commun), 0110 · UDR : 0137 · modèle : assessment/copy_controller · reset avant le cache de Turbo (retour arrière)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async connect() {
    let module
    try {
      module = await import("../../lib/course_sheet/argument_highlighter")
    } catch (error) {
      // Chargement refusé : le texte reste lisible, sans surligneurs.
      console.warn("surligneurs : indisponibles", error)
      return
    }
    if (!this.element.isConnected) return

    // Pas de try/catch ici : une erreur du constructeur remonte dans la console (rejet non intercepté), elle n'est jamais avalée.
    this.view?.destroy()
    this.view = new module.ArgumentHighlighter(this.element)
  }

  // Avant que Turbo ne garde la page en cache : on la rend telle qu'au chargement, sinon le retour arrière la montre à moitié allumée.
  reset() {
    this.view?.destroy()
    this.view = null
  }

  disconnect() {
    this.reset()
  }
}
