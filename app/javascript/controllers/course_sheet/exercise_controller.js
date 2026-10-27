// ⚡ FRONT · course_sheet/exercise_controller — exercice corrigé d'une fiche de cours : Vérifier, retours par champ, Indice, Correction
// Rôle : juge les champs numériques (±0,011, virgule) et à choix (choix figé au premier clic), affiche « juste / à revoir / à compléter » et le message global
// ADR  : 0110-fiche-de-cours-en-donnees-importees (chantier contenu-en-blocs) · UDR : 0137-fiche-de-cours-a-l-identique-des-maquettes
import { Controller } from "@hotwired/stimulus"
import { isNumericCorrect, TOLERANCE } from "./generators/bank"

export default class extends Controller {
  static targets = ["field", "feedback", "message", "hint", "correction", "hintButton", "correctionButton"]
  static values = {
    tolerance: { type: Number, default: TOLERANCE },
    incomplete: String, correct: String, wrong: String, allCorrect: String, someWrong: String
  }

  // Un clic sur un choix : sélection (modifiable jusqu'à Vérifier) ou, si le champ est figé, réponse définitive aussitôt jugée.
  pick(event) {
    const button = event.currentTarget
    const field = button.closest("[data-input='choice']")
    if (field.dataset.locked === "true") return

    field.querySelectorAll("button").forEach((other) => other.setAttribute("aria-pressed", String(other === button)))
    field.dataset.picked = button.dataset.index
    this.clearMessage()

    if (field.dataset.frozen === "true") {
      field.dataset.locked = "true"
      this.judgeChoice(field, true)
    } else {
      this.show(field, null)
    }
  }

  edit(event) {
    this.show(event.currentTarget, null)
    this.clearMessage()
  }

  check() {
    const verdicts = this.fieldTargets.map((field) => {
      const verdict = this.verdictOf(field)
      this.show(field, verdict)
      if (field.dataset.input === "choice") this.paintChoices(field, verdict)
      return verdict
    })

    const all = verdicts.length > 0 && verdicts.every((verdict) => verdict === "correct")
    this.messageTarget.textContent = all ? this.allCorrectValue : this.someWrongValue
    this.messageTarget.dataset.state = all ? "correct" : "wrong"
  }

  toggleHint() {
    this.toggle(this.hintTarget, this.hintButtonTarget)
  }

  toggleCorrection() {
    this.toggle(this.correctionTarget, this.correctionButtonTarget)
  }

  // --- interne ---

  verdictOf(field) {
    if (field.dataset.input === "choice") {
      if (field.dataset.picked === undefined) return "incomplete"
      return Number(field.dataset.picked) === Number(field.dataset.answer) ? "correct" : "wrong"
    }

    if (field.value.trim() === "") return "incomplete"
    return isNumericCorrect(field.value, Number(field.dataset.answer), this.toleranceValue) ? "correct" : "wrong"
  }

  judgeChoice(field, final) {
    const verdict = this.verdictOf(field)
    this.show(field, verdict)
    if (final) this.paintChoices(field, verdict)
  }

  // Colore les boutons d'un choix jugé : la bonne réponse en vert, une mauvaise sélection en rouge.
  paintChoices(field, verdict) {
    if (verdict === "incomplete") return

    field.querySelectorAll("button").forEach((button) => {
      const index = Number(button.dataset.index)
      if (index === Number(field.dataset.answer)) button.dataset.state = "right"
      else if (String(index) === field.dataset.picked) button.dataset.state = "wrong"
    })
  }

  // Écrit le retour sous le champ (null l'efface) ; pour un choix non figé, efface aussi les couleurs.
  show(field, verdict) {
    const feedback = this.feedbackTargets.find((target) => target.dataset.fieldId === field.dataset.fieldId)
    if (feedback) {
      feedback.textContent = verdict ? this[`${verdict}Value`] : ""
      if (verdict) feedback.dataset.state = verdict
      else delete feedback.dataset.state
    }

    if (verdict === null && field.dataset.input === "choice" && field.dataset.locked !== "true") {
      field.querySelectorAll("button").forEach((button) => delete button.dataset.state)
    }
  }

  clearMessage() {
    this.messageTarget.textContent = ""
    delete this.messageTarget.dataset.state
  }

  toggle(panel, button) {
    panel.hidden = !panel.hidden
    button.setAttribute("aria-expanded", String(!panel.hidden))
  }
}
