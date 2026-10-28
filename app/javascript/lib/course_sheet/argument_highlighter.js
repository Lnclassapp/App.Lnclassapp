// ⚡ FRONT · lib/course_sheet/argument_highlighter — les surligneurs du texte argumentatif, chargés à la demande par course_sheet/argument_highlighter_controller
// Rôle : un bouton allume une catégorie (thèse, thèse adverse, arguments, exemples, connecteurs), « Tout surligner » les allume toutes, un passage allumé s'explique au clic ou à Entrée
// ADR  : 0114 (budget du JS commun), 0110 · UDR : 0137 · formules de la maquette Fiche Texte argumentatif.dc.html (hlBtns, segs, info) ; rendu serveur : kinds/_argument_highlighter

export class ArgumentHighlighter {
  constructor(root) {
    this.root = root
    this.buttons = [...root.querySelectorAll(".sheet-hl-btn")]
    this.all = root.querySelector(".sheet-hl-all")
    this.segments = [...root.querySelectorAll(".sheet-hl-seg")]
    this.info = root.querySelector(".sheet-hl-info")
    this.title = this.info.querySelector("[data-role='title']")
    this.text = this.info.querySelector("[data-role='text']")
    // Le texte d'attente vient de la vue : relu dans le DOM, il serait faux après un retour arrière (cache de Turbo).
    this.idle = this.info.dataset.idle || ""
    this.on = new Set()
    this.current = null

    this.onClick = (event) => this.click(event)
    this.onKey = (event) => this.key(event)
    root.addEventListener("click", this.onClick)
    root.addEventListener("keydown", this.onKey)
    this.render()
    root.dataset.ready = "true"
  }

  // Détache et remet la figure comme à la livraison : aucun surligneur allumé, aucun passage actif, texte d'attente.
  destroy() {
    this.root.removeEventListener("click", this.onClick)
    this.root.removeEventListener("keydown", this.onKey)
    this.on = new Set()
    this.current = null
    this.render()
    delete this.root.dataset.ready
  }

  click(event) {
    const button = event.target.closest(".sheet-hl-btn")
    if (button) return this.toggle(button.dataset.kind)
    if (event.target.closest(".sheet-hl-all")) return this.toggleAll()
    this.pick(event.target.closest(".sheet-hl-seg"))
  }

  // Entrée ou Espace sur un passage allumé : la même explication qu'au clic.
  key(event) {
    const segment = event.target.closest?.(".sheet-hl-seg")
    if (!segment || (event.key !== "Enter" && event.key !== " ")) return

    event.preventDefault()
    this.pick(segment)
  }

  toggle(kind) {
    if (this.on.has(kind)) this.on.delete(kind)
    else this.on.add(kind)
    this.render()
  }

  toggleAll() {
    const kinds = this.buttons.map((button) => button.dataset.kind)
    this.on = kinds.every((kind) => this.on.has(kind)) ? new Set() : new Set(kinds)
    this.render()
  }

  // Un passage qui n'est pas allumé ne répond pas.
  pick(segment) {
    if (!segment || segment.dataset.on === undefined) return

    this.current = segment.dataset.kind
    this.render()
  }

  render() {
    this.buttons.forEach((button) => button.setAttribute("aria-pressed", String(this.on.has(button.dataset.kind))))
    const allOn = this.buttons.every((button) => this.on.has(button.dataset.kind))
    this.all.setAttribute("aria-pressed", String(allOn))
    this.all.textContent = allOn ? this.all.dataset.labelOff : this.all.dataset.labelOn

    this.segments.forEach((segment) => {
      if (this.on.has(segment.dataset.kind)) {
        segment.dataset.on = ""
        segment.setAttribute("role", "button")
        segment.tabIndex = 0
      } else {
        delete segment.dataset.on
        segment.removeAttribute("role")
        segment.removeAttribute("tabindex")
      }
    })

    // L'explication ne reste affichée que tant que sa catégorie est allumée.
    const active = this.current && this.on.has(this.current) ? this.buttons.find((button) => button.dataset.kind === this.current) : null
    if (active) {
      this.info.dataset.kind = this.current
      this.title.textContent = `${active.textContent} :`
      this.text.textContent = active.dataset.why
    } else {
      delete this.info.dataset.kind
      this.title.textContent = ""
      this.text.textContent = this.idle
    }
  }
}
