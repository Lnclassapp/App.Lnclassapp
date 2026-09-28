// ⚡ FRONT · password_reveal_controller — bouton œil d'un champ PIN : affiche puis remasque le code saisi
// Rôle : bascule password ↔ text, aria-pressed et libellé ; remasque au chargement, avant l'envoi et avant le cache
// UDR  : 0051, 0005 · ADR : 0049 (aucun script en ligne), 0050
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "toggle", "maskedIcon", "revealedIcon"]
  static values = { showLabel: String, hideLabel: String }

  connect() {
    this.conceal()
    this.toggleTarget.hidden = false
    this.form = this.inputTarget.form
    this.form?.addEventListener("submit", this.conceal)
    document.addEventListener("turbo:before-cache", this.conceal)
  }

  disconnect() {
    this.form?.removeEventListener("submit", this.conceal)
    document.removeEventListener("turbo:before-cache", this.conceal)
  }

  // Un clic au clavier (Entrée, Espace) a un `detail` nul : le focus reste alors sur le bouton, pour rebasculer.
  // Au pointeur, le focus revient au champ, curseur à sa place.
  toggle(event) {
    const { selectionStart, selectionEnd } = this.inputTarget
    this.render(this.inputTarget.type === "password")
    if (event.detail === 0) return

    this.inputTarget.focus()
    this.inputTarget.setSelectionRange(selectionStart, selectionEnd)
  }

  // Le bouton ne prend pas le focus au pointeur : le clavier virtuel du téléphone reste ouvert.
  keepFocus(event) {
    event.preventDefault()
  }

  // Le re-rendu 422 est un morphing (page rafraîchie) : il remettrait `hidden` sur le bouton sans repasser par connect.
  // L'événement des icônes remonte jusqu'ici : elles, au contraire, reprennent l'état masqué rendu par le serveur.
  keepShown(event) {
    if (event.target === this.toggleTarget && event.detail.attributeName === "hidden") event.preventDefault()
  }

  conceal = () => {
    this.render(false)
  }

  render(revealed) {
    this.inputTarget.type = revealed ? "text" : "password"
    this.toggleTarget.setAttribute("aria-pressed", String(revealed))
    this.toggleTarget.setAttribute("aria-label", revealed ? this.hideLabelValue : this.showLabelValue)
    this.maskedIconTarget.hidden = revealed
    this.revealedIconTarget.hidden = !revealed
  }
}
