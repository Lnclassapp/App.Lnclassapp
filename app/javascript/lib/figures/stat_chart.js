// ⚡ FRONT · lib/figures/stat_chart — le diagramme statistique : bâtons, histogramme ou circulaire
// Rôle : lit `chart` (bars, histogram, pie), `series` (nombres de 0 à 1 000 000) et `labels` (textes, dans le même ordre) ; revérifie les valeurs avant de dessiner
// ADR  : 0116-fiche-de-revision-par-notion-et-figures-parametrees (§4.2) · UDR : 0141-fiche-de-revision-en-quatre-blocs (§3.3) · chargé par import() depuis controllers/figure_controller

import { el, root, label, fixed, round } from "./svg"

const WIDTH = 440
const HEIGHT = 300
const PIE_HEIGHT = 230
const LEFT = 48
const RIGHT = 16
const TOP = 28
const BOTTOM = 52
const MAX_VALUES = 20
const RANGE = 1_000_000
const MAX_TICKS = 50
const CHARTS = ["bars", "histogram", "pie"]
const TONES = ["primary", "accent", "success", "muted", "ink"]

const finite = (value) => typeof value === "number" && Number.isFinite(value)

function read(params) {
  const { chart } = params
  const series = params.series ?? []
  const names = params.labels ?? []
  if (!CHARTS.includes(chart)) throw new Error("stat_chart : sorte de diagramme inconnue")
  if (!Array.isArray(series) || series.length === 0 || series.length > MAX_VALUES || !series.every((value) => finite(value) && value >= 0 && value <= RANGE)) {
    throw new Error("stat_chart : série invalide (nombres de 0 à 1 000 000, 20 au plus)")
  }
  if (!Array.isArray(names) || names.length > MAX_VALUES) throw new Error("stat_chart : étiquettes hors limites")
  if (chart === "pie" && series.reduce((sum, value) => sum + value, 0) <= 0) throw new Error("stat_chart : total nul")

  return { chart, series, names: series.map((_, index) => (typeof names[index] === "string" ? names[index] : "")) }
}

// Une graduation ronde au-dessus du maximum : 1, 2 ou 5 fois une puissance de dix, en 4 intervalles environ.
function niceMax(top) {
  if (top <= 0) return { unit: 0.25, max: 1 }
  const rough = top / 4
  const power = 10 ** Math.floor(Math.log10(rough))
  const unit = [1, 2, 5, 10].find((base) => base * power >= rough) * power
  return { unit, max: Math.ceil(top / unit) * unit }
}

export function create(canvas, params) {
  const state = { svg: null }

  function draw(next) {
    const { chart, series, names } = read(next)
    const svg = root(WIDTH, chart === "pie" ? PIE_HEIGHT : HEIGHT)
    if (chart === "pie") drawPie(svg, series, names)
    else drawBars(svg, series, names, chart === "histogram")
    state.svg?.remove()
    canvas.appendChild(svg)
    state.svg = svg
  }

  function drawBars(svg, series, names, joined) {
    const { unit, max } = niceMax(Math.max(...series))
    const height = HEIGHT - TOP - BOTTOM
    const y = (value) => round(TOP + height - (value / max) * height)
    // Garde : au plus 50 graduations, quoi qu'il arrive aux nombres (une boucle sans fin figerait la page).
    for (let value = 0, ticks = 0; value <= max + 1e-9 && ticks < MAX_TICKS; value += unit, ticks++) {
      el("line", { x1: LEFT, y1: y(value), x2: WIDTH - RIGHT, y2: y(value), stroke: "grid", "stroke-width": 0.75 }, svg)
      label(svg, LEFT - 6, y(value) + 4, fixed(value), { anchor: "end", tone: "muted", size: 11 })
    }
    const slot = (WIDTH - LEFT - RIGHT) / series.length
    const gap = joined ? 0 : slot * 0.25
    series.forEach((value, index) => {
      const x = LEFT + index * slot + gap / 2
      const barHeight = round((value / max) * height)
      el("rect", { x: round(x), y: y(value), width: round(slot - gap), height: barHeight, fill: "primary", stroke: joined ? "paper" : "none", "stroke-width": 1.5, opacity: 0.9, "data-bar": index }, svg)
      label(svg, x + (slot - gap) / 2, y(value) - 6, fixed(value), { tone: "ink", size: 12 })
      label(svg, x + (slot - gap) / 2, TOP + height + 18, names[index], { tone: "muted", size: 12 })
    })
    el("line", { x1: LEFT, y1: y(0), x2: WIDTH - RIGHT, y2: y(0), stroke: "ink", "stroke-width": 2 }, svg)
    el("line", { x1: LEFT, y1: TOP, x2: LEFT, y2: y(0), stroke: "ink", "stroke-width": 2 }, svg)
  }

  // Le circulaire : un secteur par valeur (angle proportionnel), sa part en pourcentage dans la légende à droite.
  function drawPie(svg, series, names) {
    const total = series.reduce((sum, value) => sum + value, 0)
    const [cx, cy, radius] = [128, PIE_HEIGHT / 2, 100]
    let angle = -Math.PI / 2
    series.forEach((value, index) => {
      const sweep = (value / total) * 2 * Math.PI
      const tone = TONES[index % TONES.length]
      if (value > 0) {
        const [x1, y1] = [cx + radius * Math.cos(angle), cy + radius * Math.sin(angle)]
        const [x2, y2] = [cx + radius * Math.cos(angle + sweep), cy + radius * Math.sin(angle + sweep)]
        const d = value === total ? `M${cx} ${cy - radius} A${radius} ${radius} 0 1 1 ${cx} ${cy + radius} A${radius} ${radius} 0 1 1 ${cx} ${cy - radius} z`
          : `M${cx} ${cy} L${round(x1)} ${round(y1)} A${radius} ${radius} 0 ${sweep > Math.PI ? 1 : 0} 1 ${round(x2)} ${round(y2)} z`
        el("path", { d, fill: tone, stroke: "paper", "stroke-width": 2, opacity: 0.9, "data-slice": index }, svg)
      }
      angle += sweep
      const row = 40 + index * Math.min(24, (PIE_HEIGHT - 60) / series.length)
      el("rect", { x: 258, y: row - 11, width: 14, height: 14, fill: tone, opacity: 0.9 }, svg)
      label(svg, 280, row, `${names[index] ? `${names[index]} : ` : ""}${fixed((value / total) * 100, 0)} %`, { anchor: "start", tone: "ink", size: 13 })
    })
  }

  draw(params)
  return {
    interactive: false,
    redraw: draw,
    destroy() {
      state.svg?.remove()
    }
  }
}
