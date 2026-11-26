// ⚡ FRONT · push_request_controller — la case « Prévenir les élèves » suit l'audience de l'annonce
// Rôle : désactivée et décochée pour « Enseignants » et « Directions », réactivée pour « Tous » et « Élèves » ; sans JavaScript, le serveur ignore la case
// UDR  : XXXX (§3.6) · ADR : XXXX (envois de notifications, §4.1)
import { Controller } from "@hotwired/stimulus"

const STUDENT_AUDIENCES = ["all", "students"]

export default class extends Controller {
  static targets = ["box"]

  connect() {
    this.sync()
  }

  sync() {
    if (!this.hasBoxTarget) return
    const chosen = this.element.querySelector("input[name='announcement[audience]']:checked")
    const open = !chosen || STUDENT_AUDIENCES.includes(chosen.value)
    this.boxTarget.disabled = !open
    if (!open) this.boxTarget.checked = false
  }
}
