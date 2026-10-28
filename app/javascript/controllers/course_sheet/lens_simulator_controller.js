// ⚡ FRONT · course_sheet/lens_simulator_controller — le simulateur de lentille : coquille Stimulus, la logique est dans lib/course_sheet/lens_simulator
// Rôle : `lib/course_sheet/lens_simulator` (gestes, rayons, image, mesures) est chargé par import(), à la demande ; il lit la figure (data-d, data-h, data-f, data-grid, data-texts)
// ADR  : 0110-fiche-de-cours-en-donnees-importees, 0114 (budget du point d'entrée commun) · sans JavaScript, le serveur dessine la position de départ
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async connect() {
    try {
      const { LensSimulator } = await import("../../lib/course_sheet/lens_simulator")
      if (this.element.isConnected && !this.simulator) this.simulator = new LensSimulator(this.element)
    } catch (error) {
      // Chargement refusé : la figure reste dans sa position de départ.
      console.warn("lentille : simulateur indisponible", error)
    }
  }

  disconnect() {
    this.simulator?.destroy()
    this.simulator = null
  }
}
