// ⚡ FRONT · lib/figures/diagram — le schéma fléché : enchaînement (flow), arbre (tree) ou cycle, calculé, jamais placé à la main
// Rôle : lit `layout`, `direction`, `nodes`, `edges`, `legend` et revérifie leurs formes avant de dessiner ; nœuds de 3 lignes au plus (texte tronqué par « … », texte complet en <title>), flèches par <marker> propre à la figure
// ADR  : XXXX-figures-des-matieres-de-3eme (§4.2) · UDR : XXXX-figures-des-matieres-de-3eme (§3) · chargé par import() depuis controllers/figure_controller

import { el, root, label, round } from "./svg"

const WIDTH = 640
const MAX_HEIGHT = 640
const MARGIN = 20
const INNER = WIDTH - 2 * MARGIN
const MAX_NODES = 12
const MAX_EDGES = 16
const MAX_LEGEND = 4
const MAX_CATEGORY = 6
const MAX_NODE_WIDTH = 180
const MIN_NODE_WIDTH = 64
const CHAR = 9 // unités par caractère : 13 px agrandis jusqu'à 1,4 fois au téléphone
const LINE = 18
const PAD_X = 8
const PAD_Y = 6
const MAX_LINES = 3
const GAP_X = 32
const GAP_Y = 44
const LEGEND_ROW = 22
const LAYOUTS = ["flow", "tree", "cycle"]
const DIRECTIONS = ["down", "right"]
// Catégories 1 à 3 : teinte pleine ; 4 à 6 : motif (UDR §3). Aucune information portée par la seule couleur.
const SOLID = { 1: "primary", 2: "success", 3: "accent" }
const PATTERNS = { 4: "primary", 5: "success", 6: "muted" }

let sequence = 0

const text = (value) => typeof value === "string" && value.trim().length > 0
const isCategory = (value) => Number.isInteger(value) && value >= 1 && value <= MAX_CATEGORY

function read(params) {
  const layout = params.layout
  const direction = params.direction ?? "down"
  const nodes = params.nodes
  const edges = params.edges ?? []
  const legend = params.legend ?? []
  if (!LAYOUTS.includes(layout)) throw new Error("diagram : disposition inconnue")
  if (!DIRECTIONS.includes(direction)) throw new Error("diagram : direction inconnue")
  if (!Array.isArray(nodes) || nodes.length === 0 || nodes.length > MAX_NODES) throw new Error("diagram : nœuds hors limites")
  if (!Array.isArray(edges) || edges.length > MAX_EDGES) throw new Error("diagram : flèches hors limites")
  if (!Array.isArray(legend) || legend.length > MAX_LEGEND || !legend.every(text)) throw new Error("diagram : légende invalide")

  const ids = new Set()
  const cleanNodes = nodes.map((node) => {
    if (node === null || typeof node !== "object" || !text(node.id) || !text(node.label) || ids.has(node.id)) throw new Error("diagram : nœud invalide")
    if (node.category !== undefined && node.category !== null && !isCategory(node.category)) throw new Error("diagram : catégorie invalide")
    ids.add(node.id)
    return { id: node.id, label: node.label.trim().slice(0, 200), category: node.category ?? null }
  })
  const cleanEdges = edges.map((edge) => {
    if (edge === null || typeof edge !== "object" || !ids.has(edge.from) || !ids.has(edge.to) || edge.from === edge.to) throw new Error("diagram : flèche invalide")
    if (edge.label !== undefined && edge.label !== null && !text(edge.label)) throw new Error("diagram : libellé de flèche invalide")
    return { from: edge.from, to: edge.to, label: edge.label ? edge.label.trim().slice(0, 100) : "" }
  })
  if (layout === "cycle" && cleanNodes.length < 3) throw new Error("diagram : un cycle demande 3 nœuds")

  return { layout, direction, nodes: cleanNodes, edges: cleanEdges, legend: legend.map((entry) => entry.trim()) }
}

// Le texte d'un nœud : césure aux espaces, 3 lignes au plus ; au-delà, la dernière ligne finit par « … ».
function wrap(content, width) {
  const chars = Math.max(3, Math.floor((width - 2 * PAD_X) / CHAR))
  const words = content.split(/\s+/).flatMap((word) => word.match(new RegExp(`.{1,${chars}}`, "gu")) ?? [])
  const lines = []
  let current = ""
  for (const word of words) {
    if (current && `${current} ${word}`.length > chars) {
      lines.push(current)
      current = word
    } else {
      current = current ? `${current} ${word}` : word
    }
  }
  if (current) lines.push(current)
  if (lines.length <= MAX_LINES) return { lines, cut: false }

  const last = lines[MAX_LINES - 1]
  return { lines: [...lines.slice(0, MAX_LINES - 1), `${last.slice(0, chars - 1).trimEnd()}…`], cut: true }
}

// Tous les nœuds ont la même taille : largeur donnée, hauteur de la plus haute pile de lignes.
function measure(nodes, width) {
  const wrapped = new Map(nodes.map((node) => [node.id, wrap(node.label, width)]))
  const lines = Math.max(...[...wrapped.values()].map((item) => item.lines.length))
  return { wrapped, height: Math.max(36, lines * LINE + 2 * PAD_Y) }
}

const naturalWidth = (nodes) => Math.min(MAX_NODE_WIDTH, Math.max(...nodes.map((node) => node.label.length)) * CHAR + 2 * PAD_X)
const rowWidth = (count, gap, width) => count * width + (count - 1) * gap
const clampWidth = (value, ceiling) => Math.max(MIN_NODE_WIDTH, Math.min(ceiling, Math.floor(value)))

function place(boxes, node, cx, cy, width, height, info) {
  boxes.set(node.id, { node, cx, cy, w: width, h: height, ...info })
}

// flow : les nœuds se suivent dans `direction` et passent à la rangée (ou à la colonne) suivante quand la place manque.
function flow({ nodes, direction }, available) {
  const natural = naturalWidth(nodes)
  const count = nodes.length
  let columns = 1
  let width = clampWidth(natural, MAX_NODE_WIDTH)
  let sizes = measure(nodes, width)
  if (direction === "right") {
    columns = count
    while (columns > 1 && (INNER - (columns - 1) * GAP_X) / columns < Math.min(natural, 110)) columns--
  } else {
    const perColumn = Math.max(1, Math.floor((available + GAP_Y) / (sizes.height + GAP_Y)))
    columns = Math.ceil(count / perColumn)
  }
  width = clampWidth(Math.min(natural, (INNER - (columns - 1) * GAP_X) / columns), MAX_NODE_WIDTH)
  sizes = measure(nodes, width)
  const lanes = Math.ceil(count / columns)
  const boxes = new Map()
  const left = (WIDTH - rowWidth(columns, GAP_X, width)) / 2
  nodes.forEach((node, index) => {
    const [column, row] = direction === "right" ? [index % columns, Math.floor(index / columns)] : [Math.floor(index / lanes), index % lanes]
    place(boxes, node, left + column * (width + GAP_X) + width / 2, row * (sizes.height + GAP_Y) + sizes.height / 2, width, sizes.height, sizes.wrapped.get(node.id))
  })
  return { boxes, height: lanes * sizes.height + (lanes - 1) * GAP_Y }
}

// tree : une racine, un parent par nœud, aucun cycle ; les niveaux se suivent dans `direction`.
function levelsOf({ nodes, edges }) {
  const parents = new Map()
  const children = new Map(nodes.map((node) => [node.id, []]))
  for (const edge of edges) {
    if (parents.has(edge.to)) throw new Error("diagram : un nœud a deux parents")
    parents.set(edge.to, edge.from)
    children.get(edge.from).push(edge.to)
  }
  const roots = nodes.filter((node) => !parents.has(node.id))
  if (roots.length !== 1) throw new Error("diagram : un arbre a une seule racine")

  const levels = [[roots[0].id]]
  const seen = new Set([roots[0].id])
  for (let level = levels[0]; level.length > 0;) {
    const next = level.flatMap((id) => children.get(id)).filter((id) => !seen.has(id))
    next.forEach((id) => seen.add(id))
    if (next.length > 0) levels.push(next)
    level = next
  }
  if (seen.size !== nodes.length) throw new Error("diagram : cycle dans un arbre")
  return levels
}

function tree(figure, available) {
  const { nodes, direction } = figure
  const byId = new Map(nodes.map((node) => [node.id, node]))
  const levels = levelsOf(figure).map((level) => level.map((id) => byId.get(id)))
  const natural = naturalWidth(nodes)
  const boxes = new Map()

  if (direction === "right") {
    const gap = 48
    const width = clampWidth(Math.min(natural, 150, (INNER - (levels.length - 1) * gap) / levels.length), MAX_NODE_WIDTH)
    const sizes = measure(nodes, width)
    const tallest = Math.max(...levels.map((level) => level.length))
    const height = tallest * sizes.height + (tallest - 1) * 24
    levels.forEach((level, depth) => {
      const top = (height - (level.length * sizes.height + (level.length - 1) * 24)) / 2
      level.forEach((node, index) => place(boxes, node, MARGIN + depth * (width + gap) + width / 2, top + index * (sizes.height + 24) + sizes.height / 2, width, sizes.height, sizes.wrapped.get(node.id)))
    })
    return { boxes, height }
  }

  const width = clampWidth(Math.min(natural, 150), MAX_NODE_WIDTH)
  const sizes = measure(nodes, width)
  const capacity = Math.max(1, Math.floor((INNER + 24) / (width + 24)))
  let row = 0
  levels.forEach((level) => {
    const rows = Math.ceil(level.length / capacity)
    const perRow = Math.ceil(level.length / rows)
    for (let part = 0; part < rows; part++, row++) {
      const items = level.slice(part * perRow, (part + 1) * perRow)
      const left = (WIDTH - rowWidth(items.length, 24, width)) / 2
      items.forEach((node, index) => place(boxes, node, left + index * (width + 24) + width / 2, row * (sizes.height + GAP_Y) + sizes.height / 2, width, sizes.height, sizes.wrapped.get(node.id)))
    }
  })
  return { boxes, height: row * sizes.height + (row - 1) * GAP_Y }
}

const intersects = (a, b, pad = 6) => Math.abs(a.cx - b.cx) < (a.w + b.w) / 2 + pad && Math.abs(a.cy - b.cy) < (a.h + b.h) / 2 + pad

// cycle : les nœuds sur une ellipse, dans l'ordre ; la largeur diminue jusqu'à ce qu'aucune boîte ne touche sa voisine.
function cycle({ nodes }, available) {
  const natural = naturalWidth(nodes)
  const count = nodes.length
  for (let width = clampWidth(Math.min(natural, 150), MAX_NODE_WIDTH); width >= MIN_NODE_WIDTH; width -= 8) {
    const sizes = measure(nodes, width)
    const rx = Math.min(WIDTH / 2 - MARGIN - width / 2, 130 + 20 * count)
    const ry = Math.max(20, Math.min(rx * 0.8, (available - sizes.height) / 2))
    const boxes = new Map()
    nodes.forEach((node, index) => {
      const angle = -Math.PI / 2 + (index * 2 * Math.PI) / count
      place(boxes, node, WIDTH / 2 + rx * Math.cos(angle), ry + sizes.height / 2 + ry * Math.sin(angle), width, sizes.height, sizes.wrapped.get(node.id))
    })
    const list = [...boxes.values()]
    if (!list.some((box, index) => list.slice(index + 1).some((other) => intersects(box, other)))) return { boxes, height: 2 * ry + sizes.height }
  }
  throw new Error("diagram : cycle trop chargé")
}

// Le point d'un rectangle vu depuis son centre vers (x, y).
function border(box, x, y) {
  const [dx, dy] = [x - box.cx, y - box.cy]
  if (dx === 0 && dy === 0) return [box.cx, box.cy]
  const scale = Math.min(dx === 0 ? Infinity : box.w / 2 / Math.abs(dx), dy === 0 ? Infinity : box.h / 2 / Math.abs(dy))
  return [box.cx + dx * scale, box.cy + dy * scale]
}

const quadratic = (start, control, end, t) => [0, 1].map((axis) => (1 - t) ** 2 * start[axis] + 2 * (1 - t) * t * control[axis] + t ** 2 * end[axis])

// Une flèche droite si rien n'est sur son chemin, sinon la première courbe qui évite les autres nœuds.
function route(from, to, boxes, reversed, bottom) {
  const [mx, my] = [(from.cx + to.cx) / 2, (from.cy + to.cy) / 2]
  const length = Math.hypot(to.cx - from.cx, to.cy - from.cy) || 1
  const [nx, ny] = [-(to.cy - from.cy) / length, (to.cx - from.cx) / length]
  const side = from.node.id < to.node.id ? 1 : -1
  const offsets = reversed ? [30, 60, 100, -60, -100].map((value) => value * side) : [0, 45, -45, 90, -90, 140, -140]
  const others = [...boxes.values()].filter((box) => box !== from && box !== to)
  let first = null
  for (const offset of offsets) {
    const control = [mx + nx * offset * 2, my + ny * offset * 2]
    const start = border(from, ...control)
    const end = border(to, ...control)
    const path = { start, control, end, straight: offset === 0 }
    first ??= path
    const points = Array.from({ length: 19 }, (_, step) => quadratic(start, control, end, (step + 1) / 20))
    const clear = points.every(([x, y]) => x > 4 && x < WIDTH - 4 && y > -MARGIN + 4 && y < bottom && !others.some((box) => Math.abs(x - box.cx) < box.w / 2 + 4 && Math.abs(y - box.cy) < box.h / 2 + 4))
    if (clear) return path
  }
  return first
}

// Catégories : teinte pleine (1 à 3) ou motif (4 à 6), posés sur le papier. Le motif a un identifiant propre à la figure.
function paint(parent, category, geometry, key) {
  if (category === null) return null
  const attrs = { ...geometry, "data-category": category }
  if (SOLID[category]) return el("rect", { ...attrs, fill: SOLID[category], "fill-opacity": 0.35 }, parent)

  const node = el("rect", attrs, parent)
  node.style.setProperty("fill", `url(#fig-${key}-pat-${category})`)
  return node
}

function definePatterns(svg, categories, key) {
  const defs = el("defs", {}, svg)
  const attrs = (category) => ({ id: `fig-${key}-pat-${category}`, width: 8, height: 8, patternUnits: "userSpaceOnUse" })
  for (const category of [...categories].filter((value) => PATTERNS[value]).sort()) {
    const tone = PATTERNS[category]
    if (category === 4) {
      const pattern = el("pattern", { ...attrs(category), patternTransform: "rotate(45)" }, defs)
      el("line", { x1: 0, y1: 0, x2: 0, y2: 8, stroke: tone, "stroke-width": 2 }, pattern)
    } else if (category === 5) {
      const pattern = el("pattern", attrs(category), defs)
      el("circle", { cx: 4, cy: 4, r: 1.6, fill: tone }, pattern)
    } else {
      const pattern = el("pattern", { ...attrs(category), patternTransform: "rotate(45)" }, defs)
      el("line", { x1: 0, y1: 0, x2: 0, y2: 8, stroke: tone, "stroke-width": 1.5 }, pattern)
      el("line", { x1: 0, y1: 0, x2: 8, y2: 0, stroke: tone, "stroke-width": 1.5 }, pattern)
    }
  }
  const marker = el("marker", { id: `fig-${key}-arrow`, viewBox: "0 0 10 10", refX: 10, refY: 5, markerWidth: 10, markerHeight: 10, markerUnits: "userSpaceOnUse", orient: "auto" }, defs)
  el("path", { d: "M0 0 L10 5 L0 10 z", fill: "ink" }, marker)
}

export function create(canvas, params) {
  const key = `d${++sequence}`
  const state = { svg: null }

  function draw(next) {
    const figure = read(next)
    const legendHeight = figure.legend.length > 0 ? figure.legend.length * LEGEND_ROW + 12 : 0
    const available = MAX_HEIGHT - 2 * MARGIN - legendHeight
    const { boxes, height } = { flow, tree, cycle }[figure.layout](figure, available)
    if (height > available) throw new Error("diagram : schéma trop haut")
    for (const box of boxes.values()) {
      if (box.cx - box.w / 2 < 0 || box.cx + box.w / 2 > WIDTH) throw new Error("diagram : schéma trop large")
    }

    const total = Math.ceil(MARGIN + height + legendHeight + MARGIN)
    const svg = root(WIDTH, total)
    const layer = el("g", { transform: `translate(0 ${MARGIN})` }, svg)
    const categories = new Set([...figure.nodes.map((node) => node.category).filter((value) => value !== null), ...figure.legend.map((_, index) => index + 1)])
    definePatterns(svg, categories, key)
    svg.insertBefore(svg.querySelector("defs"), svg.firstChild)

    drawEdges(layer, figure, boxes, height + MARGIN)
    for (const box of boxes.values()) drawNode(layer, box)
    drawLegend(svg, figure.legend, MARGIN + height + 12)

    state.svg?.remove()
    canvas.appendChild(svg)
    state.svg = svg
  }

  function drawEdges(layer, figure, boxes, bottom) {
    const pairs = new Set(figure.edges.map((edge) => `${edge.from}>${edge.to}`))
    const labels = []
    figure.edges.forEach((edge, index) => {
      const path = route(boxes.get(edge.from), boxes.get(edge.to), boxes, pairs.has(`${edge.to}>${edge.from}`), bottom)
      const [start, control, end] = [path.start, path.control, path.end].map((point) => point.map(round))
      const d = path.straight ? `M${start[0]} ${start[1]} L${end[0]} ${end[1]}` : `M${start[0]} ${start[1]} Q${control[0]} ${control[1]} ${end[0]} ${end[1]}`
      el("path", { d, fill: "none", stroke: "ink", "stroke-width": 2.5, "marker-end": `url(#fig-${key}-arrow)`, "data-edge": index, "data-from": edge.from, "data-to": edge.to }, layer)
      if (edge.label) labels.push([quadratic(path.start, path.control, path.end, 0.5), edge.label])
    })
    for (const [[x, y], content] of labels) label(layer, x, y + 4, content, { tone: "muted", size: 12 })
  }

  function drawNode(layer, box) {
    const { node, cx, cy, w, h, lines, cut } = box
    const group = el("g", { "data-node": node.id }, layer)
    if (cut) el("title", { text: node.label }, group)
    const geometry = { x: round(cx - w / 2), y: round(cy - h / 2), width: round(w), height: round(h), rx: 8, ry: 8 }
    el("rect", { ...geometry, fill: "paper", stroke: node.category === null ? "grid" : "ink", "stroke-width": 1.5, "data-box": "" }, group)
    paint(group, node.category, geometry, key)
    const top = cy - (lines.length * LINE) / 2
    lines.forEach((line, index) => label(group, cx, top + index * LINE + LINE / 2 + 4.5, line, { tone: "ink", size: 13 }))
  }

  function drawLegend(svg, legend, top) {
    legend.forEach((entry, index) => {
      const y = top + index * LEGEND_ROW
      const row = el("g", { "data-legend": index + 1 }, svg)
      const geometry = { x: MARGIN, y: round(y), width: 26, height: 14, rx: 3, ry: 3 }
      el("rect", { ...geometry, fill: "paper", stroke: "grid", "stroke-width": 1 }, row)
      paint(row, index + 1, geometry, key)
      label(row, MARGIN + 36, y + 12, entry, { anchor: "start", tone: "ink", size: 13 })
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
