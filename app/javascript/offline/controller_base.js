// ⚡ FRONT · offline/controller_base.js — la classe Controller de Stimulus, prêtée par le point d'entrée commun
// Rôle : le morceau hors ligne n'importe pas Stimulus (sinon esbuild sort Stimulus du point d'entrée dans un morceau partagé chargé d'office) ; lazy_controllers.js la prête avant l'import
// ADR  : 0051 (budget du point d'entrée commun), hors-connexion §4.2 · absente : erreur franche au chargement, jamais une classe vide
export const STIMULUS_CONTROLLER_KEY = "__lnclassStimulusController"

const base = globalThis[STIMULUS_CONTROLLER_KEY]
if (typeof base !== "function") throw new Error("[offline] Controller de Stimulus non prêté avant le chargement des contrôleurs hors ligne")

export const Controller = base
