// ⚡ FRONT · classroom/first_exercise_prompt_controller — le cadre différé de la fenêtre « Ton premier exercice »
// Rôle : une réponse sans le cadre (session expirée, erreur) laisse le cadre vide : aucun message, aucune navigation (turbo:frame-missing)
// UDR  : accueil-eleve-qr-fenetre-inviter (§3.2, états : erreur)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  missing(event) {
    event.preventDefault()
  }
}
