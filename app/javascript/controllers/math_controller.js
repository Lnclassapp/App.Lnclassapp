// ⚡ FRONT · math_controller — formules KaTeX ($…$ et $$…$$) de l'élément porteur
// Rôle : charge KaTeX à la demande (chunk servi par l'application, jamais par un CDN) ; rend de nouveau après un morph
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
    this.render()
  }

  disconnect() {
    document.removeEventListener("turbo:morph", this.render)
  }

  async render() {
    const { default: renderMathInElement } = await import("katex/contrib/auto-render")
    renderMathInElement(this.element, { delimiters: DELIMITERS, throwOnError: false })
  }
}
