// ⚡ FRONT · classroom/first_exercise_prompt_controller — le cadre différé de la fenêtre « Ton premier exercice » (accueil élève)
// Rôle : une réponse sans le cadre (session expirée, erreur) laisse le cadre vide (turbo:frame-missing) ; « Plus tard » ou Échap
//        taisent la fenêtre jusqu'à la fin de la visite (sessionStorage de l'onglet) : le cadre se charge encore, n'affiche plus rien
// UDR  : accueil-eleve-qr-fenetre-inviter (§3.2, états : erreur), 0185 §3.1
import { Controller } from "@hotwired/stimulus"

const KEY = "lnclass:first-exercise-later"

export default class extends Controller {
  connect() {
    // « close » ne remonte pas : on l'écoute en capture sur le cadre. « Commencer » quitte la page sans fermer la fenêtre.
    this.silence = (event) => {
      if (event.target.id === "student_first_exercise_modal") this.remember()
    }
    this.element.addEventListener("close", this.silence, true)
  }

  disconnect() {
    this.element.removeEventListener("close", this.silence, true)
  }

  missing(event) {
    event.preventDefault()
  }

  // Fenêtre déjà repoussée pendant cette visite : le cadre se charge (le serveur clôt la fenêtre si une copie est rendue) mais reste vide.
  render(event) {
    if (this.silenced()) event.detail.render = () => {}
  }

  remember() {
    try {
      window.sessionStorage.setItem(KEY, "1")
    } catch {
      // Stockage refusé : la fenêtre reviendra au prochain passage sur l'accueil.
    }
  }

  silenced() {
    try {
      return window.sessionStorage.getItem(KEY) === "1"
    } catch {
      return false
    }
  }
}
