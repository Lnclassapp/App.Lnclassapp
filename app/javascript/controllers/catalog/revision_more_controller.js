// ⚡ FRONT · catalog/revision_more_controller — « Voir plus » / « Voir moins » de la fiche de révision, sans requête
// Rôle : masque au démarrage ce que le serveur a marqué `rest` (la suite après 50 mots) et déplie / replie sur place ; sans JavaScript, tout reste visible
// ADR  : 0113 · UDR : 0139 §3.3 (état, focus, annonce) · le serveur ne pose jamais `hidden` sur le texte
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rest", "button", "fade", "status"]
  static values = { more: String, less: String, shown: String }

  connect() {
    // Un rafraîchissement Turbo fusionne la page : le serveur rend la suite sans `hidden`, la fiche revient repliée.
    this.fold = this.fold.bind(this)
    document.addEventListener("turbo:morph", this.fold)
    this.fold()
    this.openFromHash()
  }

  disconnect() {
    document.removeEventListener("turbo:morph", this.fold)
  }

  toggle() {
    if (this.expanded) this.collapse()
    else this.expand()
  }

  get expanded() {
    return this.hasButtonTarget && this.buttonTarget.getAttribute("aria-expanded") === "true"
  }

  // Replié : la suite masquée, le dégradé et le bouton montrés. Sans suite, rien ne change.
  fold() {
    if (!this.hasRestTarget || !this.hasButtonTarget) return

    this.restTargets.forEach((element) => { element.hidden = true })
    this.buttonTarget.hidden = false
    if (this.hasFadeTarget) this.fadeTarget.hidden = false
    this.render(false)
  }

  expand({ focus = true } = {}) {
    if (!this.hasRestTarget) return

    this.restTargets.forEach((element) => { element.hidden = false })
    if (this.hasFadeTarget) this.fadeTarget.hidden = true
    this.render(true)
    if (this.hasStatusTarget) this.statusTarget.textContent = this.shownValue
    if (!focus) return

    // Le focus va au premier élément déplié : le lecteur d'écran lit la suite, le clavier y reprend.
    const first = this.restTargets[0]
    first.tabIndex = -1
    first.focus()
  }

  collapse() {
    this.fold()
    if (this.hasStatusTarget) this.statusTarget.textContent = ""
    document.getElementById("fiche-de-revision")?.scrollIntoView({ block: "start" })
    this.buttonTarget.focus()
  }

  // Une adresse vers une ancre dans la suite déplie la fiche ; `#fiche-de-revision` la laisse repliée.
  openFromHash() {
    let id
    try {
      id = decodeURIComponent(window.location.hash.slice(1))
    } catch {
      return
    }
    if (!id) return

    const target = document.getElementById(id)
    if (!target || !this.restTargets.some((element) => element.contains(target))) return

    this.expand({ focus: false })
    target.scrollIntoView()
  }

  render(expanded) {
    const button = this.buttonTarget
    button.setAttribute("aria-expanded", String(expanded))
    const label = button.querySelector("[data-role='label']")
    if (label) label.textContent = expanded ? this.lessValue : this.moreValue
    // « chevron-up » : le chevron du bouton, retourné.
    button.querySelector("svg")?.classList.toggle("rotate-180", expanded)
  }
}
