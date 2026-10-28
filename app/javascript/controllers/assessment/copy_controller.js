// ⚡ FRONT · assessment/copy_controller — la copie de l'élève : coquille Stimulus, la logique est dans lib/assessment/copy_sheet
// Rôle : cibles, valeurs et actions ; `lib/assessment/copy_sheet` (brouillon, compteur, confirmation) est chargé par import(), à la demande
// UDR  : 0138 §3.2 · ADR : 0051, 0112 §4.5 · sans JavaScript, le formulaire part tel quel (questions vides = fausses, pas de brouillon)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["question", "counter", "errors", "missing", "offline"]
  static values = { key: String, total: Number, counter: String, missingOne: String, missingOther: String }

  async connect() {
    const { CopySheet } = await import("../../lib/assessment/copy_sheet")
    if (this.element.isConnected) this.sheet = new CopySheet(this)
  }

  disconnect() {
    this.sheet?.destroy()
    this.sheet = null
  }

  save() { this.sheet?.save() }
  submit(event) { this.sheet?.submit(event) }
  confirm() { this.sheet?.confirm() }
  done(event) { this.sheet?.done(event) }
}
