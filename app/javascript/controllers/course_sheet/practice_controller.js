// ⚡ FRONT · course_sheet/practice_controller — « Je m'entraîne » : un énoncé tiré d'un générateur, Vérifier, solution, nouvel exercice, score
// Rôle : juge la saisie (±0,011, Entrée vérifie), compte chaque énoncé une seule fois dans « ok / total » ; les générateurs sont dans generators/
// ADR  : XXXX-fiche-de-cours-en-donnees-importees (chantier contenu-en-blocs) · interface : generators/bank.js (un fichier par `kind`, trouvé par glob, rien à enregistrer)
import { Controller } from "@hotwired/stimulus"
import generators from "./generators/*.js"
import { isNumericCorrect, TOLERANCE } from "./generators/bank"

export default class extends Controller {
  static targets = ["prompt", "ask", "input", "unit", "result", "solution", "solutionButton", "score"]
  static values = {
    kind: String,
    bank: { type: Array, default: [] },
    tolerance: { type: Number, default: TOLERANCE },
    scoreTemplate: String, incomplete: String, correct: String, wrong: String
  }

  connect() {
    const entry = generators.find((generator) => generator.module.kind === this.kindValue)
    this.generator = entry?.module.create({ kind: this.kindValue, bank: this.bankValue })
    this.score = { ok: 0, total: 0 }

    // Générateur absent (pas encore livré) ou banque vide : rien à proposer, le bloc se retire plutôt que d'afficher un champ mort.
    if (!this.generator) return void (this.element.hidden = true)
    this.renderScore()
    this.draw()
  }

  // « Nouvel exercice » : un autre énoncé, et le curseur dans le champ.
  next() {
    this.draw()
    this.inputTarget.focus({ preventScroll: true })
  }

  draw() {
    const problem = this.generator.next()
    if (!problem) return void (this.element.hidden = true)

    this.problem = problem
    this.counted = false
    this.promptTarget.textContent = problem.text
    this.askTarget.textContent = problem.ask ? `${problem.ask} =` : ""
    this.unitTarget.textContent = problem.unit || ""
    this.inputTarget.value = ""
    this.clearResult()
    this.solutionTarget.hidden = true
    this.solutionButtonTarget.setAttribute("aria-expanded", "false")
  }

  edit() {
    this.clearResult()
  }

  check(event) {
    event?.preventDefault()
    if (this.inputTarget.value.trim() === "") return this.show("incomplete", this.incompleteValue)

    const ok = isNumericCorrect(this.inputTarget.value, this.problem.answer, this.toleranceValue)
    if (!this.counted) {
      this.counted = true
      this.score = { ok: this.score.ok + (ok ? 1 : 0), total: this.score.total + 1 }
      this.renderScore()
    }

    this.show(ok ? "correct" : "wrong", ok ? this.correctValue : this.wrongValue)
  }

  toggleSolution() {
    this.solutionTarget.textContent = this.problem.solution
    this.solutionTarget.hidden = !this.solutionTarget.hidden
    this.solutionButtonTarget.setAttribute("aria-expanded", String(!this.solutionTarget.hidden))
  }

  // --- interne ---

  show(state, text) {
    this.resultTarget.textContent = text
    this.resultTarget.dataset.state = state
  }

  clearResult() {
    this.resultTarget.textContent = ""
    delete this.resultTarget.dataset.state
  }

  renderScore() {
    this.scoreTarget.textContent = this.scoreTemplateValue.replace("{ok}", this.score.ok).replace("{total}", this.score.total)
  }
}
