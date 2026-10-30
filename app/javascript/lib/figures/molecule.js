// ⚡ FRONT · lib/figures/molecule — une molécule : alcane (développé, semi-développé, brut) ou atomes et liaisons sur une grille
// Rôle : lit `mode` (alkane, custom), `carbons` (1 à 10), `display`, `atoms` (20 au plus), `bonds` (24 au plus) ; revérifie éléments, liaisons et valences avant de dessiner
// ADR  : 0116-fiche-de-revision-par-notion-et-figures-parametrees (§4.2) · UDR : 0141-fiche-de-revision-en-quatre-blocs (§3.3) · chargé par import() depuis controllers/figure_controller
//
// Le nom et la formule brute sont toujours écrits sous le dessin et annoncés à chaque redraw (curseur `carbons`).

import { el, root, label, round } from "./svg"

const WIDTH = 640
const HEIGHT = 320
const NAMES = ["méthane", "éthane", "propane", "butane", "pentane", "hexane", "heptane", "octane", "nonane", "décane"]
const DISPLAYS = ["developed", "semi_developed", "raw"]
const ELEMENTS = ["C", "H", "O", "N", "Cl", "Fe", "Na"]
const VALENCE = { C: 4, H: 1, O: 2, N: 3, Cl: 1 }
const MAX_ATOMS = 20
const MAX_BONDS = 24
const GRID = 12
const SUB = "₀₁₂₃₄₅₆₇₈₉"

// Entier en chiffres indices Unicode (10 → ₁₀).
const subscript = (count) => String(count).replace(/\d/g, (digit) => SUB[Number(digit)])
const formulaOf = (carbons) => `C${carbons > 1 ? subscript(carbons) : ""}H${subscript(2 * carbons + 2)}`

function read(params) {
  const { mode } = params
  if (mode === "alkane") {
    const { carbons, display } = params
    if (!Number.isInteger(carbons) || carbons < 1 || carbons > NAMES.length) throw new Error("molecule : carbons hors bornes (1 à 10)")
    if (!DISPLAYS.includes(display)) throw new Error("molecule : display inconnu")
    return { mode, carbons, display }
  }
  if (mode === "custom") return { mode, ...readGraph(params) }
  throw new Error("molecule : mode inconnu")
}

// Atomes et liaisons d'un dessin libre : éléments connus, identifiants uniques, liaisons entre atomes présents et sans doublon, valences tenues.
function readGraph({ atoms, bonds }) {
  if (!Array.isArray(atoms) || atoms.length === 0 || atoms.length > MAX_ATOMS) throw new Error("molecule : atomes absents ou trop nombreux")
  if (!Array.isArray(bonds) || bonds.length > MAX_BONDS) throw new Error("molecule : liaisons trop nombreuses")
  const byId = new Map()
  atoms.forEach((atom) => {
    const { id, element, x, y } = atom ?? {}
    if (typeof id !== "string" || id === "" || byId.has(id)) throw new Error("molecule : identifiant d'atome absent ou dupliqué")
    if (!ELEMENTS.includes(element)) throw new Error("molecule : élément inconnu")
    if (![x, y].every((value) => Number.isInteger(value) && value >= 0 && value <= GRID)) throw new Error("molecule : position hors grille")
    byId.set(id, { id, element, x, y, used: 0 })
  })
  const pairs = new Set()
  const links = bonds.map((bond) => {
    const [a, b, order] = Array.isArray(bond) ? bond : []
    if (!byId.has(a) || !byId.has(b) || a === b) throw new Error("molecule : liaison vers un atome absent")
    const pair = JSON.stringify([a, b].sort())
    if (pairs.has(pair)) throw new Error("molecule : liaison en double entre deux atomes")
    pairs.add(pair)
    if (!Number.isInteger(order) || order < 1 || order > 3) throw new Error("molecule : ordre de liaison hors 1 à 3")
    byId.get(a).used += order
    byId.get(b).used += order
    return { from: byId.get(a), to: byId.get(b), order }
  })
  byId.forEach((atom) => {
    if (atom.element in VALENCE && atom.used > VALENCE[atom.element]) throw new Error(`molecule : valence dépassée pour ${atom.element}`)
  })
  return { atoms: [...byId.values()], links }
}

// Formule brute d'un dessin libre, à la manière de Hill : C, H, puis les autres par ordre alphabétique.
function hill(atoms) {
  const counts = {}
  atoms.forEach(({ element }) => { counts[element] = (counts[element] ?? 0) + 1 })
  const order = Object.keys(counts).sort((a, b) => rank(a) - rank(b) || a.localeCompare(b))
  return order.map((element) => element + (counts[element] > 1 ? subscript(counts[element]) : "")).join("")
}
const rank = (element) => (element === "C" ? 0 : element === "H" ? 1 : 2)

// Groupe de la chaîne semi-développée : CH₃ aux bouts, CH₂ à l'intérieur.
function semiText(carbons) {
  if (carbons === 1) return "CH₄"
  return Array.from({ length: carbons }, (_, index) => (index === 0 || index === carbons - 1 ? "CH₃" : "CH₂")).join("–")
}

export function create(canvas, params, { announce } = {}) {
  const state = { svg: null }

  // Une liaison : 1 à 3 traits parallèles, raccourcie aux deux bouts pour laisser la place aux lettres.
  function bond(svg, p, q, order, gap = 11) {
    const length = Math.hypot(q.x - p.x, q.y - p.y) || 1
    const [ux, uy] = [(q.x - p.x) / length, (q.y - p.y) / length]
    const [nx, ny] = [-uy, ux]
    const group = el("g", { "data-bond": order }, svg)
    for (let index = 0; index < order; index++) {
      const shift = (index - (order - 1) / 2) * 7
      el("line", {
        x1: round(p.x + ux * gap + nx * shift), y1: round(p.y + uy * gap + ny * shift),
        x2: round(q.x - ux * gap + nx * shift), y2: round(q.y - uy * gap + ny * shift),
        stroke: "ink", "stroke-width": 2.5, "stroke-linecap": "round"
      }, group)
    }
  }

  function atom(svg, point, element) {
    const node = label(svg, point.x, point.y + 6, element, { tone: "ink", size: 18 })
    node.setAttribute("data-atom", element)
  }

  function developed(svg, carbons) {
    const step = Math.min(54, 600 / (carbons + 1))
    const y = 112
    const arm = 46
    const at = (index) => ({ x: 320 + (index - (carbons - 1) / 2) * step, y })
    const hydrogens = (from, dx, dy) => {
      const h = { x: from.x + dx, y: from.y + dy }
      bond(svg, from, h, 1)
      atom(svg, h, "H")
    }
    for (let index = 0; index < carbons; index++) {
      const c = at(index)
      if (index > 0) bond(svg, at(index - 1), c, 1)
      atom(svg, c, "C")
      if (carbons === 1) continue
      hydrogens(c, 0, -arm)
      hydrogens(c, 0, arm)
      if (index === 0) hydrogens(c, -step, 0)
      if (index === carbons - 1) hydrogens(c, step, 0)
    }
    if (carbons === 1) {
      const c = at(0)
      hydrogens(c, 0, -arm)
      hydrogens(c, 0, arm)
      hydrogens(c, -step, 0)
      hydrogens(c, step, 0)
    }
  }

  function drawAlkane(svg, { carbons, display }) {
    const name = NAMES[carbons - 1]
    const formula = formulaOf(carbons)
    if (display === "developed") developed(svg, carbons)
    else {
      const text = display === "raw" ? formula : semiText(carbons)
      const size = display === "raw" ? 64 : Math.min(30, 600 / (text.length * 0.7))
      label(svg, WIDTH / 2, 130, text, { tone: "ink", size })
    }
    label(svg, WIDTH / 2, 232, name, { tone: "primary", size: 22 }).setAttribute("data-name", name)
    label(svg, WIDTH / 2, 272, formula, { tone: "ink", size: 22 }).setAttribute("data-formula", formula)
    return `${name}, ${formula}`
  }

  function drawCustom(svg, { atoms, links }) {
    const at = (a) => ({ x: round(56 + a.x * 44), y: round(24 + a.y * 19) })
    links.forEach(({ from, to, order }) => bond(svg, at(from), at(to), order, 10))
    atoms.forEach((a) => atom(svg, at(a), a.element))
    const formula = hill(atoms)
    label(svg, WIDTH / 2, 302, formula, { tone: "ink", size: 22 }).setAttribute("data-formula", formula)
    return formula
  }

  function draw(next) {
    const data = read(next)
    const svg = root(WIDTH, HEIGHT)
    const spoken = data.mode === "alkane" ? drawAlkane(svg, data) : drawCustom(svg, data)
    state.svg?.remove()
    canvas.appendChild(svg)
    state.svg = svg
    return spoken
  }

  draw(params)
  return {
    interactive: false,
    // Le contrôleur garde ce texte et l'annonce au relâchement du curseur, à la place du libellé.
    redraw(next) {
      announce?.(draw(next))
    },
    destroy() {
      state.svg?.remove()
    }
  }
}
