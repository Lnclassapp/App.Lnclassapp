// ⚡ FRONT · offline/lazy_controllers.js — enregistre les contrôleurs hors ligne sans les mettre dans le point d'entrée commun
// Rôle : un contrôleur d'attente par identifiant ; à sa première connexion, importe offline/controllers.js et enregistre les vrais, que Stimulus substitue aux attentes sur les éléments déjà présents
// ADR  : 0051 (budget de 61 Ko gzip), hors-connexion §4.2 · même principe que copy_sheet dans assessment/copy_controller.js
import { Controller } from "@hotwired/stimulus"

// Même nom que STIMULUS_CONTROLLER_KEY de controller_base.js, qui n'est pas importé ici pour rester hors du point d'entrée.
const STIMULUS_CONTROLLER_KEY = "__lnclassStimulusController"

export const OFFLINE_IDENTIFIERS = [ "offline-copy", "offline-queue", "offline-session", "offline-start", "offline-status", "offline-sync" ]

let loading = null

export function loadOfflineControllers(application, load = () => import("./controllers.js")) {
  globalThis[STIMULUS_CONTROLLER_KEY] ||= Controller
  loading ||= load().then(({ default: controllers }) => {
    Object.entries(controllers).forEach(([identifier, controller]) => application.register(identifier, controller))
  }).catch((error) => {
    loading = null
    console.error("[offline] contrôleurs hors ligne non chargés", error)
  })
  return loading
}

export function registerOfflineControllers(application, load) {
  OFFLINE_IDENTIFIERS.forEach((identifier) => {
    application.register(identifier, class extends Controller {
      connect() { loadOfflineControllers(this.application, load) }
    })
  })
}
