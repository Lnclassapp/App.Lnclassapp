// ⚡ FRONT · push_switch_controller — envoie le formulaire d'une case « Automatique » dès qu'elle change
// Rôle : pose aria-busy et verrouille la case jusqu'à la réponse ; sans JavaScript, le bouton « Enregistrer » du <noscript> reste
// UDR  : XXXX écran notifications de l'équipe (§3.3) · le contrôleur `autosubmit` attend un motif de saisie, il ne convient pas
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit() {
    this.element.setAttribute("aria-busy", "true")
    this.element.requestSubmit()
  }

  // turbo:submit-end : la ligne est remplacée par la réponse ; si l'envoi a échoué (réseau), la case se libère.
  done() {
    this.element.removeAttribute("aria-busy")
  }
}
