// ⚡ FRONT · figure_controller — une figure paramétrée de la leçon : charge le module de sa sorte, dessine, crée les curseurs
// Rôle : liste blanche des 11 sortes ; `lib/figures/<kind>` chargé par import(), à la demande (rien dans le JS commun) ; curseurs accessibles ; sans JavaScript, ou en cas d'erreur, la description reste affichée
// ADR  : 0116-fiche-de-revision-par-notion-et-figures-parametrees (§4.2, menace), 0117-figures-des-matieres-de-3eme (§4.2), 0114 (budget du point d'entrée commun) · UDR : 0141-fiche-de-revision-en-quatre-blocs (§3.3, §3.6)
import { Controller } from "@hotwired/stimulus"

const KINDS = ["geometry", "coordinate_plane", "number_line", "stat_chart", "solid", "timeline", "map", "diagram", "plate", "optics", "molecule"]
// Les seules clés numériques de premier niveau qu'un curseur peut régler, par sorte (ADR §4.2) : les clés `adjustable` de FigureKinds.
const RANGE_PARAMS = {
  geometry: [],
  coordinate_plane: ["xmin", "xmax", "ymin", "ymax"],
  number_line: ["min", "max", "step"],
  stat_chart: [],
  solid: ["height", "side", "width", "depth", "radius"],
  timeline: ["start", "end"],
  map: [],
  diagram: [],
  plate: [],
  optics: ["focal", "object_distance", "object_height"],
  molecule: ["carbons"]
}
const MAX_CONTROLS = 4

const finite = (value) => typeof value === "number" && Number.isFinite(value)

export default class extends Controller {
  static targets = ["canvas", "controls", "fallback"]
  static values = { kind: String, params: Object, controls: Array }

  // Jeton de génération : un connect() dont le module arrive après un disconnect() (ou un second connect()) ne dessine rien.
  generation = 0

  async connect() {
    const run = ++this.generation
    this.clear()
    this.element.dataset.figureState = "loading"
    if (!KINDS.includes(this.kindValue)) return this.fail(new Error(`figure : sorte inconnue « ${this.kindValue} »`))

    let module
    try {
      module = await import(`../lib/figures/${this.kindValue}.js`)
    } catch (error) {
      return this.fail(error)
    }
    if (run !== this.generation) return

    try {
      this.values = { ...this.paramsValue }
      // Un module peut charger ses données (fond de carte) par import() avant de dessiner : on attend, puis on revérifie le jeton.
      const figure = await module.create(this.canvasTarget, this.values, { announce: (text) => this.remember(text), controls: this.controlsValue })
      if (run !== this.generation) return figure?.destroy?.()

      this.figure = figure
      this.buildControls()
    } catch (error) {
      return run === this.generation ? this.fail(error) : undefined
    }
    this.fit()
    this.resize = new ResizeObserver(() => this.fit())
    this.resize.observe(this.canvasTarget)

    // Une figure dont les points se déplacent expose ses poignées : le cadre n'est plus une image opaque.
    this.canvasTarget.setAttribute("role", this.figure.interactive ? "group" : "img")
    this.fallbackTarget.classList.add("sr-only")
    this.element.dataset.figureState = "ready"
  }

  disconnect() {
    this.generation++
    this.clear()
  }

  clear() {
    this.resize?.disconnect()
    this.resize = null
    this.figure?.destroy()
    this.figure = null
    this.controlsTarget.replaceChildren()
    this.live?.remove()
    this.live = null
    this.sliding = false
    this.fallbackTarget.classList.remove("sr-only")
  }

  // État d'erreur : rien n'est dessiné, la description reste la seule figure ; l'erreur n'est jamais avalée en silence.
  fail(error) {
    console.warn("figure : description seule", error)
    this.clear()
    this.canvasTarget.replaceChildren()
    this.element.dataset.figureState = "error"
  }

  // Le texte garde une taille lisible : une figure affichée plus étroite que son viewBox agrandit ses étiquettes, jusqu'à 1,4 fois.
  fit() {
    const svg = this.canvasTarget.querySelector("svg")
    const width = svg?.getBoundingClientRect().width
    if (!width) return

    const ratio = Math.min(1.4, Math.max(1, svg.viewBox.baseVal.width / width))
    this.canvasTarget.style.setProperty("--figure-text", ratio.toFixed(2))
  }

  // Un curseur par contrôle admis : clé numérique de premier niveau déclarée réglable par la sorte, bornes finies, au plus 4.
  buildControls() {
    const allowed = RANGE_PARAMS[this.kindValue]
    this.live = document.createElement("div")
    this.live.className = "sr-only"
    this.live.setAttribute("aria-live", "polite")
    this.element.appendChild(this.live)

    this.controlsValue.slice(0, MAX_CONTROLS).forEach((control, index) => {
      const { param, min, max, step, label } = control ?? {}
      if (!allowed.includes(param) || !finite(this.values[param])) return
      if (![min, max, step].every(finite) || max <= min || step <= 0 || typeof label !== "string") return

      this.controlsTarget.appendChild(this.slider({ param, min, max, step, label }, index))
    })
  }

  slider({ param, min, max, step, label }, index) {
    const wrapper = document.createElement("label")
    wrapper.className = "flex w-full flex-col gap-1"
    const caption = document.createElement("span")
    const input = document.createElement("input")
    input.type = "range"
    input.id = `${this.element.id || "figure"}-${index}-${param}`
    input.min = String(min)
    input.max = String(max)
    input.step = String(step)
    input.value = String(Math.min(max, Math.max(min, this.values[param])))
    input.className = "h-12 w-full"
    input.dataset.param = param

    const show = () => {
      const text = String(Number(input.value)).replace(".", ",")
      caption.textContent = `${label} : ${text}`
      input.setAttribute("aria-valuetext", `${label} : ${text}`)
      return `${label} : ${text}`
    }
    show()
    input.addEventListener("input", () => {
      show()
      this.values = { ...this.values, [param]: Number(input.value) }
      this.spoken = null
      this.sliding = true
      try {
        this.figure.redraw(this.values)
      } catch (error) {
        this.fail(error)
      }
    })
    // Au relâchement, la mesure que la figure vient de dire l'emporte sur le libellé du curseur ; sans mesure, on dit le libellé.
    input.addEventListener("change", () => {
      this.sliding = false
      this.announce(this.spoken ?? show())
    })
    wrapper.append(caption, input)
    return wrapper
  }

  // Ce que la figure dit d'elle-même (module) : retenu pour le relâchement du curseur ; hors geste de curseur (poignée déplacée), dit tout de suite.
  remember(text) {
    this.spoken = text
    if (!this.sliding && this.live) this.live.textContent = text
  }

  announce(text) {
    this.spoken = text
    if (this.live) this.live.textContent = text
  }
}
