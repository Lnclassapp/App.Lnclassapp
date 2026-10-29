// ⚡ FRONT · lib/figures/solid — la pyramide ou le cône en perspective cavalière, arêtes cachées en pointillés, volume recalculé en direct
// Rôle : lit `shape` (pyramid, cone), `base` (square, rectangular, triangular), `height`, `side`, `width`, `depth`, `radius` ; revérifie les dimensions (0,5 à 50) avant de dessiner
// ADR  : XXXX-fiche-de-revision-par-notion-et-figures-parametrees (§4.2) · UDR : XXXX-fiche-de-revision-en-quatre-blocs (§3.3) · chargé par import() depuis controllers/figure_controller
//
// Perspective cavalière : la face avant est en vraie grandeur ; la profondeur fuit vers le haut et la droite, à 45 °, réduite de moitié.

import { el, root, label, fixed, round } from "./svg"

const WIDTH = 440
const HEIGHT = 320
const PAD = 36
const SLOPE = 0.5 * Math.SQRT1_2
const BASES = ["square", "rectangular", "triangular"]
const MIN = 0.5
const MAX = 50

const finite = (value) => typeof value === "number" && Number.isFinite(value)

// Les dimensions utiles à la forme demandée, ou une erreur : le contrôleur montre alors la description seule.
function read(params) {
  const { shape, base } = params
  const needs = shape === "cone" ? ["radius", "height"]
    : shape === "pyramid" && base === "rectangular" ? ["width", "depth", "height"]
    : shape === "pyramid" && BASES.includes(base) ? ["side", "height"]
    : null
  if (!needs) throw new Error("solid : forme ou base inconnue")
  if (!needs.every((name) => finite(params[name]) && params[name] >= MIN && params[name] <= MAX)) throw new Error("solid : dimension manquante ou hors bornes")

  return { shape, base, ...Object.fromEntries(needs.map((name) => [name, params[name]])) }
}

// Sommets d'une pyramide : 0 avant gauche, 1 avant droit, puis l'arrière, "a" le sommet. Faces visibles : l'avant (0, 1, a) et la droite (1, 2, a).
const VISIBLE_FACES = [[0, 1, "a"], [1, 2, "a"]]
const isHidden = (a, b) => !VISIBLE_FACES.some((face) => face.includes(a) && face.includes(b))

export function create(canvas, params) {
  const state = { svg: null }

  function draw(next) {
    const dims = read(next)
    const svg = root(WIDTH, HEIGHT)
    const volume = dims.shape === "cone" ? drawCone(svg, dims) : drawPyramid(svg, dims)
    label(svg, 10, 22, `V ≈ ${fixed(volume, 1)}`, { anchor: "start", tone: "primary", size: 14 })
    state.svg?.remove()
    canvas.appendChild(svg)
    state.svg = svg
  }

  // Un cadrage commun : le solide tient dans la zone sous la mesure, centré, à l'échelle la plus grande qui convient.
  function fit(points) {
    const xs = points.map((p) => p.x)
    const ys = points.map((p) => p.y)
    const [minX, maxX, minY, maxY] = [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys)]
    const scale = Math.min((WIDTH - 2 * PAD) / (maxX - minX), (HEIGHT - 2 * PAD - 20) / (maxY - minY))
    const [dx, dy] = [(WIDTH - (maxX - minX) * scale) / 2, 20 + (HEIGHT - 20 - (maxY - minY) * scale) / 2]
    return (p) => ({ x: round(dx + (p.x - minX) * scale), y: round(HEIGHT - dy - (p.y - minY) * scale), scale })
  }

  function drawPyramid(svg, { base, side, width, depth, height }) {
    const [w, d] = base === "rectangular" ? [width, depth] : base === "triangular" ? [side, side * Math.sqrt(3) / 2] : [side, side]
    const project = (x, z, y) => ({ x: x + y * SLOPE, y: z + y * SLOPE })
    const ground = base === "triangular" ? [[0, 0], [w, 0], [w / 2, d]] : [[0, 0], [w, 0], [w, d], [0, d]]
    const centre = base === "triangular" ? [w / 2, d / 3] : [w / 2, d / 2]
    const corners = ground.map(([x, y]) => project(x, 0, y))
    const apex = project(centre[0], height, centre[1])
    const plan = [...corners, apex]
    const at = fit(plan)
    const edges = []
    corners.forEach((_, index) => edges.push([index, (index + 1) % corners.length]))
    corners.forEach((_, index) => edges.push([index, "a"]))
    edges.forEach(([a, b]) => {
      const [p, q] = [a === "a" ? at(apex) : at(corners[a]), b === "a" ? at(apex) : at(corners[b])]
      const dashed = isHidden(a, b)
      el("line", { x1: p.x, y1: p.y, x2: q.x, y2: q.y, stroke: "ink", "stroke-width": 2, "stroke-linecap": "round", "stroke-dasharray": dashed ? "6 5" : "0", "data-edge": dashed ? "hidden" : "visible" }, svg)
    })
    const front = [at(corners[0]), at(corners[1])]
    label(svg, (front[0].x + front[1].x) / 2, front[0].y + 20, `${base === "rectangular" ? "l" : "c"} = ${fixed(w)}`, { tone: "muted", size: 12 })
    const foot = at({ x: centre[0] + centre[1] * SLOPE, y: centre[1] * SLOPE })
    el("line", { x1: foot.x, y1: foot.y, x2: at(apex).x, y2: at(apex).y, stroke: "accent", "stroke-width": 1.5, "stroke-dasharray": "3 4", "data-height": "" }, svg)
    label(svg, at(apex).x - 8, (foot.y + at(apex).y) / 2, `h = ${fixed(height)}`, { anchor: "end", tone: "accent", size: 13 })
    const area = base === "triangular" ? (w * d) / 2 : w * d
    return (area * height) / 3
  }

  // Un cône : l'ellipse de base (demi-arrière en pointillé) et les deux génératrices tangentes à l'ellipse.
  function drawCone(svg, { radius, height }) {
    const minor = radius / 2
    const reach = height > minor ? radius * Math.sqrt(1 - (minor / height) ** 2) : radius
    const touch = height > minor ? (minor * minor) / height : 0
    const at = fit([{ x: -radius, y: -minor }, { x: radius, y: minor }, { x: 0, y: height }])
    const c = at({ x: 0, y: 0 })
    const apex = at({ x: 0, y: height })
    const [rx, ry] = [round(radius * c.scale), round(minor * c.scale)]
    const left = at({ x: -reach, y: touch })
    const right = at({ x: reach, y: touch })
    const arc = (sweep, hiddenArc) => el("path", { d: `M${round(c.x - rx)} ${c.y} A${rx} ${ry} 0 0 ${sweep} ${round(c.x + rx)} ${c.y}`, fill: "none", stroke: "ink", "stroke-width": 2, "stroke-dasharray": hiddenArc ? "6 5" : "0", "data-edge": hiddenArc ? "hidden" : "visible" }, svg)
    arc(1, true)
    arc(0, false)
    ;[left, right].forEach((p) => el("line", { x1: apex.x, y1: apex.y, x2: p.x, y2: p.y, stroke: "ink", "stroke-width": 2, "stroke-linecap": "round", "data-edge": "visible" }, svg))
    el("line", { x1: c.x, y1: c.y, x2: apex.x, y2: apex.y, stroke: "accent", "stroke-width": 1.5, "stroke-dasharray": "3 4", "data-height": "" }, svg)
    el("line", { x1: c.x, y1: c.y, x2: round(c.x + rx), y2: c.y, stroke: "accent", "stroke-width": 1.5, "stroke-dasharray": "3 4" }, svg)
    label(svg, c.x + 8, (c.y + apex.y) / 2, `h = ${fixed(height)}`, { anchor: "start", tone: "accent", size: 13 })
    label(svg, c.x + rx / 2, c.y - 6, `r = ${fixed(radius)}`, { tone: "accent", size: 13 })
    return (Math.PI * radius * radius * height) / 3
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
