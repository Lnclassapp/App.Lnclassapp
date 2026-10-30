// ⚡ FRONT · lib/figures/map — la carte : un fond (Côte d'Ivoire, Afrique, monde), des aires par catégorie, des lieux, des routes
// Rôle : lit `base`, `areas`, `places`, `routes`, `legend`, charge le fond par import() (liste blanche), revérifie chaque identifiant, dessine teinte + motif et numérote les étiquettes qui se chevauchent
// ADR  : 0117-figures-des-matieres-de-3eme (§4.2, §4.3, menace) · UDR : 0142-dessin-des-figures-de-3eme (§3) · chargé par import() depuis controllers/figure_controller

import { el, root, label, round, COLOR } from "./svg"

const BASES = ["cote_d_ivoire", "africa", "world"]
const MAX = { areas: 40, places: 20, routes: 10, legend: 6 }
const MAX_TEXT = 60
const WIDTH = 640
const DOT = 5
const MARGIN = 16
const SWATCH = { width: 22, height: 14 }
// Catégories 1 à 6 : teinte et motif ensemble (UDR §3) ; les pleins sont à 0,35 d'opacité, les motifs sont des <pattern>.
const CATEGORIES = [
  { tone: "primary", pattern: null },
  { tone: "success", pattern: null },
  { tone: "accent", pattern: null },
  { tone: "primary", pattern: "hatch" },
  { tone: "success", pattern: "dots" },
  { tone: "muted", pattern: "cross" }
]

// Un identifiant par figure : les <pattern> et le <marker> ne se mélangent pas entre deux cartes d'une même page.
let serial = 0

const isText = (value) => typeof value === "string" && value.trim() !== "" && value.length <= MAX_TEXT
const known = (table, id) => typeof id === "string" && Object.hasOwn(table, id)

// Le texte des figures est agrandi par --figure-text (1 à 1,4) quand la figure est affichée petite : même formule que le contrôleur.
// Un cadre pas encore affiché (largeur 0) est traité au pire cas ; la mesure suivante redessine si le rapport change.
function textScale(canvas) {
  const shown = canvas.getBoundingClientRect().width
  return shown > 0 ? Math.min(1.4, Math.max(1, WIDTH / shown)) : 1.4
}

function read(params, data) {
  const areas = params.areas ?? []
  const places = params.places ?? []
  const routes = params.routes ?? []
  const legend = params.legend ?? []
  for (const [name, list] of Object.entries({ areas, places, routes, legend })) {
    if (!Array.isArray(list) || list.length > MAX[name]) throw new Error(`map : ${name} hors limites`)
  }
  if (!legend.every(isText)) throw new Error("map : légende invalide")
  if (areas.length > 0 && legend.length === 0) throw new Error("map : des aires sans légende")

  const seen = new Set()
  for (const area of areas) {
    const { id, category } = area ?? {}
    if (!known(data.AREAS, id) && !known(data.CONTINENTS ?? {}, id)) throw new Error(`map : aire inconnue « ${id} » dans ce fond`)
    if (seen.has(id)) throw new Error(`map : aire répétée « ${id} »`)
    if (!Number.isInteger(category) || category < 1 || category > legend.length) throw new Error(`map : catégorie invalide pour « ${id} »`)
    seen.add(id)
  }
  for (const place of places) {
    if (!known(data.PLACES, place?.id)) throw new Error(`map : lieu inconnu « ${place?.id} » dans ce fond`)
    if (place.label !== undefined && !isText(place.label)) throw new Error(`map : libellé invalide pour « ${place.id} »`)
  }
  for (const route of routes) {
    if (!known(data.PLACES, route?.from) || !known(data.PLACES, route?.to) || route.from === route.to) throw new Error("map : route entre des lieux inconnus de ce fond")
    if (route.label !== undefined && !isText(route.label)) throw new Error("map : libellé de route invalide")
  }
  return { areas, places, routes, legend }
}

// Les motifs des catégories 4 à 6 (identifiants fig-<key>-pat-<n>) et la pointe de flèche des routes.
function defineDefs(svg, key, count) {
  const defs = el("defs", {}, svg)
  CATEGORIES.slice(0, count).forEach(({ tone, pattern }, index) => {
    if (!pattern) return
    const node = el("pattern", { id: `fig-${key}-pat-${index + 1}`, width: 8, height: 8, patternUnits: "userSpaceOnUse" }, defs)
    el("rect", { x: 0, y: 0, width: 8, height: 8, fill: "paper" }, node)
    if (pattern === "dots") {
      el("circle", { cx: 4, cy: 4, r: 1.7, fill: tone }, node)
      return
    }
    node.setAttribute("patternTransform", "rotate(45)")
    el("line", { x1: 0, y1: 0, x2: 0, y2: 8, stroke: tone, "stroke-width": pattern === "hatch" ? 2 : 1.2 }, node)
    if (pattern === "cross") el("line", { x1: 0, y1: 0, x2: 8, y2: 0, stroke: tone, "stroke-width": 1.2 }, node)
  })
  const marker = el("marker", { id: `fig-${key}-arrow`, viewBox: "0 0 10 10", refX: 8, refY: 5, markerWidth: 4, markerHeight: 4, orient: "auto" }, defs)
  el("path", { d: "M0 0L10 5L0 10z", fill: "accent" }, marker)
}

function paint(node, category, key) {
  const { tone, pattern } = CATEGORIES[category - 1]
  if (pattern) {
    node.setAttribute("fill", `url(#fig-${key}-pat-${category})`)
  } else {
    node.style.setProperty("fill", COLOR[tone])
    node.setAttribute("fill-opacity", "0.35")
  }
}

// --- Étiquettes : quatre positions autour du point, sinon un numéro renvoyé dans la légende --------------------------------------

const overlaps = (a, b) => a.x0 < b.x1 && b.x0 < a.x1 && a.y0 < b.y1 && b.y0 < a.y1
const inside = (box, bounds) => box.x0 >= 0 && box.y0 >= 0 && box.x1 <= bounds.width && box.y1 <= bounds.height

// La boîte réelle d'un texte, mesurée sur la police rendue : ~0,5 em par caractère (0,58 par prudence), 1 em au-dessus de la ligne de base,
// 0,33 em en dessous (jambages), plus 1 unité de marge. Une boîte plus petite que celle-ci laissait deux étiquettes se toucher.
function textBox(anchor, x, baseline, width, em) {
  const x0 = anchor === "start" ? x - 1 : anchor === "end" ? x - width : x - width / 2
  return { x0, x1: x0 + width + 1, y0: baseline - em - 1, y1: baseline + em * 0.33 + 1 }
}

// Quatre positions autour du point : à droite, à gauche, au-dessus, en dessous.
function candidates(x, y, text, em) {
  const width = [...text].length * 0.58 * em + 4
  const gap = DOT + 3
  const right = x + gap
  const left = x - gap
  const level = y + em * 0.35
  const above = y - gap - em * 0.33
  const below = y + gap + em + 1
  const place = (anchor, px, baseline) => ({ anchor, x: px, y: baseline, box: textBox(anchor, px, baseline, width, em) })
  return [
    place("start", right, level),
    place("end", left, level),
    place("middle", x, above),
    place("middle", x, below)
  ]
}

// Pose le texte à la première position libre ; sinon renvoie null.
function fit(x, y, text, em, taken, bounds) {
  const found = candidates(x, y, text, em).find((candidate) => inside(candidate.box, bounds) && !taken.some((box) => overlaps(box, candidate.box)))
  if (found) taken.push(found.box)
  return found ?? null
}

// Découpe un texte aux espaces en lignes d'au plus `chars` caractères.
function wrap(text, chars) {
  const lines = []
  let line = ""
  for (const word of text.split(" ")) {
    if (line !== "" && [...`${line} ${word}`].length > chars) {
      lines.push(line)
      line = word
    } else {
      line = line === "" ? word : `${line} ${word}`
    }
  }
  lines.push(line)
  return lines
}

// Calcule ce qui se dessine : étiquettes posées, numéros de repli et lignes de légende (la hauteur totale en dépend).
function layout({ places, routes, legend }, data, scale) {
  const em = 13 * scale
  const [frameWidth, frameHeight] = data.VIEWBOX
  const bounds = { width: frameWidth, height: frameHeight }
  const spot = (id) => data.PLACES[id]
  const taken = places.map(({ id }) => ({ x0: spot(id).x - DOT - 1, x1: spot(id).x + DOT + 1, y0: spot(id).y - DOT - 1, y1: spot(id).y + DOT + 1 }))
  const notes = []
  const texts = []

  const write = (kind, id, x, y, text) => {
    const spotted = fit(x, y, text, em, taken, bounds)
    if (spotted) return texts.push({ kind, id, text, ...spotted })

    const number = notes.length + 1
    notes.push({ number, text })
    let marked = fit(x, y, String(number), em, taken, bounds)
    if (!marked) {
      marked = candidates(x, y, String(number), em)[0]
      taken.push(marked.box)
    }
    texts.push({ kind, id, text: String(number), number, ...marked })
  }

  places.forEach(({ id, label: custom }) => write("place", id, spot(id).x, spot(id).y, custom ?? spot(id).name))
  const curves = routes.map((route) => curve(spot(route.from), spot(route.to)))
  routes.forEach((route, index) => {
    if (route.label) write("route", index, curves[index].mid.x, curves[index].mid.y, route.label)
  })

  const chars = Math.max(12, Math.floor((frameWidth - MARGIN - SWATCH.width - 14 - MARGIN) / (0.58 * em)))
  const rows = legend.map((text, index) => ({ category: index + 1, lines: wrap(text, chars) }))
  const noteChars = Math.max(12, Math.floor((frameWidth - 2 * MARGIN) / (0.58 * em)))
  notes.forEach(({ number, text }) => rows.push({ number, lines: wrap(`${number}. ${text}`, noteChars) }))
  const height = frameHeight + (rows.length > 0 || data.ATTRIBUTION ? 10 : 0) + rows.reduce((sum, row) => sum + row.lines.length * Math.round(em * 1.3) + 4, 0) + (data.ATTRIBUTION ? Math.round(em * 1.1) + 6 : 0)
  return { em, texts, rows, curves, height }
}

// La route : une quadratique entre deux lieux, raccourcie pour que la pointe de flèche ne se cache pas sous le point.
function curve(from, to) {
  const dx = to.x - from.x
  const dy = to.y - from.y
  const distance = Math.hypot(dx, dy) || 1
  const control = { x: (from.x + to.x) / 2 - (dy / distance) * distance * 0.2, y: (from.y + to.y) / 2 + (dx / distance) * distance * 0.2 }
  const toward = (a, b, length) => {
    const run = Math.hypot(b.x - a.x, b.y - a.y) || 1
    return { x: a.x + ((b.x - a.x) / run) * length, y: a.y + ((b.y - a.y) / run) * length }
  }
  const start = toward(from, control, DOT + 2)
  const end = toward(to, control, DOT + 3)
  const mid = { x: 0.25 * start.x + 0.5 * control.x + 0.25 * end.x, y: 0.25 * start.y + 0.5 * control.y + 0.25 * end.y }
  return { start, control, end, mid }
}

// --- Dessin ------------------------------------------------------------------------------------------------------------------------------

function drawArea(parent, data, id, category, key) {
  const node = Object.hasOwn(data.CONTINENTS ?? {}, id) ? el("g", { "data-area": id, "data-category": category }, parent) : null
  const members = node ? data.CONTINENTS[id] : [id]
  const name = node ? data.CONTINENT_NAMES[id] : data.AREAS[id].name
  for (const member of members) {
    const path = el("path", { d: data.AREAS[member].d, stroke: "muted", "stroke-width": 1.5, "stroke-linejoin": "round" }, node ?? parent)
    paint(path, category, key)
    if (!node) {
      path.setAttribute("data-area", id)
      path.setAttribute("data-category", String(category))
    }
    el("title", { text: node ? data.AREAS[member].name : name }, path)
  }
}

function draw(svgHost, key, data, values, scale) {
  const plan = layout(values, data, scale)
  const frameHeight = data.VIEWBOX[1]
  const svg = root(WIDTH, plan.height)
  defineDefs(svg, key, values.legend.length)

  const colored = new Set(values.areas.flatMap(({ id }) => data.CONTINENTS?.[id] ?? [id]))
  const base = el("g", {}, svg)
  for (const d of data.OUTLINE) el("path", { d, fill: "paper", stroke: "muted", "stroke-opacity": 0.6, "stroke-width": 0.8, "stroke-linejoin": "round" }, base)
  for (const [id, area] of Object.entries(data.AREAS)) {
    if (!colored.has(id)) el("path", { d: area.d, fill: "paper", stroke: "muted", "stroke-opacity": 0.6, "stroke-width": 0.8, "stroke-linejoin": "round" }, base)
  }
  const marked = el("g", {}, svg)
  for (const { id, category } of values.areas) drawArea(marked, data, id, category, key)

  values.routes.forEach((route, index) => {
    const { start, control, end } = plan.curves[index]
    const path = el("path", { d: `M${round(start.x)} ${round(start.y)}Q${round(control.x)} ${round(control.y)} ${round(end.x)} ${round(end.y)}`, fill: "none", stroke: "accent", "stroke-width": 2.5, "stroke-linecap": "round", "data-route": `${route.from}>${route.to}` }, svg)
    path.setAttribute("marker-end", `url(#fig-${key}-arrow)`)
  })
  for (const { id } of values.places) {
    const { x, y } = data.PLACES[id]
    el("circle", { cx: x, cy: y, r: DOT, fill: "ink", stroke: "paper", "stroke-width": 1.5, "data-place": id }, svg)
  }
  for (const text of plan.texts) {
    const node = label(svg, text.x, text.y, text.text, { anchor: text.anchor, size: text.number ? 12 : 13 })
    node.setAttribute(text.kind === "place" ? "data-place-label" : "data-route-label", String(text.id))
    if (text.number) {
      node.setAttribute("data-note", String(text.number))
      node.style.fontWeight = "700"
    }
  }

  drawLegend(svg, plan, key, frameHeight)
  if (data.ATTRIBUTION) {
    const note = label(svg, MARGIN, plan.height - 6, data.ATTRIBUTION, { anchor: "start", tone: "muted", size: 10 })
    note.setAttribute("data-attribution", "")
  }
  svgHost.replaceChildren(svg)
  return svg
}

function drawLegend(svg, plan, key, frameHeight) {
  const line = Math.round(plan.em * 1.3)
  let top = frameHeight + 10
  for (const row of plan.rows) {
    const entry = el("g", row.category ? { "data-legend": row.category } : { "data-legend-note": row.number }, svg)
    if (row.category) {
      const swatch = el("rect", { x: MARGIN, y: top + Math.max(0, (plan.em - SWATCH.height) / 2), ...SWATCH, rx: 2, stroke: "muted", "stroke-width": 1 }, entry)
      paint(swatch, row.category, key)
    }
    row.lines.forEach((text, index) => {
      label(entry, row.category ? MARGIN + SWATCH.width + 14 : MARGIN, top + plan.em * 0.85 + index * line, text, { anchor: "start", size: 13 })
    })
    top += row.lines.length * line + 4
  }
}

export async function create(canvas, params) {
  const base = params.base
  if (!BASES.includes(base)) throw new Error(`map : fond inconnu « ${base} »`)

  // Le fond n'est chargé que par une page qui a une carte ; `base` a passé la liste blanche ci-dessus.
  const data = await import(`./maps/${base}.js`)
  const key = `map${++serial}`
  const state = { svg: null, values: read(params, data), scale: textScale(canvas) }

  const render = () => {
    state.svg = draw(canvas, key, data, state.values, state.scale)
  }
  render()

  // Le cadre n'a de largeur qu'une fois affiché, et change avec la fenêtre : on redessine quand le rapport du texte change.
  const observer = new ResizeObserver(() => {
    const scale = textScale(canvas)
    if (Math.abs(scale - state.scale) < 0.05) return
    state.scale = scale
    render()
  })
  observer.observe(canvas)

  return {
    interactive: false,
    redraw(next) {
      state.values = read(next, data)
      render()
    },
    destroy() {
      observer.disconnect()
      state.svg?.remove()
    }
  }
}
