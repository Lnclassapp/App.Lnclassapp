// ⚡ FRONT · lib/figures/number_line — la droite graduée : graduation, points, intervalles ouverts ou fermés
// Rôle : lit `min`, `max`, `step`, `points` [{value, label}] et `intervals` [{from, to, from_open, to_open}] ; revérifie les bornes avant de dessiner
// ADR  : XXXX-fiche-de-revision-par-notion-et-figures-parametrees (§4.2) · UDR : XXXX-fiche-de-revision-en-quatre-blocs (§3.3) · chargé par import() depuis controllers/figure_controller

import { el, root, label, fixed, round, clamp } from "./svg"

const WIDTH = 440
const HEIGHT = 88
const MARGIN = 28
const AXIS_Y = 52
const MAX_TICKS = 200
const MAX_LABELS = 11
const LIMITS = { points: 12, intervals: 6 }
const RANGE = 100

const finite = (value) => typeof value === "number" && Number.isFinite(value)

// Les paramètres lus, ou une erreur : le contrôleur montre alors la description seule.
function read(params) {
  const { min, max, step } = params
  if (![min, max, step].every(finite) || max <= min || step <= 0) throw new Error("number_line : bornes ou graduation invalides")
  if (Math.abs(min) > RANGE || Math.abs(max) > RANGE) throw new Error("number_line : bornes hors limites")
  if ((max - min) / step > MAX_TICKS) throw new Error("number_line : trop de graduations")

  const points = params.points ?? []
  const intervals = params.intervals ?? []
  if (!Array.isArray(points) || points.length > LIMITS.points) throw new Error("number_line : points hors limites")
  if (!Array.isArray(intervals) || intervals.length > LIMITS.intervals) throw new Error("number_line : intervalles hors limites")

  return { min, max, step, points: points.filter((point) => finite(point?.value)), intervals: intervals.filter((range) => range && typeof range === "object") }
}

export function create(canvas, params) {
  const state = { svg: null }

  function draw(next) {
    const { min, max, step, points, intervals } = read(next)
    const x = (value) => MARGIN + ((clamp(value, min, max) - min) / (max - min)) * (WIDTH - 2 * MARGIN)
    const svg = root(WIDTH, HEIGHT)

    const ticks = Math.floor((max - min) / step + 1e-9)
    const every = Math.ceil((ticks + 1) / MAX_LABELS)
    el("line", { x1: MARGIN - 10, y1: AXIS_Y, x2: WIDTH - MARGIN + 10, y2: AXIS_Y, stroke: "ink", "stroke-width": 2 }, svg)
    el("path", { d: `M${WIDTH - MARGIN + 10} ${AXIS_Y} l-8 -4 v8 z`, fill: "ink" }, svg)
    for (let index = 0; index <= ticks; index++) {
      const value = min + index * step
      el("line", { x1: round(x(value)), y1: AXIS_Y - 5, x2: round(x(value)), y2: AXIS_Y + 5, stroke: "ink", "stroke-width": 1.5, "data-tick": index }, svg)
      if (index % every === 0) label(svg, x(value), AXIS_Y + 24, fixed(value), { tone: "muted", size: 12 })
    }

    intervals.forEach((range, index) => drawInterval(svg, range, index, { x, min, max }))
    // Une étiquette qui chevaucherait la précédente de son rang monte d'un rang (2 rangs ; largeur comptée au texte agrandi, × 1,4).
    const ordered = [...points].sort((a, b) => a.value - b.value)
    const rights = [-Infinity, -Infinity]
    ordered.forEach((point) => {
      const group = el("g", { "data-point": point.value }, svg)
      el("circle", { cx: round(x(point.value)), cy: AXIS_Y, r: 5, fill: "accent", stroke: "paper", "stroke-width": 1.5 }, group)
      if (typeof point.label !== "string" || !point.label) return

      const half = point.label.length * 6 + 3
      const free = rights.findIndex((right) => x(point.value) - half >= right)
      const row = free === -1 ? (rights[0] <= rights[1] ? 0 : 1) : free
      label(group, x(point.value), AXIS_Y - 14 - row * 20, point.label, { tone: "accent", size: 14 })
      rights[row] = x(point.value) + half
    })

    state.svg?.remove()
    canvas.appendChild(svg)
    state.svg = svg
  }

  // Un intervalle : un trait épais sur l'axe, un crochet plein (fermé) ou creux (ouvert) à chaque bout ; un bout absent va à l'infini.
  function drawInterval(svg, range, index, { x, min, max }) {
    const from = finite(range.from) ? range.from : null
    const to = finite(range.to) ? range.to : null
    const left = x(from ?? min)
    const right = x(to ?? max)
    const group = el("g", { "data-interval": index }, svg)
    el("line", { x1: round(left), y1: AXIS_Y, x2: round(right), y2: AXIS_Y, stroke: "primary", "stroke-width": 7, "stroke-linecap": "butt", opacity: 0.85 }, group)
    ;[[from, left, range.from_open], [to, right, range.to_open]].forEach(([value, position, open]) => {
      if (value === null) return

      el("circle", { cx: round(position), cy: AXIS_Y, r: 7, fill: open === true ? "paper" : "primary", stroke: "primary", "stroke-width": 2.5 }, group)
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
