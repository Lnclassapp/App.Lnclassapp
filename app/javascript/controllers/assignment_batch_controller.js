// ⚡ FRONT · assignment_batch_controller — le devoir que l'enseignant compose : cases « Choisir », bandeau d'envoi, sélection gardée d'une leçon à l'autre
// Rôle : tient la liste des exercices choisis (identifiants publics, 10 au plus) dans localStorage (clé lnclass-batch-<enseignant>), coche les cases `[data-batch-choice]` de la page, affiche « n exercices choisis », ajoute les identifiants au formulaire « Envoyer à <classe> » ; vide la sélection quand le compte rendu de l'envoi arrive
// ADR  : sujets-de-devoir (ajout du 2026-10-30) · UDR : XXXX-feuilles-prepare-interros-et-devoirs §3 (Devoir composé par l'enseignant) · lecture et écriture du stockage sous try/catch : un navigateur qui le refuse garde la sélection le temps de la page
import { Controller } from "@hotwired/stimulus"

// Les cases sont dans les feuilles, le bandeau est ailleurs dans la page : un clic sur une case se lit à l'écoute du document.
const REDRAW_EVENTS = ["turbo:render", "turbo:morph", "turbo:frame-render"]

export default class extends Controller {
  static targets = ["status", "limit", "selection", "count"]
  static values = { key: String, max: Number, one: String, other: String }

  connect() {
    this.onClick = this.onClick.bind(this)
    this.redraw = this.redraw.bind(this)
    document.addEventListener("click", this.onClick)
    REDRAW_EVENTS.forEach((name) => document.addEventListener(name, this.redraw))
    this.render()
  }

  disconnect() {
    document.removeEventListener("click", this.onClick)
    REDRAW_EVENTS.forEach((name) => document.removeEventListener(name, this.redraw))
  }

  // Le compte rendu de l'envoi arrive (Turbo Stream) : les exercices sont partis, la sélection est vidée.
  statusTargetConnected(status) {
    if (status.dataset.sent !== "true") return

    this.ids = []
    this.save()
    this.render()
  }

  onClick(event) {
    const box = event.target.closest && event.target.closest("[data-batch-choice]")
    if (!box) return

    const id = box.dataset.batchChoice
    const ids = this.selected()
    if (this.hasStatusTarget) this.statusTarget.hidden = true
    if (ids.includes(id)) {
      this.ids = ids.filter((other) => other !== id)
    } else if (ids.length >= this.maxValue) {
      this.limitTarget.hidden = false
      return
    } else {
      this.ids = [...ids, id]
    }
    this.limitTarget.hidden = true
    this.save()
    this.render()
  }

  clear() {
    this.ids = []
    this.limitTarget.hidden = true
    this.save()
    this.render()
  }

  // Au moment de l'envoi (formdata) : les exercices choisis rejoignent le formulaire de la classe.
  fill(event) {
    event.formData.delete("exercise_public_ids[]")
    this.selected().forEach((id) => event.formData.append("exercise_public_ids[]", id))
  }

  // Une page arrive ou se fusionne : les cases et le bandeau reprennent l'état de la sélection.
  redraw() {
    this.render()
  }

  render() {
    const ids = this.selected()
    document.querySelectorAll("[data-batch-choice]").forEach((box) => {
      box.setAttribute("aria-checked", String(ids.includes(box.dataset.batchChoice)))
    })
    this.selectionTarget.hidden = ids.length === 0
    this.countTarget.textContent = ids.length === 0 ? "" : (ids.length === 1 ? this.oneValue : this.otherValue).replace(/\d+/, ids.length)
    this.element.hidden = ids.length === 0 && !this.hasMessage()
  }

  hasMessage() {
    return this.hasStatusTarget && !this.statusTarget.hidden && this.statusTarget.textContent.trim() !== ""
  }

  selected() {
    if (!this.ids) this.ids = this.load()
    return this.ids
  }

  load() {
    try {
      const stored = JSON.parse(localStorage.getItem(this.keyValue))
      return Array.isArray(stored) ? [...new Set(stored.filter((id) => typeof id === "string"))].slice(0, this.maxValue) : []
    } catch {
      return []
    }
  }

  save() {
    try {
      if (this.ids.length === 0) localStorage.removeItem(this.keyValue)
      else localStorage.setItem(this.keyValue, JSON.stringify(this.ids))
    } catch {
      // Stockage refusé : la sélection reste dans la page.
    }
  }
}
