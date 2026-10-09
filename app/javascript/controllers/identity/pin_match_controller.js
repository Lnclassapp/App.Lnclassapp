// ⚡ FRONT · identity/pin_match_controller — dit en direct si la confirmation du code secret concorde
// Rôle : dès 4 chiffres, icône et message sous la confirmation, annoncés (aria-live) ; le serveur refuse toujours des codes différents
// ADR  : 0050, 0051, 0083 · UDR : 0079 (§3.5)
import { Controller } from "@hotwired/stimulus"

const LENGTH = 4
const BORDERS = ["border-line", "border-success", "border-error"]
const STATES = {
  ok: { icon: "okIcon", tone: "text-success", border: "border-success" },
  ko: { icon: "koIcon", tone: "text-error", border: "border-error" }
}

export default class extends Controller {
  static targets = ["pin", "confirmation", "status", "okIcon", "koIcon"]
  static values = { ok: String, ko: String }

  // Un morphing (re-rendu 422) remet les attributs du serveur : bordure d'origine et lien au statut sont relus.
  connect() {
    this.remember()
    document.addEventListener("turbo:morph", this.refresh)
  }

  disconnect() {
    document.removeEventListener("turbo:morph", this.refresh)
  }

  refresh = () => {
    this.remember()
    this.check()
  }

  // Le code change aussi : la concordance est relue depuis les deux champs.
  check() {
    const confirmation = this.confirmationTarget.value
    if (confirmation.length < LENGTH) return this.render(null)

    this.render(confirmation === this.pinTarget.value ? "ok" : "ko")
  }

  // Moins de 4 chiffres : rien d'affiché, la bordure du serveur revient ; un aria-invalid posé ici est retiré.
  render(state) {
    const field = this.confirmationTarget
    const status = this.statusTarget
    field.classList.remove(...BORDERS)
    status.classList.remove(STATES.ok.tone, STATES.ko.tone)
    if (state === "ko") field.setAttribute("aria-invalid", "true")
    else if (state === "ok" || status.dataset.state === "ko") field.removeAttribute("aria-invalid")
    status.dataset.state = state || ""

    if (!state) {
      if (this.border) field.classList.add(this.border)
      status.hidden = true
      return
    }

    const { icon, tone, border } = STATES[state]
    field.classList.add(border)
    status.classList.add(tone)
    status.replaceChildren(this[`${icon}Target`].content.cloneNode(true), this[`${state}Value`])
    status.hidden = false
  }

  // Bordure rendue par le serveur (neutre ou en erreur), et statut ajouté à aria-describedby sans retirer l'aide ni
  // l'erreur déjà reliées.
  remember() {
    const field = this.confirmationTarget
    this.border = BORDERS.find((name) => field.classList.contains(name))
    const ids = (field.getAttribute("aria-describedby") || "").split(/\s+/).filter(Boolean)
    if (!ids.includes(this.statusTarget.id)) field.setAttribute("aria-describedby", [...ids, this.statusTarget.id].join(" "))
  }
}
