// ⚡ FRONT · offline/controllers.js — les six contrôleurs hors ligne, en un seul morceau chargé à la demande
// Rôle : identifiant Stimulus → classe ; importé par offline/lazy_controllers.js à la première connexion d'un contrôleur hors ligne
// ADR  : 0051 (budget du point d'entrée commun), hors-connexion §4.2 · le layout porte offline-session : le morceau est chargé en ligne sur chaque page, donc gardé par le programme d'arrière-plan
import OfflineCopyController from "./controllers/copy_controller.js"
import OfflineQueueController from "./controllers/queue_controller.js"
import OfflineSessionController from "./controllers/session_controller.js"
import OfflineStartController from "./controllers/start_controller.js"
import OfflineStatusController from "./controllers/status_controller.js"
import OfflineSyncController from "./controllers/sync_controller.js"

export default {
  "offline-copy": OfflineCopyController,
  "offline-queue": OfflineQueueController,
  "offline-session": OfflineSessionController,
  "offline-start": OfflineStartController,
  "offline-status": OfflineStatusController,
  "offline-sync": OfflineSyncController
}
