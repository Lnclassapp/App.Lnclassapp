// ⚡ FRONT · course_sheet/lens_construction_controller — « Place l'image » : coquille Stimulus, la logique est dans lib/course_sheet/lens_construction
// Rôle : `lib/course_sheet/lens_construction` (énoncés, marqueur, jugement, score, solution) est chargé par import(), à la demande ; il lit l'exercice (data-f, data-d, data-h, data-texts)
// ADR  : 0110-fiche-de-cours-en-donnees-importees, 0114 (budget du point d'entrée commun) · sans JavaScript, le serveur dessine le premier énoncé
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async connect() {
    try {
      const { LensConstruction } = await import("../../lib/course_sheet/lens_construction")
      if (this.element.isConnected && !this.construction) this.construction = new LensConstruction(this.element)
    } catch (error) {
      // Chargement refusé : l'exercice reste sur son premier énoncé, sans jugement.
      console.warn("lentille : entraînement indisponible", error)
    }
  }

  disconnect() {
    this.construction?.destroy()
    this.construction = null
  }
}
