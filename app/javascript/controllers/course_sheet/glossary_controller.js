// ⚡ FRONT · course_sheet/glossary_controller — lexique de la fiche de cours : bulle près du mot touché, liste « Lexique », aide
// Rôle : la bulle se place près du clic (même règle que la maquette), se ferme au défilement, au clic ailleurs et à Échap ; texte brut seulement
// ADR  : XXXX-fiche-de-cours-en-donnees-importees · UDR : XXXX-fiche-de-cours-a-l-identique-des-maquettes
import { Controller } from "@hotwired/stimulus"

const LIST = "-list"
const HELP = "-help"

export default class extends Controller {
  static targets = [ "bubble", "title", "list" ]
  static values = { glossary: Object, help: Array, listTitle: String }

  connect() {
    this.onScroll = this.onScroll.bind(this)
    this.onClick = this.onClick.bind(this)
    this.onKeydown = this.onKeydown.bind(this)
    window.addEventListener("scroll", this.onScroll, true)
    document.addEventListener("click", this.onClick)
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll, true)
    document.removeEventListener("click", this.onClick)
    document.removeEventListener("keydown", this.onKeydown)
  }

  // data-action="…#open" et data-…-key-param : la clé du mot, ou « -list » (Lexique) ou « -help » (aide).
  open(event) {
    event.stopPropagation()
    const { x, y } = this.pointOf(event)
    this.show(event.params.key, x, y)
  }

  close() {
    if (!this.hasBubbleTarget) return
    this.bubbleTarget.hidden = true
  }

  show(key, x, y) {
    if (key === LIST) {
      this.fill(this.listTitleValue, this.allWords())
    } else if (key === HELP) {
      this.fill(this.helpValue[0], [ { definition: this.helpValue[1] } ])
    } else {
      const entry = this.glossaryValue[key]
      if (!entry) return
      this.fill(entry[0], [ { definition: entry[1], example: entry[2] } ])
    }
    this.bubbleTarget.hidden = false
    this.place(key === LIST, x, y)
  }

  allWords() {
    return Object.entries(this.glossaryValue).map(([ key, entry ]) => ({ key, title: entry[0], definition: entry[1] }))
  }

  // Tout se construit en textContent : le lexique vient d'un fichier importé, jamais du HTML.
  fill(title, items) {
    this.titleTarget.textContent = title
    this.listTarget.replaceChildren(...items.map((item) => this.itemElement(item)))
    this.bubbleTarget.scrollTop = 0
  }

  itemElement({ key, title, definition, example }) {
    const element = document.createElement("div")
    element.className = "sheet-bubble-item"
    if (title) {
      const heading = document.createElement("button")
      heading.type = "button"
      heading.className = "sheet-bubble-term"
      heading.textContent = title
      heading.addEventListener("click", (event) => {
        event.stopPropagation()
        this.show(key, this.lastX, this.lastY)
      })
      element.append(heading)
    }
    const text = document.createElement("span")
    text.textContent = definition
    element.append(text)
    if (example) {
      const sample = document.createElement("span")
      sample.className = "sheet-bubble-example"
      sample.textContent = example
      element.append(sample)
    }
    return element
  }

  // Règle de la maquette : à gauche du clic moins 20 px, gardée dans la fenêtre ; sous le clic, ou au-dessus près du bas.
  place(isList, x, y) {
    this.lastX = x
    this.lastY = y
    const width = window.innerWidth
    const height = window.innerHeight
    const left = Math.max(8, Math.min(x - 20, width - 326))
    const top = isList
      ? Math.max(8, Math.min(y + 18, height * 0.3))
      : (y > height - 240 ? Math.max(8, y - 230) : y + 18)
    this.bubbleTarget.style.setProperty("--sheet-bubble-left", `${left}px`)
    this.bubbleTarget.style.setProperty("--sheet-bubble-top", `${top}px`)
  }

  // Un clic au clavier n'a pas de coordonnées : on part du mot.
  pointOf(event) {
    if (event.clientX || event.clientY) return { x: event.clientX, y: event.clientY }
    const rect = event.currentTarget.getBoundingClientRect()
    return { x: rect.left, y: rect.top }
  }

  onScroll(event) {
    if (this.hasBubbleTarget && this.bubbleTarget.contains(event.target)) return
    this.close()
  }

  onClick(event) {
    if (this.hasBubbleTarget && !this.bubbleTarget.contains(event.target)) this.close()
  }

  onKeydown(event) {
    if (event.key === "Escape") this.close()
  }
}
