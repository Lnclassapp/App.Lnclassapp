// ⚡ FRONT · math_controller — formules KaTeX ($…$ et $$…$$) de l'élément porteur
// Rôle : charge KaTeX à la demande (chunk servi par l'application, jamais par un CDN)
// ADR  : 0051 · TR-41
import { Controller } from "@hotwired/stimulus"

const DELIMITERS = [
  { left: "$$", right: "$$", display: true },
  { left: "$", right: "$", display: false }
]

export default class extends Controller {
  async connect() {
    const { default: renderMathInElement } = await import("katex/contrib/auto-render")
    renderMathInElement(this.element, { delimiters: DELIMITERS, throwOnError: false })
  }
}
