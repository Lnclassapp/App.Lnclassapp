// ⚡ FRONT · math_controller — formules KaTeX ($…$ et $$…$$) de l'élément porteur
// Rôle : charge KaTeX à la demande (chunk servi par l'application, jamais par un CDN) ; rend de nouveau après un morph et dès que du contenu arrive sous l'élément (frame ou Turbo Stream)
// ADR  : 0051 · TR-41
import { Controller } from "@hotwired/stimulus"

const DELIMITERS = [
  { left: "$$", right: "$$", display: true },
  { left: "$", right: "$", display: false }
]

export default class extends Controller {
  connect() {
    // Un turbo_stream.refresh fusionne la page : le texte brut du serveur remplace le rendu, sans reconnecter ce
    // contrôleur. On rend donc de nouveau après chaque morph ; un texte déjà rendu n'a plus de délimiteur.
    this.render = this.render.bind(this)
    document.addEventListener("turbo:morph", this.render)
    // Un turbo-frame ou un Turbo Stream ne remplace que le contenu : l'élément porteur reste, `connect` ne rejoue pas et la réponse
    // (énoncé, propositions, indice, correction) resterait en `$…$` brut. On rend donc ce qui arrive ; l'observateur se tait
    // pendant le rendu, dont les mutations sont les siennes.
    this.observer = new MutationObserver(() => this.render())
    this.active = true
    this.render()
  }

  disconnect() {
    this.active = false
    document.removeEventListener("turbo:morph", this.render)
    this.observer?.disconnect()
  }

  async render() {
    const { default: renderMathInElement } = await import("katex/contrib/auto-render")
    if (!this.active) return

    this.observer.disconnect()
    renderMathInElement(this.element, { delimiters: DELIMITERS, throwOnError: false })
    this.observer.observe(this.element, { childList: true, subtree: true, characterData: true })
  }
}
