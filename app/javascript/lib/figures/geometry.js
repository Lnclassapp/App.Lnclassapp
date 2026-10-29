// ⚡ FRONT · lib/figures/geometry — la figure de géométrie : points, segments, droites, cercles, angles, longueurs, contraintes, points déplaçables
// Rôle : lit `points`, `segments`, `lines`, `circles`, `angles`, `labels`, `constraints` ; un point `draggable` se déplace au pointeur et aux flèches, les mesures se recalculent en direct
// ADR  : XXXX-fiche-de-revision-par-notion-et-figures-parametrees (§4.2) · UDR : XXXX-fiche-de-revision-en-quatre-blocs (§3.3, §3.6) · chargé par import() depuis controllers/figure_controller
//
// Formes lues (contrat de l'ADR §4.2, « Formes des éléments » ; les clés absentes sont ignorées, jamais interprétées) :
//   point       { id, x, y, label?, draggable? }       segment, droite  [id, id]       cercle  { center, r }
//   angle       { vertex, from, to, mark: "right" | "arc" }                             longueur  { from, to, text }
//   contrainte  { point, on: "AB" } : le point reste sur le segment dont « AB » colle les deux identifiants
//   point dérivé  { point, on: "AC", parallel_to: "BC", through: "D" } : le point est l'intersection de (AC) et de la parallèle à (BC) passant par D (Thalès), recalculée quand D bouge

import { el, root, label, fixed, round, clamp, hitRadius } from "./svg"

const WIDTH = 440
const HEIGHT = 320
const PAD = 44
const STEP = 1
const FINE_STEP = 0.25
const LIMITS = { points: 12, segments: 30, lines: 12, circles: 6, angles: 12, labels: 20, constraints: 12 }
const COORDINATE = 20

const finite = (value) => typeof value === "number" && Number.isFinite(value)
const isId = (value) => typeof value === "string" && value.length > 0
const pair = (item) => (Array.isArray(item) ? [item[0], item[1]] : [item?.from, item?.to])
const list = (value, name) => {
  const items = value ?? []
  if (!Array.isArray(items) || items.length > LIMITS[name]) throw new Error(`geometry : ${name} hors limites`)
  return items
}

// Les paramètres revérifiés : listes bornées, coordonnées finies et dans l'intervalle, identifiants uniques.
function read(params) {
  const model = Object.fromEntries(Object.keys(LIMITS).map((name) => [name, list(params[name], name)]))
  const ids = new Set()
  model.points.forEach((point) => {
    if (!point || !isId(point.id) || ids.has(point.id)) throw new Error("geometry : point invalide")
    ids.add(point.id)
    const coords = [point.x, point.y]
    if (!coords.every((value) => finite(value) && Math.abs(value) <= COORDINATE)) throw new Error("geometry : coordonnées hors limites")
  })
  return model
}

const sub = (p, q) => ({ x: p.x - q.x, y: p.y - q.y })
const dist = (p, q) => Math.hypot(p.x - q.x, p.y - q.y)
const valid = (p) => p && finite(p.x) && finite(p.y)

// Projette P sur la droite (A, B), ou sur le segment [A, B] si `bounded`.
function onLine(p, a, b, bounded) {
  const d = sub(b, a)
  const squared = d.x * d.x + d.y * d.y
  if (squared === 0) return { ...a }

  let k = ((p.x - a.x) * d.x + (p.y - a.y) * d.y) / squared
  if (bounded) k = clamp(k, 0, 1)
  return { x: a.x + k * d.x, y: a.y + k * d.y }
}

export function create(canvas, params, hooks = {}) {
  let model = read(params)
  const moved = new Map()
  const svg = root(WIDTH, HEIGHT)
  canvas.appendChild(svg)
  let drag = null
  let shown = null

  const draggableIds = () => new Set(model.points.filter((point) => point.draggable === true).map((point) => point.id))

  // Les positions : points de départ ou déplacés, ramenés sur leur segment par les contraintes.
  function positions() {
    const at = {}
    model.points.forEach((point) => {
      at[point.id] = moved.get(point.id) ?? { x: point.x, y: point.y }
    })
    model.constraints.filter((rule) => !derived(rule)).forEach((rule) => {
      if (at[rule?.point] && draggableIds().has(rule.point)) at[rule.point] = constrain(at[rule.point], rule, at)
    })
    model.constraints.filter(derived).forEach((rule) => {
      const spot = parallelPoint(rule, at)
      if (at[rule.point] && spot) at[rule.point] = spot
    })
    return at
  }

  // « AB » : on cherche la coupe en deux identifiants connus (les identifiants n'ont pas tous une lettre).
  function ends(on, at) {
    if (typeof on !== "string") return null
    for (let cut = 1; cut < on.length; cut++) {
      const [a, b] = [on.slice(0, cut), on.slice(cut)]
      if (valid(at[a]) && valid(at[b])) return [at[a], at[b]]
    }
    return null
  }

  const derived = (rule) => typeof rule?.parallel_to === "string" && typeof rule?.through === "string"

  // L'intersection de la droite « on » et de la parallèle à « parallel_to » passant par « through » ; null si elles sont parallèles.
  function parallelPoint(rule, at) {
    const [line, guide, through] = [ends(rule.on, at), ends(rule.parallel_to, at), at[rule.through]]
    if (!line || !guide || !valid(through)) return null

    const [d, v] = [sub(line[1], line[0]), sub(guide[1], guide[0])]
    const det = d.x * v.y - d.y * v.x
    if (Math.abs(det) < 1e-9) return null

    const w = sub(through, line[0])
    const k = (w.x * v.y - w.y * v.x) / det
    return { x: line[0].x + k * d.x, y: line[0].y + k * d.y }
  }

  function constrain(point, rule, at) {
    const segment = ends(rule.on, at)
    return segment ? onLine(point, segment[0], segment[1], true) : point
  }

  // Le cadrage : fixé une fois sur la figure de départ, pour que rien ne bouge d'échelle pendant un déplacement.
  function frame() {
    const at = positions()
    const xs = Object.values(at).map((p) => p.x)
    const ys = Object.values(at).map((p) => p.y)
    model.circles.forEach((circle) => {
      const c = at[circle?.center]
      if (valid(c) && finite(circle.r)) {
        xs.push(c.x - circle.r, c.x + circle.r)
        ys.push(c.y - circle.r, c.y + circle.r)
      }
    })
    if (xs.length === 0) throw new Error("geometry : aucun point")

    const [minX, maxX, minY, maxY] = [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys)]
    // Une bande en haut pour les mesures, sur deux colonnes, ajoutée à la hauteur : la figure garde toute sa place.
    const rows = Math.ceil((model.labels.length + Math.floor(model.labels.length / 2)) / 2)
    const band = rows > 0 ? rows * 24 + 8 : 0
    const height = HEIGHT + band
    svg.setAttribute("viewBox", `0 0 ${WIDTH} ${height}`)
    const scale = Math.min((WIDTH - 2 * PAD) / (maxX - minX || 1), (HEIGHT - 2 * PAD) / (maxY - minY || 1), 60)
    const offsetX = (WIDTH - (maxX - minX) * scale) / 2
    const offsetY = (HEIGHT - (maxY - minY) * scale) / 2
    return { scale, minX, maxX, minY, maxY, px: (x) => offsetX + (x - minX) * scale, py: (y) => height - offsetY - (y - minY) * scale }
  }

  function draw() {
    const at = positions()
    const { px, py, scale } = shown
    svg.replaceChildren()
    const next = svg
    const P = (id) => (valid(at[id]) ? { x: px(at[id].x), y: py(at[id].y) } : null)
    const centroid = (() => {
      const all = Object.values(at)
      return { x: all.reduce((s, p) => s + px(p.x), 0) / all.length, y: all.reduce((s, p) => s + py(p.y), 0) / all.length }
    })()
    // Le sens dans lequel un nom de point s'écarte de la figure (unitaire).
    const awayOf = (id) => {
      const p = P(id)
      if (!p) return { x: 0, y: 0 }

      const away = { x: p.x - centroid.x, y: p.y - centroid.y }
      const norm = Math.hypot(away.x, away.y) || 1
      return { x: away.x / norm, y: away.y / norm }
    }

    model.circles.forEach((circle) => {
      const c = P(circle?.center)
      if (c && finite(circle.r) && circle.r > 0) el("circle", { cx: round(c.x), cy: round(c.y), r: round(circle.r * scale), fill: "none", stroke: "muted", "stroke-width": 1.5, "data-circle": "" }, next)
    })
    model.lines.forEach((line) => {
      const [a, b] = pair(line).map(P)
      if (a && b && dist(a, b) > 0) {
        const far = (WIDTH + HEIGHT) / dist(a, b)
        el("line", { x1: round(a.x - far * (b.x - a.x)), y1: round(a.y - far * (b.y - a.y)), x2: round(a.x + far * (b.x - a.x)), y2: round(a.y + far * (b.y - a.y)), stroke: "muted", "stroke-width": 1.5, "stroke-dasharray": "6 4", "data-line": "" }, next)
      }
    })
    model.segments.forEach((segment) => {
      const [a, b] = pair(segment).map(P)
      if (a && b) el("line", { x1: round(a.x), y1: round(a.y), x2: round(b.x), y2: round(b.y), stroke: "ink", "stroke-width": 2, "stroke-linecap": "round", "data-segment": "" }, next)
    })
    model.angles.forEach((angle) => drawAngle(next, angle, at, { px, py }))

    const handles = draggableIds()
    const rendered = shown.size ?? hitRadius(WIDTH, canvas.getBoundingClientRect().width)
    model.points.forEach((point) => {
      const p = P(point.id)
      if (!p) return

      const away = awayOf(point.id)
      const name = typeof point.label === "string" && point.label ? point.label : point.id
      const spot = el("g", {}, next)
      el("circle", { cx: round(p.x), cy: round(p.y), r: handles.has(point.id) ? 6.5 : 4, fill: handles.has(point.id) ? "accent" : "ink", stroke: "paper", "stroke-width": 1.5, "data-dot": point.id }, spot)
      label(spot, p.x + 16 * away.x, p.y + 16 * away.y + 4, name, { size: 15 }).setAttribute("data-name", point.id)
      if (handles.has(point.id)) drawHandle(spot, point, at[point.id], p, rendered)
    })

    drawMeasures(next, at, { px, py, awayOf })
    if (drag) svg.querySelector(`[data-point="${CSS.escape(drag)}"]`)?.focus({ preventScroll: true })
  }

  // La poignée : une zone de toucher de 48 px, au clavier (flèches) et au pointeur.
  function drawHandle(parent, point, at, p, radius) {
    const handle = el("circle", {
      cx: round(p.x), cy: round(p.y), r: radius, fill: "none", "data-point": point.id, tabindex: 0, role: "slider",
      "aria-label": `Point ${point.label || point.id}`, "aria-valuetext": `x = ${fixed(at.x)}, y = ${fixed(at.y)}`
    }, parent)
    handle.style.pointerEvents = "all"
    handle.style.cursor = "grab"
    handle.style.outlineOffset = "2px"
    handle.addEventListener("pointerdown", (event) => grab(event, point.id))
    handle.addEventListener("keydown", (event) => nudge(event, point.id))
  }

  function drawAngle(parent, angle, at, { px, py }) {
    const [o, a, b] = [at[angle?.vertex], at[angle?.from], at[angle?.to]]
    if (!valid(o) || !valid(a) || !valid(b)) return

    const start = Math.atan2(-(a.y - o.y), a.x - o.x)
    const end = Math.atan2(-(b.y - o.y), b.x - o.x)
    let delta = end - start
    while (delta > Math.PI) delta -= 2 * Math.PI
    while (delta < -Math.PI) delta += 2 * Math.PI
    const [cx, cy] = [px(o.x), py(o.y)]
    const radius = 20
    const group = el("g", { "data-angle": angle.vertex }, parent)
    if (angle.mark === "right") {
      const ux = [Math.cos(start), Math.sin(start)]
      const vx = [Math.cos(end), Math.sin(end)]
      const d = `M${round(cx + 14 * ux[0])} ${round(cy + 14 * ux[1])} L${round(cx + 14 * (ux[0] + vx[0]))} ${round(cy + 14 * (ux[1] + vx[1]))} L${round(cx + 14 * vx[0])} ${round(cy + 14 * vx[1])}`
      el("path", { d, fill: "none", stroke: "ink", "stroke-width": 1.5 }, group)
      return
    }
    const sweep = delta > 0 ? 1 : 0
    const d = `M${round(cx + radius * Math.cos(start))} ${round(cy + radius * Math.sin(start))} A${radius} ${radius} 0 0 ${sweep} ${round(cx + radius * Math.cos(end))} ${round(cy + radius * Math.sin(end))}`
    el("path", { d, fill: "none", stroke: "primary", "stroke-width": 2 }, group)
    const mid = start + delta / 2
    label(group, cx + (radius + 14) * Math.cos(mid), cy + (radius + 14) * Math.sin(mid) + 4, `${fixed(Math.abs(delta) * 180 / Math.PI, 0)}°`, { tone: "primary", size: 12 })
  }

  // Les mesures en direct : la longueur de chaque segment étiqueté, puis le rapport des étiquettes deux à deux (1re sur 2e, 3e sur 4e…).
  function lines(at) {
    const length = (item) => {
      const [a, b] = [at[item?.from], at[item?.to]]
      return valid(a) && valid(b) ? dist(a, b) : null
    }
    const name = (item) => `${item.from}${item.to}`
    const out = model.labels.map((item) => (length(item) === null ? null : `${name(item)} = ${fixed(length(item), 1)}`))
    for (let index = 0; index + 1 < model.labels.length; index += 2) {
      const [top, bottom] = [model.labels[index], model.labels[index + 1]]
      if (length(top) !== null && length(bottom)) out.push(`${name(top)}/${name(bottom)} = ${fixed(length(top) / length(bottom), 2)}`)
    }
    return out.filter(Boolean)
  }

  // Le texte de l'étiquette, posé au milieu de son segment ; les mesures, dans la bande du haut.
  // Le texte de l'étiquette est décalé perpendiculairement au segment, du côté opposé aux noms de ses extrémités : il ne les recouvre pas.
  function drawMeasures(parent, at, { px, py, awayOf }) {
    model.labels.forEach((item) => {
      const [a, b] = [at[item?.from], at[item?.to]]
      if (!valid(a) || !valid(b) || typeof item.text !== "string" || !item.text) return

      const [dx, dy] = [px(b.x) - px(a.x), py(b.y) - py(a.y)]
      const norm = Math.hypot(dx, dy) || 1
      let normal = { x: -dy / norm, y: dx / norm }
      const [from, to] = [awayOf(item.from), awayOf(item.to)]
      if (normal.x * (from.x + to.x) + normal.y * (from.y + to.y) > 0) normal = { x: -normal.x, y: -normal.y }
      const [mx, my] = [px((a.x + b.x) / 2) + 14 * normal.x, py((a.y + b.y) / 2) + 14 * normal.y]
      label(parent, mx, my + 4, item.text, { tone: "muted", size: 12 }).setAttribute("data-length", `${item.from}${item.to}`)
    })
    lines(at).forEach((text, index) => label(parent, 10 + (index % 2) * (WIDTH / 2), 24 + Math.floor(index / 2) * 24, text, { anchor: "start", tone: "primary", size: 14 }))
  }

  function announce() {
    const text = lines(positions()).join(", ")
    if (text) hooks.announce?.(text)
  }

  // --- gestes ---

  function grab(event, id) {
    event.preventDefault()
    drag = id
    try {
      svg.setPointerCapture(event.pointerId)
    } catch {
      drag = null
      return
    }
    svg.onpointermove = (move) => {
      const matrix = svg.getScreenCTM()
      if (!drag || !matrix) return

      const spot = new DOMPoint(move.clientX, move.clientY).matrixTransform(matrix.inverse())
      place(drag, { x: shown.minX + (spot.x - (shown.px(shown.minX))) / shown.scale, y: shown.minY + (shown.py(shown.minY) - spot.y) / shown.scale })
    }
    svg.onpointerup = svg.onpointercancel = () => {
      drag = null
      svg.onpointermove = null
      announce()
    }
  }

  function nudge(event, id) {
    const arrows = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, 1], ArrowDown: [0, -1] }
    const direction = arrows[event.key]
    if (!direction) return

    event.preventDefault()
    drag = id
    const step = event.shiftKey ? FINE_STEP : STEP
    const current = positions()[id]
    place(id, { x: current.x + direction[0] * step, y: current.y + direction[1] * step })
    drag = null
    announce()
  }

  // Le point est contraint (au tracé), borné au cadre de la figure puis redessiné.
  function place(id, spot) {
    moved.set(id, { x: clamp(spot.x, -COORDINATE, COORDINATE), y: clamp(spot.y, -COORDINATE, COORDINATE) })
    draw()
    if (drag === null) svg.querySelector(`[data-point="${CSS.escape(id)}"]`)?.focus({ preventScroll: true })
  }

  shown = frame()
  draw()
  return {
    interactive: draggableIds().size > 0,
    redraw(next) {
      model = read(next)
      moved.clear()
      shown = frame()
      draw()
    },
    destroy() {
      svg.remove()
    }
  }
}
