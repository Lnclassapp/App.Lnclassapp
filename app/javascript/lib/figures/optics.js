// ⚡ FRONT · lib/figures/optics — le tracé d'une lentille mince (image calculée) ou d'un œil réduit avec sa lentille correctrice
// Rôle : lit `mode` (lens, eye), `lens`, `focal`, `object_distance`, `object_height`, `defect`, `correction` ; revérifie bornes et listes fermées avant de dessiner
// ADR  : XXXX-figures-des-matieres-de-3eme (§4.2) · UDR : XXXX-figures-des-matieres-de-3eme (§3) · chargé par import() depuis controllers/figure_controller
//
// Lentille : OA = −object_distance, f' = ±focal, 1/OA' = 1/f' + 1/OA, γ = OA'/OA. Le dessin n'a pas la même échelle en long et en haut (comme
// sur un schéma de cours) : les droites restent des droites, donc les trois rayons particuliers se coupent bien à l'image calculée.

import { el, root, label, fixed, round } from "./svg"

const WIDTH = 640
const HEIGHT = 320
const MODES = ["lens", "eye"]
const LENSES = ["convergent", "divergent"]
const DEFECTS = ["none", "myopia", "hyperopia"]
const CORRECTIONS = ["none", "convergent", "divergent"]
const BOUNDS = { focal: [0.5, 20], object_distance: [0.5, 60], object_height: [0.5, 10] }
const INFINITE = 1e-9
const RAY_WIDTH = 2.5
const DASH = "6 5"

// Lentille : l'axe est à AXIS_Y, la lentille au milieu du dessin ; les mesures sont écrites sous le dessin (zone de dessin : 0 à DRAW_HEIGHT).
const CENTER_X = 320
const AXIS_Y = 125
const DRAW_HEIGHT = 245
const LENS_HALF = 105
const SPAN_X = 285
const SPAN_Y = 90

// Œil : cristallin et rétine à distance fixe ; la puissance relative vaut 1 pour un œil normal.
const EYE_CENTER = { x: 380, y: AXIS_Y }
const EYE_RADIUS = 90
const CRYSTALLINE_X = 335
const RETINA_X = EYE_CENTER.x + EYE_RADIUS
const CORRECTION_X = 235
const RAY_OFFSETS = [-24, 0, 24]
const EYE_POWER = { none: 1, myopia: 1.4, hyperopia: 0.6 }
const CORRECTION_POWER = { none: 0, convergent: 0.4, divergent: -0.4 }
const MIN_POWER = 0.15
const EYE_NAME = { none: "normal", myopia: "myope", hyperopia: "hypermétrope" }

let serial = 0

const finite = (value) => typeof value === "number" && Number.isFinite(value)

// Les paramètres revérifiés, ou une erreur : le contrôleur montre alors la description seule.
function read(params) {
  const { mode } = params
  if (!MODES.includes(mode)) throw new Error("optics : mode inconnu")
  const correction = params.correction ?? "none"
  if (!CORRECTIONS.includes(correction)) throw new Error("optics : correction inconnue")

  if (mode === "eye") {
    if (!DEFECTS.includes(params.defect)) throw new Error("optics : défaut de l'œil inconnu")
    return { mode, defect: params.defect, correction }
  }

  if (!LENSES.includes(params.lens)) throw new Error("optics : sorte de lentille inconnue")
  if (correction !== "none") throw new Error("optics : une correction n'existe qu'en mode œil")
  Object.entries(BOUNDS).forEach(([name, [min, max]]) => {
    if (!finite(params[name]) || params[name] < min || params[name] > max) throw new Error(`optics : ${name} manquant ou hors bornes`)
  })
  return { mode, lens: params.lens, focal: params.focal, distance: params.object_distance, height: params.object_height }
}

// L'image donnée par la lentille mince ; `oa` est null si elle est à l'infini.
function image({ lens, focal, distance, height }) {
  const fPrime = lens === "convergent" ? focal : -focal
  const vergence = 1 / fPrime - 1 / distance
  if (Math.abs(vergence) < INFINITE) return { fPrime, oa: null, gamma: null, height: null }

  const oa = 1 / vergence
  const gamma = oa / -distance
  return { fPrime, oa, gamma, height: gamma * height }
}

function nature(oa, gamma) {
  if (oa === null) return "image à l'infini"
  const size = Math.abs(Math.abs(gamma) - 1) < INFINITE ? "de même taille" : Math.abs(gamma) > 1 ? "agrandie" : "réduite"
  return `${oa > 0 ? "réelle" : "virtuelle"}, ${gamma < 0 ? "renversée" : "droite"}, ${size}`
}

export function create(canvas, params, { announce = () => {} } = {}) {
  const state = { svg: null }

  function draw(next) {
    const dims = read(next)
    const svg = root(WIDTH, HEIGHT)
    const id = `fig-optics-${++serial}`
    const defs = el("defs", {}, svg)
    el("rect", { x: 0, y: 0, width: WIDTH, height: DRAW_HEIGHT }, el("clipPath", { id: `${id}-clip` }, defs))
    const line = dims.mode === "lens" ? drawLens(svg, defs, id, dims) : drawEye(svg, dims)
    state.svg?.remove()
    canvas.appendChild(svg)
    state.svg = svg
    announce(line)
  }

  // Une pointe de flèche par couleur, à l'identifiant unique par figure.
  function arrow(defs, id, tone) {
    const marker = el("marker", { id: `${id}-arrow-${tone}`, markerWidth: 9, markerHeight: 9, refX: 8, refY: 4.5, orient: "auto", markerUnits: "userSpaceOnUse" }, defs)
    el("path", { d: "M0 0 L9 4.5 L0 9 z", fill: tone }, marker)
    return `url(#${id}-arrow-${tone})`
  }

  // Une lentille : un trait vertical et deux pointes, vers l'extérieur (convergente) ou l'intérieur (divergente).
  function lensShape(svg, x, half, converging, attrs = {}) {
    const group = el("g", attrs, svg)
    el("line", { x1: x, y1: AXIS_Y - half, x2: x, y2: AXIS_Y + half, stroke: "ink", "stroke-width": RAY_WIDTH, "stroke-linecap": "round" }, group)
    ;[-1, 1].forEach((side) => {
      const tip = AXIS_Y + side * half
      const base = converging ? tip - side * 12 : tip + side * 12
      el("path", { d: `M${x - 8} ${base} L${x} ${tip} L${x + 8} ${base}`, fill: "none", stroke: "ink", "stroke-width": RAY_WIDTH, "stroke-linecap": "round", "stroke-linejoin": "round" }, group)
    })
    return group
  }

  function drawLens(svg, defs, id, dims) {
    const { fPrime, oa, gamma, height: imageHeight } = image(dims)
    const { focal, distance, height } = dims
    const reach = Math.max(distance, focal, oa === null ? 0 : Math.min(Math.abs(oa), 2 * Math.max(distance, focal)))
    const sx = SPAN_X / reach
    const tallest = Math.max(height, imageHeight === null ? 0 : Math.min(Math.abs(imageHeight), 2 * height))
    const sy = Math.min(sx, SPAN_Y / tallest)
    const X = (x) => round(CENTER_X + x * sx)
    const Y = (y) => round(AXIS_Y - y * sy)
    const far = (WIDTH - CENTER_X) / sx
    const virtual = oa !== null && oa < 0

    el("line", { x1: 0, y1: AXIS_Y, x2: WIDTH, y2: AXIS_Y, stroke: "grid", "stroke-width": 1.5, "stroke-dasharray": DASH, "data-axis": "" }, svg)
    lensShape(svg, CENTER_X, LENS_HALF, dims.lens === "convergent", { "data-lens": dims.lens })
    label(svg, CENTER_X + 12, AXIS_Y + 18, "O", { anchor: "start", tone: "muted" })

    // F est le foyer objet (−f'), F' le foyer image (f').
    ;[["F", -fPrime], ["F'", fPrime]].forEach(([name, x]) => {
      const group = el("g", { "data-focus": name }, svg)
      el("circle", { cx: X(x), cy: AXIS_Y, r: 3.5, fill: "ink" }, group)
      label(group, X(x), AXIS_Y + 20, name, { tone: "muted" })
    })

    const rays = el("g", { "data-rays": "", "clip-path": `url(#${id}-clip)` }, svg)
    const segment = (parent, [x1, y1], [x2, y2], dashed = false) => el("line", { x1: X(x1), y1: Y(y1), x2: X(x2), y2: Y(y2), stroke: "accent", "stroke-width": RAY_WIDTH, "stroke-linecap": "round", ...(dashed ? { "stroke-dasharray": DASH } : {}) }, parent)
    const top = [-distance, height]
    const grazing = Math.abs(fPrime - distance) < INFINITE
    const hit = grazing ? null : (height * fPrime) / (fPrime - distance)
    // Les trois rayons particuliers : par le centre ; parallèle puis par F' ; par F puis parallèle (au foyer, il reste vertical).
    const paths = [
      { incident: [0, 0], emergent: [[0, 0], [far, (-height * far) / distance]] },
      { incident: [0, height], emergent: [[0, height], [far, height * (1 - far / fPrime)]], backFrom: [0, height] },
      { incident: grazing ? [-distance, 0] : [0, hit], emergent: grazing ? null : [[0, hit], [far, hit]], backFrom: grazing ? null : [0, hit] }
    ]
    paths.forEach(({ incident, emergent, backFrom }, index) => {
      const group = el("g", { "data-ray": index + 1 }, rays)
      segment(group, top, incident)
      if (emergent) segment(group, ...emergent)
      if (virtual && backFrom) segment(group, backFrom, [oa, imageHeight], true)
    })

    const object = el("g", { "data-object": "" }, svg)
    el("line", { x1: X(-distance), y1: AXIS_Y, x2: X(-distance), y2: Y(height), stroke: "primary", "stroke-width": RAY_WIDTH, "marker-end": arrow(defs, id, "primary") }, object)
    label(object, X(-distance), Y(height) - 8, "B", { tone: "primary" })

    if (oa !== null) {
      const group = el("g", { "data-image": "", ...(virtual ? { "data-virtual": "" } : {}) }, svg)
      el("line", { x1: X(oa), y1: AXIS_Y, x2: X(oa), y2: Y(imageHeight), stroke: "success", "stroke-width": RAY_WIDTH, "marker-end": arrow(defs, id, "success"), "data-shaft": "", ...(virtual ? { "stroke-dasharray": DASH } : {}) }, group)
      label(group, X(oa), Y(imageHeight) + (imageHeight < 0 ? 18 : -8), "B'", { tone: "success" })
    }

    const texts = oa === null
      ? [["nature", nature(null)]]
      : [["oa", `OA' = ${fixed(oa)} cm`], ["gamma", `γ = ${fixed(gamma)}`], ["nature", nature(oa, gamma)]]
    texts.forEach(([name, text], index) => {
      label(svg, 12, 266 + index * 24, text, { anchor: "start", tone: name === "nature" ? "success" : "ink", size: 14 }).setAttribute("data-measure", name)
    })
    return texts.map(([, text]) => text).join(", ")
  }

  // L'œil : un faisceau parallèle traverse l'éventuelle lentille correctrice puis le cristallin et converge (avant, sur ou après la rétine).
  function drawEye(svg, { defect, correction }) {
    const power = Math.max(EYE_POWER[defect] + CORRECTION_POWER[correction], MIN_POWER)
    const retinaDistance = RETINA_X - CRYSTALLINE_X
    const converge = CRYSTALLINE_X + retinaDistance / power
    const place = Math.abs(power - 1) < INFINITE ? "on" : power > 1 ? "before" : "after"
    svg.setAttribute("data-convergence", place)

    el("line", { x1: 0, y1: AXIS_Y, x2: WIDTH, y2: AXIS_Y, stroke: "grid", "stroke-width": 1, "stroke-dasharray": DASH }, svg)
    el("circle", { cx: EYE_CENTER.x, cy: EYE_CENTER.y, r: EYE_RADIUS, fill: "none", stroke: "grid", "stroke-width": 1.5, "data-eyeball": "" }, svg)
    const [reachX, reachY] = [EYE_CENTER.x + EYE_RADIUS * Math.cos(Math.PI / 3), EYE_RADIUS * Math.sin(Math.PI / 3)]
    el("path", { d: `M${round(reachX)} ${round(AXIS_Y - reachY)} A${EYE_RADIUS} ${EYE_RADIUS} 0 0 1 ${round(reachX)} ${round(AXIS_Y + reachY)}`, fill: "none", stroke: "ink", "stroke-width": 4, "stroke-linecap": "round", "data-retina": "" }, svg)
    lensShape(svg, CRYSTALLINE_X, 34, true, { "data-crystalline": "" })
    label(svg, CRYSTALLINE_X, AXIS_Y + 56, "cristallin", { tone: "muted" })
    label(svg, RETINA_X - 6, AXIS_Y + 82, "rétine", { tone: "muted" })
    if (correction !== "none") {
      lensShape(svg, CORRECTION_X, 52, correction === "convergent", { "data-correction": correction })
      label(svg, CORRECTION_X, AXIS_Y + 76, "lentille", { tone: "muted" })
    }

    const gap = CRYSTALLINE_X - CORRECTION_X
    RAY_OFFSETS.forEach((offset, index) => {
      const atLens = offset * (1 - (CORRECTION_POWER[correction] / retinaDistance) * gap)
      const slope = -atLens / (converge - CRYSTALLINE_X)
      const at = (x) => atLens + slope * (x - CRYSTALLINE_X)
      const group = el("g", { "data-ray": index + 1 }, svg)
      const path = (points, attrs) => el("polyline", { points: points.map(([x, y]) => `${round(x)},${round(AXIS_Y - y)}`).join(" "), fill: "none", stroke: "accent", "stroke-width": RAY_WIDTH, "stroke-linejoin": "round", ...attrs }, group)
      path([[0, offset], [CORRECTION_X, offset], [CRYSTALLINE_X, atLens], [RETINA_X, at(RETINA_X)]])
      if (place === "after") path([[RETINA_X, at(RETINA_X)], [Math.min(converge, WIDTH - 12), at(Math.min(converge, WIDTH - 12))]], { "stroke-dasharray": DASH })
    })
    if (converge < WIDTH - 12) el("circle", { cx: round(converge), cy: AXIS_Y, r: 4.5, fill: "success", "data-convergence-point": "" }, svg)

    const where = { before: "avant", on: "sur", after: "après" }[place]
    const who = correction === "none" ? `œil ${EYE_NAME[defect]}` : `œil ${EYE_NAME[defect]}, lentille ${correction === "convergent" ? "convergente" : "divergente"}`
    const text = `L'image se forme ${where} la rétine : ${who}`
    label(svg, 12, 280, text, { anchor: "start", size: 14 }).setAttribute("data-measure", "convergence")
    return text
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
