// ⚡ FRONT · teams/nested_form_controller — ajoute et retire des champs imbriqués (questions, propositions) sans requête
// Rôle : clone le <template> rendu par le serveur en remplaçant son index fictif par un index unique ; « Retirer » ôte l'élément
// UDR  : 0006, 0017 · Turbo ne sait pas ajouter un champ sans aller-retour : c'est le cas où Stimulus est justifié
import { Controller } from "@hotwired/stimulus"

let sequence = 0

export default class extends Controller {
  static targets = ["list", "template"]
  static values = { placeholder: String, item: String }

  // L'index vient de l'horloge : il ne croise jamais les index 0, 1, 2… des éléments rendus par le serveur.
  add() {
    const index = `${Date.now()}${sequence++}`
    const html = this.templateTarget.innerHTML.replaceAll(this.placeholderValue, index)
    this.listTarget.insertAdjacentHTML("beforeend", html)
    this.listTarget.lastElementChild.querySelector("textarea, input:not([type=hidden])")?.focus()
  }

  // Les questions sont remplacées en bloc à l'enregistrement : un élément retiré du formulaire n'est simplement plus envoyé.
  remove(event) {
    event.target.closest(this.itemValue)?.remove()
  }
}
