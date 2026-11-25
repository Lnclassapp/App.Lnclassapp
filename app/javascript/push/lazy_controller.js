// ⚡ FRONT · push/lazy_controller.js — enregistre le contrôleur d'abonnement Web Push sans le mettre dans le point d'entrée commun
// Rôle : un contrôleur d'attente « push-subscription » ; à sa première connexion il importe push_subscription_controller.js et l'enregistre à sa place, Stimulus le substitue sur les éléments déjà présents
// ADR  : 0051 (budget de 61 Ko gzip), 0146 · même principe que offline/lazy_controllers.js
import { Controller } from "@hotwired/stimulus"

export const PUSH_IDENTIFIER = "push-subscription"

let loading = null

export function loadPushController(application, load = () => import("./push_subscription_controller.js")) {
  loading ||= load().then(({ default: controller }) => application.register(PUSH_IDENTIFIER, controller)).catch((error) => {
    loading = null
    console.error("[push] contrôleur d'abonnement non chargé", error)
  })
  return loading
}

export function registerPushController(application, load) {
  application.register(PUSH_IDENTIFIER, class extends Controller {
    connect() { loadPushController(this.application, load) }
  })
}
