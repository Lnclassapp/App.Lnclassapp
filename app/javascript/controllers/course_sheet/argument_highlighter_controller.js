// ⚡ FRONT · course_sheet/argument_highlighter_controller — coquille Stimulus des surligneurs : la logique est dans lib/course_sheet/argument_highlighter
// Rôle : charge `lib/course_sheet/argument_highlighter` par import(), à la demande, pour tenir le budget du JS commun ; sans lui le texte se lit non surligné
// ADR  : 0114 (budget du JS commun), 0110 · UDR : 0137 · modèle : assessment/copy_controller
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async connect() {
    try {
      const { ArgumentHighlighter } = await import("../../lib/course_sheet/argument_highlighter")
      if (!this.element.isConnected) return

      this.view?.destroy()
      this.view = new ArgumentHighlighter(this.element)
    } catch (error) {
      // Chargement refusé : le texte reste lisible, sans surligneurs.
      console.warn("surligneurs : indisponibles", error)
    }
  }

  disconnect() {
    this.view?.destroy()
    this.view = null
  }
}
