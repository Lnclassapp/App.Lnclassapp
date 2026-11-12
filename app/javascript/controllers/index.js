// ⚡ FRONT · controllers/index.js — enregistre tous les contrôleurs Stimulus par motif (esbuild-rails)
// Rôle : app/javascript/controllers/<ctx>/<nom>_controller.js a pour identifiant « <ctx>--<nom> » ; les contrôleurs hors ligne (offline/controllers/) sont chargés à la demande
// ADR  : 0051 · aucun manifeste à éditer : un lot dépose son fichier, il est enregistré
import { application } from "./application"
import controllers from "./**/*_controller.js"
import { registerOfflineControllers } from "../offline/lazy_controllers.js"

controllers.forEach((controller) => application.register(controller.name, controller.module.default))
registerOfflineControllers(application)
