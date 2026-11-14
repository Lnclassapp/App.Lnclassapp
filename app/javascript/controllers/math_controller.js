// ⚡ FRONT · math_controller — formules KaTeX ($…$ et $$…$$) de l'élément porteur
// Rôle : charge KaTeX à la demande (chunk servi par l'application, jamais par un CDN) ; rend de nouveau après un morph et dès que du contenu arrive sous l'élément (frame ou Turbo Stream)
// ADR  : 0051 · TR-41
import { Controller } from "@hotwired/stimulus"

const DELIMITERS = [
  { left: "$$", right: "$$", display: true },
  { left: "$", right: "$", display: false }
]

// Les contrôleurs connectés. Les éléments `math` s'imbriquent (la feuille, l'exercice, une proposition) : le rendu de l'un mute le
// sous-arbre des autres, dont l'observateur est actif. Chaque contrôleur ne peut donc pas se contenter de couper le sien.
const connected = new Set()

export default class extends Controller {
  connect() {
    // Un turbo_stream.refresh fusionne la page : le texte brut du serveur remplace le rendu, sans reconnecter ce
    // contrôleur. On rend donc de nouveau après chaque morph ; un texte déjà rendu n'a plus de délimiteur.
    this.render = this.render.bind(this)
    document.addEventListener("turbo:morph", this.render)
    // Un turbo-frame ou un Turbo Stream ne remplace que le contenu : l'élément porteur reste, `connect` ne rejoue pas et la réponse
    // (énoncé, propositions, indice, correction) resterait en `$…$` brut. On rend donc ce qui arrive.
    this.observer = new MutationObserver(() => this.render())
    this.observer.observe(this.element, { childList: true, subtree: true, characterData: true })
    this.active = true
    connected.add(this)
    this.render()
  }

  disconnect() {
    this.active = false
    connected.delete(this)
    document.removeEventListener("turbo:morph", this.render)
    this.observer?.disconnect()
  }

  async render() {
    const { default: renderMathInElement } = await import("katex/contrib/auto-render")
    if (!this.active) return

    renderMathInElement(this.element, { delimiters: DELIMITERS, throwOnError: false })
    this.settle()
  }

  // Le rendu vient de muter le DOM, et KaTeX réécrit aussi un texte qui garde un `$` seul (une formule coupée par une case à
  // remplir) : un contrôleur qui rendrait pour ces mutations-là les ferait rendre à son tour, sans fin (PR de train 626, tâche `lecons`).
  // Les mutations arrivées sous l'élément rendu sont donc les nôtres, de tous les contrôleurs : on les écarte. Celles hors de
  // l'élément, qu'il n'a pas rendu, restent dues à leur contrôleur.
  settle() {
    for (const controller of connected) {
      const foreign = controller.observer.takeRecords().filter((record) => !this.element.contains(record.target))
      if (foreign.length > 0) controller.render()
    }
  }
}
