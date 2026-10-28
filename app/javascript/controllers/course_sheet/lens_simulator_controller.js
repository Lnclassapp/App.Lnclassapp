// ⚡ FRONT · course_sheet/lens_simulator_controller — le simulateur de lentille : coquille Stimulus, la logique est dans lib/course_sheet/lens_simulator
// Rôle : `lib/course_sheet/lens_simulator` (gestes, rayons, image, mesures) est chargé par import(), à la demande ; il lit la figure (data-d, data-h, data-f, data-grid, data-texts)
// ADR  : 0110-fiche-de-cours-en-donnees-importees, 0114 (budget du point d'entrée commun) · sans JavaScript, le serveur dessine la position de départ · reset avant le cache de Turbo (retour arrière), modèle : argument_highlighter_controller
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async connect() {
    // L'état du serveur, gardé avant tout geste : c'est lui que reset() remet avant le cache de Turbo.
    this.initial ??= { html: this.element.innerHTML, data: { d: this.element.dataset.d, h: this.element.dataset.h, f: this.element.dataset.f, grid: this.element.dataset.grid } }

    let module
    try {
      module = await import("../../lib/course_sheet/lens_simulator")
    } catch (error) {
      // Chargement refusé : la figure reste dans l'état du serveur.
      console.warn("lentille : simulateur indisponible", error)
      return
    }
    if (!this.element.isConnected) return

    // Pas de try/catch ici : une erreur du constructeur remonte dans la console (rejet non intercepté), elle n'est jamais avalée.
    this.simulator?.destroy()
    this.simulator = new module.LensSimulator(this.element)
  }

  // Avant que Turbo ne garde la page en cache : on la rend telle que le serveur l'a écrite, sinon le retour arrière la montre à moitié jouée.
  reset() {
    if (!this.simulator) return

    this.simulator.destroy()
    this.simulator = null
    this.element.innerHTML = this.initial.html
    Object.assign(this.element.dataset, this.initial.data)
    delete this.element.dataset.ready
  }

  disconnect() {
    this.reset()
  }
}
