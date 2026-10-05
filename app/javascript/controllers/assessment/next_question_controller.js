// ⚡ FRONT · assessment/next_question_controller — « Question suivante » sans requête : la question arrivée avec le verdict
// Rôle : remplace le frame « question » par celui du <template> joint au verdict, puis met le focus sur l'énoncé
// UDR  : 0076 §3.3 · ADR : 0076 · sans question jointe, ou sans JavaScript, le lien charge la session comme avant
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["question"]

  show(event) {
    const frame = this.hasQuestionTarget && this.questionTarget.content.querySelector("turbo-frame#question")
    if (!frame) return

    event.preventDefault()
    const question = document.importNode(frame, true)
    this.element.closest("turbo-frame#question").replaceWith(question)
    // Le bouton cliqué a disparu : le focus va à l'énoncé de la nouvelle question, jamais dans le vide.
    const legend = question.querySelector("legend")
    legend?.setAttribute("tabindex", "-1")
    legend?.focus()
  }
}
