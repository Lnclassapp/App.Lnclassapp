// ⚡ FRONT · lib/course_sheet/writing — « Ma rédaction » : connecteurs repérés, mots, paragraphes et liste de vérification, chargés à la demande par course_sheet/writing_controller
// Rôle : lit la zone de texte à chaque frappe et coche la liste ; tout se passe dans le navigateur : aucun envoi au serveur, aucune note, rien n'est gardé
// ADR  : 0114 (budget du JS commun), 0110 · UDR : 0137 · formules de la maquette Fiche Texte argumentatif.dc.html (renderVals : found, wordsN, parasN, checks) ; rendu serveur : blocks/_writing
const LETTERS = "a-zàâäçéèêëîïôöûùüÿœ"
const OPINION = ["je pense", "selon moi", "à mon avis", "je suis convaincu", "je suis convaincue", "il me semble", "je crois", "je trouve"]
const EXAMPLE = ["par exemple", "notamment", "comme "]
const CONCLUSION = ["en conclusion", "pour conclure", "en somme", "finalement"]

const escape = (text) => text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
const hasAny = (text, list) => list.some((item) => text.includes(item))

export class Writing {
  constructor(root) {
    this.root = root
    this.input = root.querySelector(".sheet-writing-input")
    this.items = [...root.querySelectorAll("[data-check]")]
    this.count = root.querySelector("[data-role='count']")
    this.pills = root.querySelector("[data-role='found']")
    this.stats = root.querySelector("[data-role='stats']")
    this.min = {
      words: Number(root.dataset.minWords) || 0,
      paragraphs: Number(root.dataset.minParagraphs) || 0,
      connectors: Number(root.dataset.minConnectors) || 0
    }
    // Un mot entier : ni lettre avant, ni lettre après ; une locution qui finit par une apostrophe (« parce qu' ») est suivie d'une lettre.
    this.connectors = this.list(root.dataset.connectors).map((word) => {
      const after = new RegExp(`[${LETTERS}]$`).test(word) ? `(?=$|[^${LETTERS}])` : ""
      return { word, pattern: new RegExp(`(^|[^${LETTERS}])${escape(word)}${after}`) }
    })

    this.onInput = () => this.update()
    this.update()
    this.input.addEventListener("input", this.onInput)
    root.dataset.ready = "true"
  }

  // Détache et remet la liste comme à la livraison (le cache de Turbo ne garde pas la saisie : la liste ne doit pas la survivre).
  destroy() {
    this.input.removeEventListener("input", this.onInput)
    this.input.value = ""
    this.update()
    delete this.root.dataset.ready
  }

  // Les connecteurs sont lus comme le texte de l'élève : minuscules, apostrophes droites.
  list(json) {
    try {
      const list = JSON.parse(json || "[]")
      return Array.isArray(list) ? list.filter((word) => typeof word === "string").map((word) => this.normalize(word).trim()).filter(Boolean) : []
    } catch (error) {
      console.warn("rédaction : liste de connecteurs illisible", error)
      return []
    }
  }

  normalize(text) {
    return text.toLowerCase().replace(/[’`]/g, "'")
  }

  update() {
    const raw = this.input.value
    const text = this.normalize(raw)
    const found = this.found(text)
    const words = raw.trim() ? raw.trim().split(/\s+/).length : 0
    const paragraphs = raw.split(/\n\s*\n/).filter((part) => part.trim()).length

    this.count.textContent = String(found.length)
    this.pills.replaceChildren(...found.map((word) => this.pill(word)))
    this.stats.textContent = this.root.dataset.stats.replace("{words}", words).replace("{paragraphs}", paragraphs)

    const verdicts = {
      opinion: hasAny(text, OPINION),
      paragraphs: paragraphs >= this.min.paragraphs,
      connectors: found.length >= this.min.connectors,
      example: hasAny(text, EXAMPLE),
      question: text.includes("?"),
      conclusion: hasAny(text, CONCLUSION),
      words: words >= this.min.words
    }
    this.items.forEach((item) => this.mark(item, verdicts[item.dataset.check] === true))
  }

  // Les connecteurs du bloc trouvés dans le texte, dans l'ordre de la liste ; « d'abord » ne compte pas quand « tout d'abord » est là.
  found(text) {
    const found = this.connectors.filter(({ pattern }) => pattern.test(text)).map(({ word }) => word)
    return found.filter((word) => !found.some((other) => other !== word && other.includes(word)))
  }

  pill(word) {
    const pill = document.createElement("span")
    pill.className = "sheet-writing-pill"
    pill.textContent = word
    return pill
  }

  mark(item, done) {
    item.dataset.state = done ? "done" : "todo"
    item.querySelector(".sheet-writing-mark").textContent = done ? "✓" : "○"
    item.querySelector("[data-role='state']").textContent = done ? this.root.dataset.labelDone : this.root.dataset.labelTodo
  }
}
