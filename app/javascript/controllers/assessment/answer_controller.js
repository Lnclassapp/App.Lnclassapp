// ⚡ FRONT · assessment/answer_controller — « Valider » reste désactivé tant que la réponse est incomplète
// Rôle : prêt quand le formulaire est valide (radio choisie, champ rempli, nombre lisible, listes choisies) et, pour plusieurs
//        réponses, quand le nombre demandé de cases est coché ; les contrôleurs de type déclenchent `input` après chaque geste
// UDR  : 0087 §3.2, §3.4 · sans JavaScript, le bouton reste actif et le serveur refuse une réponse incomplète (422)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit", "choice"]

  connect() {
    this.check()
  }

  check() {
    const expected = this.element.querySelector("[data-expected-count]")
    const ready = expected
      ? this.choiceTargets.filter((choice) => choice.checked).length === Number(expected.dataset.expectedCount)
      : this.element.checkValidity()
    this.submitTarget.disabled = !ready
  }
}
