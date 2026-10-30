// ⚡ FRONT · lib/figures/timeline — la frise chronologique : axe gradué, périodes en bandes, événements en quinconce
// Rôle : lit `start`, `end`, `step`, `unit`, `periods` [{from, to, label}] et `events` [{at, label}] ; revérifie bornes et formes avant de dessiner ; les curseurs `start`/`end` zooment
// ADR  : XXXX-figures-des-matieres-de-3eme (§4.2) · UDR : XXXX-figures-des-matieres-de-3eme (§3 timeline) · chargé par import() depuis controllers/figure_controller

import { el, root, label, fixed, round, clamp } from "./svg"

const WIDTH = 640
const HEIGHT = 180
const AXIS_LEFT = 30
const AXIS_RIGHT = 574
const AXIS_Y = 62
const BAND_TOP = 8
const BAND_HEIGHT = 32
const ROWS = [112, 138]
const LEGEND_TOP = 172
const LEGEND_LINE = 18
const MAX_TICKS = 200
const RANGE = { min: -3000, max: 2100 }
const LIMITS = { periods: 8, events: 16 }
// Largeur d'un caractère en unités du dessin, comptée au texte agrandi au maximum (× 1,4 au téléphone) : l'estimation ne sous-évalue jamais.
const CHAR = 10.5
const GAP = 4
const UNITS = { year: "", month: "mois", day: "jour" }
const CATEGORIES = 6

const finite = (value) => typeof value === "number" && Number.isFinite(value)
const text = (value) => typeof value === "string" && value.trim() !== ""
const plain = (value) => value !== null && typeof value === "object" && !Array.isArray(value)

let figures = 0

// Les paramètres lus, ou une erreur : le contrôleur montre alors la description seule.
function read(params) {
  const { start, end, step } = params
  const unit = params.unit ?? "year"
  if (![start, end, step].every(finite) || end <= start || step <= 0) throw new Error("timeline : bornes ou graduation invalides")
  if (start < RANGE.min || end > RANGE.max) throw new Error("timeline : bornes hors limites")
  if ((end - start) / step > MAX_TICKS) throw new Error("timeline : trop de graduations")
  if (!Object.hasOwn(UNITS, unit)) throw new Error("timeline : unité inconnue")

  const periods = params.periods ?? []
  const events = params.events ?? []
  if (!Array.isArray(periods) || periods.length > LIMITS.periods) throw new Error("timeline : périodes hors limites")
  if (!Array.isArray(events) || events.length > LIMITS.events) throw new Error("timeline : événements hors limites")
  periods.forEach((period) => {
    if (!plain(period) || !finite(period.from) || !finite(period.to) || period.from >= period.to || !text(period.label)) throw new Error("timeline : période mal formée")
  })
  events.forEach((event) => {
    if (!plain(event) || !finite(event.at) || !text(event.label)) throw new Error("timeline : événement mal formé")
  })

  return { start, end, step, unit, periods, events }
}

// Les motifs des catégories 4 à 6 (teinte et motif ensemble) ; les trois premières sont des aplats.
const PATTERNS = {
  4: (pattern) => el("line", { x1: 0, y1: 0, x2: 0, y2: 8, stroke: "primary", "stroke-width": 2 }, pattern),
  5: (pattern) => el("circle", { cx: 3, cy: 3, r: 1.6, fill: "success" }, pattern),
  6: (pattern) => {
    el("line", { x1: 0, y1: 0, x2: 0, y2: 8, stroke: "muted", "stroke-width": 1.5 }, pattern)
    el("line", { x1: 0, y1: 4, x2: 8, y2: 4, stroke: "muted", "stroke-width": 1.5 }, pattern)
  }
}
const SOLIDS = { 1: "primary", 2: "success", 3: "accent" }

function definePatterns(svg, prefix, used) {
  const defs = el("defs", {}, svg)
  used.filter((category) => PATTERNS[category]).forEach((category) => {
    const size = category === 5 ? 6 : 8
    const attrs = { id: `${prefix}-pat-${category}`, width: size, height: size, patternUnits: "userSpaceOnUse" }
    if (category !== 5) attrs.patternTransform = "rotate(45)"
    PATTERNS[category](el("pattern", attrs, defs))
  })
}

// Un texte tronqué à `room` unités avec « … », ou vide s'il n'y tient pas.
function fit(value, room) {
  const chars = Math.floor(room / CHAR)
  if (chars < 1) return ""
  if (value.length <= chars) return value
  return chars < 2 ? "" : `${value.slice(0, chars - 1)}…`
}

export function create(canvas, params) {
  const state = { svg: null }
  const prefix = `fig-timeline-${++figures}`

  function draw(next) {
    const { start, end, step, unit, periods, events } = read(next)
    const x = (value) => AXIS_LEFT + ((clamp(value, start, end) - start) / (end - start)) * (AXIS_RIGHT - AXIS_LEFT)
    const shown = events.filter((event) => event.at >= start && event.at <= end).sort((a, b) => a.at - b.at)
    const visible = periods.filter((period) => period.to > start && period.from < end)
    const layout = arrange(shown, x)
    const height = layout.numbered ? LEGEND_TOP + shown.length * LEGEND_LINE : HEIGHT
    const svg = root(WIDTH, height)

    definePatterns(svg, prefix, visible.map((_, index) => (index % CATEGORIES) + 1))
    visible.forEach((period, index) => drawPeriod(svg, period, (index % CATEGORIES) + 1, x))
    drawAxis(svg, { start, end, step, unit, x })

    shown.forEach((event, index) => {
      const slot = layout.slots[index]
      const group = el("g", { "data-event": index }, svg)
      el("line", { x1: round(x(event.at)), y1: AXIS_Y, x2: round(x(event.at)), y2: ROWS[slot.row] - 16, stroke: "muted", "stroke-width": 1.5 }, group)
      el("circle", { cx: round(x(event.at)), cy: AXIS_Y, r: 5, fill: "accent", stroke: "paper", "stroke-width": 1.5 }, group)
      label(group, slot.center, ROWS[slot.row], layout.numbered ? String(index + 1) : event.label, { tone: "accent", size: 13 })
    })
    if (layout.numbered) drawLegend(svg, shown)

    state.svg?.remove()
    canvas.appendChild(svg)
    state.svg = svg
  }

  // Deux rangs en quinconce : un libellé qui chevauche le précédent de son rang passe à l'autre ; si aucun rang n'est libre, tous deviennent des numéros.
  function arrange(shown, x) {
    const place = (labels) => {
      const rights = [-Infinity, -Infinity]
      const slots = []
      for (const value of labels) {
        const width = value.length * CHAR + 6
        if (width > WIDTH - 4) return null
        const left = clamp(x(shown[slots.length].at) - width / 2, 2, WIDTH - 2 - width)
        const row = rights.findIndex((right) => left >= right + GAP)
        if (row === -1) return null

        rights[row] = left + width
        slots.push({ row, center: left + width / 2 })
      }
      return slots
    }
    const named = place(shown.map((event) => event.label))
    if (named) return { numbered: false, slots: named }

    const numbers = place(shown.map((_, index) => String(index + 1)))
    // Même numérotée, une frise très serrée alterne les rangs plutôt que de ne rien dessiner.
    return { numbered: true, slots: numbers ?? shown.map((event, index) => ({ row: index % 2, center: x(event.at) })) }
  }

  function drawPeriod(svg, period, category, x) {
    const left = x(period.from)
    const width = x(period.to) - left
    const group = el("g", { "data-period": category }, svg)
    const attrs = { x: round(left), y: BAND_TOP, width: round(width), height: BAND_HEIGHT, rx: 4, stroke: "grid", "stroke-width": 1.5 }
    if (SOLIDS[category]) el("rect", { ...attrs, fill: SOLIDS[category], "fill-opacity": 0.35 }, group)
    else el("rect", attrs, group).style.setProperty("fill", `url(#${prefix}-pat-${category})`)
    const caption = fit(period.label, width - 8)
    if (caption) label(group, left + width / 2, BAND_TOP + BAND_HEIGHT / 2 + 5, caption)
  }

  function drawAxis(svg, { start, end, step, unit, x }) {
    el("line", { x1: AXIS_LEFT - 10, y1: AXIS_Y, x2: AXIS_RIGHT + 10, y2: AXIS_Y, stroke: "ink", "stroke-width": 2.5 }, svg)
    el("path", { d: `M${AXIS_RIGHT + 10} ${AXIS_Y} l-8 -4 v8 z`, fill: "ink" }, svg)
    const ticks = Math.floor((end - start) / step + 1e-9)
    const spacing = ((AXIS_RIGHT - AXIS_LEFT) / (end - start)) * step
    const widest = Math.max(String(fixed(start)).length, String(fixed(start + ticks * step)).length) * CHAR + 12
    const every = Math.max(1, Math.ceil(widest / spacing))
    for (let index = 0; index <= ticks; index++) {
      const value = start + index * step
      el("line", { x1: round(x(value)), y1: AXIS_Y - 6, x2: round(x(value)), y2: AXIS_Y + 6, stroke: "ink", "stroke-width": 1.5, "data-tick": index }, svg)
      if (index % every === 0) label(svg, x(value), AXIS_Y + 26, fixed(value), { tone: "muted", size: 13 })
    }
    if (UNITS[unit]) label(svg, AXIS_RIGHT + 18, AXIS_Y + 5, UNITS[unit], { anchor: "start", tone: "muted", size: 12 })
  }

  function drawLegend(svg, shown) {
    const group = el("g", { "data-legend": shown.length }, svg)
    shown.forEach((event, index) => {
      label(group, 8, LEGEND_TOP + index * LEGEND_LINE, `${index + 1}. ${event.at} : ${event.label}`, { anchor: "start", size: 12 })
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
