// ⚡ FRONT · catalog/paper_table_controller — le tableau de QCM d'un sujet en forme d'épreuve : colonnes à la taille, empilé s'il ne tient pas
// Rôle : mesure le tableau sans empilement, à chaque changement de taille (fenêtre, formules KaTeX rendues après coup) ; plus large que son cadre, ou l'affirmation plus étroite que 10 em, il prend ps-paper-table--stacked (propositions en cases sous l'affirmation, comme sous 480 px)
// ADR  : — · UDR : 0152 §3 (amendement du 2026-11-06) · la mesure se fait toujours sans la classe : la poser ou l'ôter ne renverse pas la décision suivante ; sans JS, le tableau reste à la taille (CSS seul)
import { Controller } from "@hotwired/stimulus"

const STACKED = "ps-paper-table--stacked"
const STATEMENT_MIN_EM = 10

export default class extends Controller {
  connect() {
    this.scheduled = false
    this.onResize = () => this.schedule()
    if ("ResizeObserver" in window) {
      this.observer = new ResizeObserver(this.onResize)
      this.observer.observe(this.element)
      if (this.element.parentElement) this.observer.observe(this.element.parentElement)
    } else {
      window.addEventListener("resize", this.onResize)
    }
    // Les polices de KaTeX arrivent après coup et changent la largeur des formules : une mesure de plus quand elles sont là.
    document.fonts?.ready.then(this.onResize)
    this.fit()
  }

  disconnect() {
    this.observer?.disconnect()
    window.removeEventListener("resize", this.onResize)
  }

  // Une mesure par image : une classe posée pendant le rappel de ResizeObserver relancerait la boucle dans la même image.
  schedule() {
    if (this.scheduled) return
    this.scheduled = true
    requestAnimationFrame(() => {
      this.scheduled = false
      this.fit()
    })
  }

  fit() {
    const frame = this.element.parentElement
    if (!frame) return

    this.element.classList.remove(STACKED)
    // Sous 480 px, le CSS empile déjà le tableau (display: block) : rien à mesurer.
    if (getComputedStyle(this.element).display !== "table") return

    const style = getComputedStyle(frame)
    const room = frame.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight)
    const statement = this.element.querySelector("tbody td")
    const em = parseFloat(getComputedStyle(this.element).fontSize)
    const tooWide = this.element.offsetWidth > room + 1
    const squeezed = statement !== null && statement.offsetWidth < STATEMENT_MIN_EM * em
    this.element.classList.toggle(STACKED, tooWide || squeezed)
  }
}
