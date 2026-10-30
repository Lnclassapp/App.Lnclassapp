// ⚡ FRONT · lib/figures/plate — la planche légendée : un dessin fixe de manuel, des étiquettes à gauche et à droite reliées à leur partie, le surlignage
// Rôle : lit `plate`, `labels` (≤ 12), `highlight` (≤ 4), `numbering` (names, numbers) ; revérifie la planche et les parties avant de dessiner ; le tracé vient de plates/<planche>.js
// ADR  : XXXX-figures-des-matieres-de-3eme (§4.2 plate) · UDR : XXXX-figures-des-matieres-de-3eme (§3 plate) · chargé par import() depuis controllers/figure_controller
//
// Le dessin occupe la zone centrale (x 170 à 470) ; les étiquettes se rangent dans les marges, du côté de l'ancre de leur partie, sans se chevaucher.

import { el, root, label, round, clamp } from "./svg"
import { PLATES } from "./plates/index"

const WIDTH = 640
const HEIGHT = 480
const CENTRE = WIDTH / 2
const LEFT_EDGE = 160
const RIGHT_EDGE = 480
const TOP = 34
const BOTTOM = HEIGHT - 8
const MIN_GAP = 26
const LINE = 18
const WRAP = 16
const MAX_LABELS = 12
const MAX_HIGHLIGHT = 4
const MAX_TEXT = 60
const NUMBERINGS = ["names", "numbers"]

let counter = 0

const own = (object, key) => typeof key === "string" && Object.hasOwn(object, key)

// Les paramètres lus et vérifiés, ou une erreur : le contrôleur montre alors la description seule.
function read(params) {
  const { plate, labels = [], highlight = [], numbering = "names" } = params ?? {}
  if (!own(PLATES, plate)) throw new Error("plate : planche inconnue")
  if (!NUMBERINGS.includes(numbering)) throw new Error("plate : numérotation inconnue")
  if (!Array.isArray(labels) || labels.length > MAX_LABELS) throw new Error("plate : trop d'étiquettes")
  if (!Array.isArray(highlight) || highlight.length > MAX_HIGHLIGHT) throw new Error("plate : trop de surlignages")

  const { PARTS } = PLATES[plate]
  const seen = new Set()
  labels.forEach((entry) => {
    const part = entry?.part
    if (!own(PARTS, part)) throw new Error("plate : partie inconnue")
    if (seen.has(part)) throw new Error("plate : partie en double")
    if (entry.text !== undefined && (typeof entry.text !== "string" || entry.text.length > MAX_TEXT)) throw new Error("plate : texte d'étiquette invalide")
    seen.add(part)
  })
  highlight.forEach((part) => {
    if (!own(PARTS, part)) throw new Error("plate : partie surlignée inconnue")
  })
  if (new Set(highlight).size !== highlight.length) throw new Error("plate : surlignage en double")

  return { plate, labels, highlight, numbering }
}

// Coupe un texte aux espaces et après les traits d'union en lignes d'au plus WRAP signes (un mot plus long reste entier).
function wrap(text) {
  const lines = []
  text.split(/\s+/).filter(Boolean).flatMap((word) => word.split(/(?<=-)/)).forEach((piece) => {
    const last = lines[lines.length - 1]
    const glue = last?.endsWith("-") ? "" : " "
    if (last !== undefined && `${last}${glue}${piece}`.length <= WRAP) lines[lines.length - 1] = `${last}${glue}${piece}`
    else lines.push(piece)
  })
  return lines.length ? lines : [""]
}

// Répartit les étiquettes d'un côté : triées par ordonnée d'ancre, au moins MIN_GAP entre deux centres, dans le cadre.
function stack(items) {
  const sorted = [...items].sort((a, b) => a.anchor[1] - b.anchor[1])
  let previous = null
  sorted.forEach((item) => {
    const wanted = previous ? previous.y + Math.max(MIN_GAP, (previous.height + item.height) / 2 + 4) : TOP + item.height / 2
    item.y = Math.max(item.anchor[1], wanted)
    previous = item
  })
  let next = null
  ;[...sorted].reverse().forEach((item) => {
    const limit = next ? next.y - Math.max(MIN_GAP, (next.height + item.height) / 2 + 4) : BOTTOM - item.height / 2
    item.y = Math.min(item.y, limit)
    next = item
  })
  // Si le haut déborde après avoir remonté, on repousse vers le bas à partir du cadre (la place manque seulement au-delà de 12 étiquettes très longues).
  previous = null
  sorted.forEach((item) => {
    const floor = previous ? previous.y + Math.max(MIN_GAP, (previous.height + item.height) / 2 + 4) : TOP + item.height / 2
    item.y = Math.max(item.y, floor)
    previous = item
  })
  return sorted
}

const total = (items) => items.reduce((sum, item) => sum + Math.max(MIN_GAP, item.height + 4), 0)

// Une étiquette à gauche si l'ancre est à gauche du centre ; si un côté est plein, la plus proche du centre passe de l'autre côté.
function split(items) {
  const left = items.filter((item) => item.anchor[0] < CENTRE)
  const right = items.filter((item) => item.anchor[0] >= CENTRE)
  const room = BOTTOM - TOP
  while (total(left) > room && left.length) right.push(left.splice(left.indexOf(left.reduce((a, b) => (a.anchor[0] > b.anchor[0] ? a : b))), 1)[0])
  while (total(right) > room && right.length) left.push(right.splice(right.indexOf(right.reduce((a, b) => (a.anchor[0] < b.anchor[0] ? a : b))), 1)[0])
  return { left, right }
}

export function create(canvas, params) {
  const state = { svg: null }

  function draw(next) {
    const { plate, labels, highlight, numbering } = read(next)
    const module = PLATES[plate]
    const svg = root(WIDTH, HEIGHT)
    const highlighted = new Set(highlight)
    counter += 1
    const prefix = `plate-${counter}`

    label(svg, 10, 20, module.TITLE, { anchor: "start", tone: "muted", size: 12 })
    const group = el("g", { "data-plate": plate }, svg)
    module.draw(group, context(group, highlighted, prefix))

    const items = labels.map(({ part, text }, index) => {
      const lines = numbering === "numbers" ? [String(index + 1)] : wrap(text ?? module.PARTS[part].name)
      return { part, lines, height: lines.length * LINE, anchor: module.PARTS[part].anchor, y: 0 }
    })
    const { left, right } = split(items)
    stack(left).forEach((item) => legend(svg, item, "left", numbering))
    stack(right).forEach((item) => legend(svg, item, "right", numbering))

    state.svg?.remove()
    canvas.appendChild(svg)
    state.svg = svg
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

// Une étiquette : son texte dans la marge, un trait de rappel jusqu'à la partie et un point sur l'ancre.
function legend(svg, item, side, numbering) {
  const group = el("g", { "data-label": item.part }, svg)
  const [ax, ay] = item.anchor
  const edge = side === "left" ? LEFT_EDGE + 3 : RIGHT_EDGE - 3
  el("line", { x1: round(edge), y1: round(item.y), x2: ax, y2: ay, stroke: "ink", "stroke-width": 1, "stroke-linecap": "round" }, group)
  el("circle", { cx: ax, cy: ay, r: 2.5, fill: "ink", stroke: "none" }, group)
  const x = side === "left" ? LEFT_EDGE - 2 : RIGHT_EDGE + 2
  const size = numbering === "numbers" ? 15 : 13
  const top = item.y - item.height / 2
  item.lines.forEach((line, index) => {
    label(group, x, top + index * LINE + LINE * 0.72, line, { anchor: side === "left" ? "end" : "start", size })
  })
}

// Ce que chaque planche reçoit pour tracer : les parties surlignées, `el`, des identifiants uniques et deux aides de tracé.
function context(group, highlighted, prefix) {
  const defs = el("defs", {}, group)
  const uid = (name) => `${prefix}-${name}`

  // Un motif de remplissage (hachures, points…) : `build(pattern)` y dessine ; renvoie la référence à passer à `texture`.
  const pattern = (name, size, build) => {
    const node = el("pattern", { id: uid(name), width: size, height: size, patternUnits: "userSpaceOnUse" }, defs)
    build(node)
    return uid(name)
  }

  // Un trait de décor (ni partie, ni surlignable) : ink 1,5, sans remplissage sauf demande.
  const sketch = (tag, attrs = {}, parent = group) => el(tag, { fill: "none", stroke: "ink", "stroke-width": 1.5, "stroke-linecap": "round", "stroke-linejoin": "round", ...attrs }, parent)

  // Une forme d'une partie : data-part ; surlignée, remplie primary à 0,35 avec un contour épaissi (≥ 3) et marquée data-highlight.
  // `fill: "ghost"` : une zone qui ne fait que se superposer à un dessin déjà tracé (contour fin, sans remplissage) ; surlignée, elle se remplit comme les autres.
  const part = (id, tag, attrs = {}, parent = group) => {
    const { fill: wanted = "paper", stroke = "ink", texture = null, "stroke-width": width = 1.5, ...rest } = attrs
    const ghost = wanted === "ghost"
    const fill = ghost ? "none" : wanted
    const open = fill === "none" && !texture && !ghost
    const base = { "stroke-linecap": "round", "stroke-linejoin": "round", ...rest }
    const paint = (node, tex) => {
      if (tex) node.style.setProperty("fill", `url(#${tex})`)
      return node
    }
    if (!highlighted.has(id)) return paint(el(tag, { ...base, "data-part": id, fill, stroke, "stroke-width": width }, parent), texture)
    if (!open && !ghost) paint(el(tag, { ...base, fill, stroke: "none" }, parent), texture)
    return el(tag, {
      ...base, "data-part": id, "data-highlight": "", fill: open ? "none" : "primary", "fill-opacity": 0.35,
      stroke: open ? "primary" : stroke, "stroke-width": clamp(width + 1.5, 3, 5)
    }, parent)
  }

  // Un tube (intestin, vaisseau) : un trait épais bordé d'encre, creux ; surligné, le creux se teinte primary à 0,35 et la bordure s'épaissit.
  const tube = (id, d, width = 8, { cap = "round", parent = group } = {}) => {
    const on = highlighted.has(id)
    const round = { fill: "none", "stroke-linecap": cap, "stroke-linejoin": "round" }
    const outline = el("path", { ...round, d, stroke: "ink", "stroke-width": width + (on ? 6 : 3), "data-part": id, ...(on ? { "data-highlight": "" } : {}) }, parent)
    el("path", { ...round, d, stroke: "paper", "stroke-width": width }, parent)
    if (on) el("path", { ...round, d, stroke: "primary", "stroke-opacity": 0.35, "stroke-width": width }, parent)
    return outline
  }

  return { highlighted, el, uid, defs, pattern, sketch, part, tube, label }
}
