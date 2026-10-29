// ⚡ FRONT · lib/figures/coordinate_plane — le repère orthogonal : axes gradués, points, vecteurs, droites y = ax + b, segments
// Rôle : lit `xmin`, `xmax`, `ymin`, `ymax`, `points`, `vectors`, `lines`, `segments` ; revérifie les bornes avant de dessiner ; repère orthonormé, centré dans le cadre
// ADR  : XXXX-fiche-de-revision-par-notion-et-figures-parametrees (§4.2) · UDR : XXXX-fiche-de-revision-en-quatre-blocs (§3.3) · chargé par import() depuis controllers/figure_controller
//
// Formes lues (contrat de l'ADR §4.2) :
//   point  { id, x, y }     vecteur  { label, dx, dy, ox, oy }     droite  { a, b } (y = ax + b)     segment  { x1, y1, x2, y2 }

import { el, root, label, fixed, round, clamp } from "./svg"

const WIDTH = 440
const HEIGHT = 340
const MARGIN = 30
const RANGE = 50
const LIMITS = { points: 12, vectors: 8, lines: 6, segments: 12 }
const MAX_TICKS = 12
const STEPS = [1, 2, 5]

const finite = (value) => typeof value === "number" && Number.isFinite(value)
const all = (item, keys) => item && typeof item === "object" && keys.every((key) => finite(item[key]))

// Le pas de graduation : 1, 2, 5, 10, 20… le plus petit qui laisse au plus MAX_TICKS repères.
function stepFor(span) {
  for (let power = 1; ; power *= 10) {
    for (const base of STEPS) if (span / (base * power / 10) <= MAX_TICKS) return base * power / 10
  }
}

function read(params) {
  const { xmin, xmax, ymin, ymax } = params
  if (![xmin, xmax, ymin, ymax].every(finite) || xmax <= xmin || ymax <= ymin) throw new Error("coordinate_plane : bornes invalides")
  if ([xmin, xmax, ymin, ymax].some((value) => Math.abs(value) > RANGE)) throw new Error("coordinate_plane : bornes hors limites")

  const model = { xmin, xmax, ymin, ymax }
  for (const [name, max] of Object.entries(LIMITS)) {
    const items = params[name] ?? []
    if (!Array.isArray(items) || items.length > max) throw new Error(`coordinate_plane : ${name} hors limites`)
    model[name] = items
  }
  return model
}

export function create(canvas, params) {
  const state = { svg: null, uid: 0 }

  function draw(next) {
    const { xmin, xmax, ymin, ymax, points, vectors, lines, segments } = read(next)
    const unit = Math.min((WIDTH - 2 * MARGIN) / (xmax - xmin), (HEIGHT - 2 * MARGIN) / (ymax - ymin))
    const left = (WIDTH - (xmax - xmin) * unit) / 2
    const top = (HEIGHT - (ymax - ymin) * unit) / 2
    const px = (x) => round(left + (x - xmin) * unit)
    const py = (y) => round(HEIGHT - top - (y - ymin) * unit)
    const svg = root(WIDTH, HEIGHT)
    const clip = `figure-plane-${state.uid++}`
    const defs = el("defs", {}, svg)
    el("rect", { x: px(xmin), y: py(ymax), width: round((xmax - xmin) * unit), height: round((ymax - ymin) * unit) }, el("clipPath", { id: clip }, defs))

    const [sx, sy] = [stepFor(xmax - xmin), stepFor(ymax - ymin)]
    const axisX = py(clamp(0, ymin, ymax))
    const axisY = px(clamp(0, xmin, xmax))
    el("rect", { x: px(xmin), y: py(ymax), width: round((xmax - xmin) * unit), height: round((ymax - ymin) * unit), fill: "none", stroke: "grid", "stroke-width": 1 }, svg)
    for (let x = Math.ceil(xmin / sx) * sx; x <= xmax + 1e-9; x += sx) {
      const value = round(x)
      el("line", { x1: px(value), y1: py(ymin), x2: px(value), y2: py(ymax), stroke: "grid", "stroke-width": 0.75, "data-xtick": value }, svg)
      if (value !== 0) label(svg, px(value), axisX + 16, fixed(value), { tone: "muted", size: 11 })
    }
    for (let y = Math.ceil(ymin / sy) * sy; y <= ymax + 1e-9; y += sy) {
      const value = round(y)
      el("line", { x1: px(xmin), y1: py(value), x2: px(xmax), y2: py(value), stroke: "grid", "stroke-width": 0.75, "data-ytick": value }, svg)
      if (value !== 0) label(svg, axisY - 6, py(value) + 4, fixed(value), { anchor: "end", tone: "muted", size: 11 })
    }
    el("line", { x1: px(xmin), y1: axisX, x2: px(xmax), y2: axisX, stroke: "ink", "stroke-width": 2 }, svg)
    el("line", { x1: axisY, y1: py(ymin), x2: axisY, y2: py(ymax), stroke: "ink", "stroke-width": 2 }, svg)

    const content = el("g", { "clip-path": `url(#${clip})` }, svg)
    lines.filter((line) => all(line, ["a", "b"])).forEach((line) => {
      el("line", { x1: px(xmin), y1: py(line.a * xmin + line.b), x2: px(xmax), y2: py(line.a * xmax + line.b), stroke: "primary", "stroke-width": 2, "data-line": "" }, content)
    })
    segments.filter((segment) => all(segment, ["x1", "y1", "x2", "y2"])).forEach((segment) => {
      el("line", { x1: px(segment.x1), y1: py(segment.y1), x2: px(segment.x2), y2: py(segment.y2), stroke: "ink", "stroke-width": 2, "stroke-linecap": "round", "data-segment": "" }, content)
    })
    vectors.filter((vector) => finite(vector?.dx) && finite(vector?.dy)).forEach((vector, index) => drawVector(content, vector, index, { px, py }))
    points.filter((point) => all(point, ["x", "y"])).forEach((point) => {
      const group = el("g", { "data-point": point.id ?? "" }, content)
      el("circle", { cx: px(point.x), cy: py(point.y), r: 4.5, fill: "accent", stroke: "paper", "stroke-width": 1.5 }, group)
      if (typeof point.id === "string" && point.id) label(group, px(point.x) + 12, py(point.y) - 8, `${point.id}`, { tone: "accent", size: 14 })
    })

    // Les composantes des vecteurs, lisibles en haut du repère.
    const texts = vectors.filter((vector) => finite(vector?.dx) && finite(vector?.dy)).map((vector) => `${vector.label ?? ""} (${fixed(vector.dx)} ; ${fixed(vector.dy)})`.trim())
    texts.forEach((text, index) => label(svg, px(xmin) + 8, py(ymax) + 18 + index * 18, text, { anchor: "start", tone: "primary", size: 13 }))

    state.svg?.remove()
    canvas.appendChild(svg)
    state.svg = svg
  }

  // Un vecteur : une flèche de l'origine (ox, oy) à (ox + dx, oy + dy), son nom au milieu.
  function drawVector(parent, vector, index, { px, py }) {
    const [ox, oy] = [finite(vector.ox) ? vector.ox : 0, finite(vector.oy) ? vector.oy : 0]
    const [x1, y1, x2, y2] = [px(ox), py(oy), px(ox + vector.dx), py(oy + vector.dy)]
    const group = el("g", { "data-vector": index }, parent)
    el("line", { x1, y1, x2, y2, stroke: "accent", "stroke-width": 2.5, "stroke-linecap": "round" }, group)
    const length = Math.hypot(x2 - x1, y2 - y1)
    if (length > 0) {
      const [ux, uy] = [(x2 - x1) / length, (y2 - y1) / length]
      const head = Math.min(11, length / 2)
      el("path", { d: `M${x2} ${y2} L${round(x2 - head * ux + head * 0.5 * uy)} ${round(y2 - head * uy - head * 0.5 * ux)} L${round(x2 - head * ux - head * 0.5 * uy)} ${round(y2 - head * uy + head * 0.5 * ux)} z`, fill: "accent" }, group)
      if (typeof vector.label === "string" && vector.label) label(group, (x1 + x2) / 2 - 12 * uy, (y1 + y2) / 2 + 12 * ux + 4, vector.label, { tone: "accent", size: 15 })
    }
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
