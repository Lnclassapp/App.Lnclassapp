// ⚡ FRONT · course_sheet/thales_figure_controller — la figure interactive de Thalès : A, B, C, M et N se déplacent à la souris, au doigt ou au clavier
// Rôle : M et N glissent sur [AB) et [AC) (ou suivent l'un l'autre si (MN) // (BC) est imposé), les mesures, les rapports et la conclusion se recalculent
// ADR  : 0110-fiche-de-cours-en-donnees-importees (chantier contenu-en-blocs) · formules de la maquette Fiche Thales.dc.html (renderVals) ; sans JavaScript, le serveur dessine la position de départ

import { Controller } from "@hotwired/stimulus"

const WIDTH = 440
const BOUNDS = { minX: 12, maxX: 428, minY: 12, maxY: 308 }
const K_RANGE = { min: -1.2, max: 1.5, floor: 0.12 }
const SNAP = 0.025
const HIT_RADIUS = 17
const HIT_SCREEN = 22
const STEP = 8
const K_STEP = 0.02
const SCALE = 40

const lerp = (p, q, k) => ({ x: p.x + k * (q.x - p.x), y: p.y + k * (q.y - p.y) })
const length = (p, q) => Math.hypot(p.x - q.x, p.y - q.y)
const clamp = (value, min, max) => Math.max(min, Math.min(max, value))
const fixed = (value, digits) => value.toFixed(digits).replace(".", ",")
const round = (value) => Math.round(value * 100) / 100

// La droite (P, Q) prolongée de `from` à `to` fois sa longueur.
const extend = (p, q, from, to) => ({
  x1: p.x + from * (q.x - p.x), y1: p.y + from * (q.y - p.y), x2: p.x + to * (q.x - p.x), y2: p.y + to * (q.y - p.y)
})

// Projette P sur (A, B) : le coefficient k de M = A + k·AB, borné, jamais trop près de A (sinon M se confond avec A).
function project(p, a, b) {
  const dx = b.x - a.x
  const dy = b.y - a.y
  const squared = dx * dx + dy * dy || 1
  let k = clamp(((p.x - a.x) * dx + (p.y - a.y) * dy) / squared, K_RANGE.min, K_RANGE.max)
  if (Math.abs(k) < K_RANGE.floor) k = k < 0 ? -K_RANGE.floor : K_RANGE.floor
  return k
}

// L'étiquette d'un sommet : à 17 unités, à l'opposé du centre de gravité.
const away = (p, from) => {
  const l = length(p, from) || 1
  return { x: p.x + 17 * (p.x - from.x) / l, y: p.y + 17 * (p.y - from.y) / l }
}

// L'étiquette de M ou de N : à 17 unités, du côté de la droite opposé au troisième sommet.
const side = (p, o, q, x) => {
  let nx = -(q.y - o.y)
  let ny = q.x - o.x
  const l = Math.hypot(nx, ny) || 1
  nx /= l
  ny /= l
  if (nx * (x.x - o.x) + ny * (x.y - o.y) > 0) {
    nx = -nx
    ny = -ny
  }
  return { x: p.x + 17 * nx, y: p.y + 17 * ny }
}

export default class extends Controller {
  static targets = ["svg", "abc", "amn", "d1", "d2", "bc", "mn", "dot", "name", "hit", "config", "cell", "ratio", "status", "lock"]
  static values = {
    aX: Number, aY: Number, bX: Number, bY: Number, cX: Number, cY: Number, kM: Number, kN: Number,
    statusLocked: String, statusOrder: String, statusConverse: String, statusContraposed: String,
    configTriangle: String, configButterfly: String, configOther: String, lockFree: String, lockImpose: String
  }

  connect() {
    this.start = {
      A: { x: this.aXValue, y: this.aYValue }, B: { x: this.bXValue, y: this.bYValue }, C: { x: this.cXValue, y: this.cYValue },
      kM: this.kMValue, kN: this.kNValue
    }
    this.load()
    this.drag = null

    // La zone de toucher mesure au moins 44 px à l'écran : son rayon suit la largeur de la feuille.
    this.observer = new ResizeObserver(() => this.sizeHits())
    this.observer.observe(this.svgTarget)
    this.render()
  }

  disconnect() {
    this.observer?.disconnect()
  }

  // --- gestes ---

  grab(event) {
    event.preventDefault()
    this.drag = event.currentTarget.dataset.point
    try {
      this.svgTarget.setPointerCapture(event.pointerId)
    } catch {
      // Pointeur déjà relâché : le glissement ne démarre pas.
      this.drag = null
    }
  }

  move(event) {
    if (!this.drag) return

    const point = this.toSvg(event)
    if (point) this.placeAt(this.drag, point)
  }

  release() {
    this.drag = null
  }

  // Les flèches déplacent le point ; Majuscule pour de petits pas.
  nudge(event) {
    const arrows = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] }
    const direction = arrows[event.key]
    if (!direction) return

    event.preventDefault()
    const name = event.currentTarget.dataset.point
    const factor = event.shiftKey ? 0.25 : 1
    if (name === "M" || name === "N") {
      const along = direction[0] + direction[1] > 0 ? 1 : -1
      this.slide(name, (name === "M" ? this.state.kM : this.state.kN) + along * K_STEP * factor)
    } else {
      const current = this.state[name]
      this.placeAt(name, { x: current.x + direction[0] * STEP * factor, y: current.y + direction[1] * STEP * factor })
    }
  }

  toggleLock() {
    this.state.lock = !this.state.lock
    if (this.state.lock) this.state.kN = this.state.kM
    this.render()
  }

  reset() {
    this.load()
    this.render()
  }

  // --- état ---

  load() {
    this.state = { A: { ...this.start.A }, B: { ...this.start.B }, C: { ...this.start.C }, kM: this.start.kM, kN: this.start.kN, lock: true }
  }

  placeAt(name, point) {
    if (name === "A" || name === "B" || name === "C") {
      this.state[name] = { x: clamp(point.x, BOUNDS.minX, BOUNDS.maxX), y: clamp(point.y, BOUNDS.minY, BOUNDS.maxY) }
      this.render()
    } else {
      const { A, B, C } = this.state
      this.slide(name, project(point, A, name === "M" ? B : C))
    }
  }

  // M ou N prend le coefficient k ; verrouillé, l'autre le prend aussi ; libre, k s'accroche à celui de l'autre près de l'égalité.
  slide(name, k) {
    const bounded = clamp(k, K_RANGE.min, K_RANGE.max)
    let value = Math.abs(bounded) < K_RANGE.floor ? (bounded < 0 ? -K_RANGE.floor : K_RANGE.floor) : bounded
    if (this.state.lock) {
      this.state.kM = value
      this.state.kN = value
    } else {
      const other = name === "M" ? this.state.kN : this.state.kM
      if (Math.abs(value - other) < SNAP) value = other
      if (name === "M") this.state.kM = value
      else this.state.kN = value
    }
    this.render()
  }

  // Le pointeur en coordonnées du dessin (la feuille se redimensionne : getScreenCTM tient compte de l'échelle).
  toSvg(event) {
    const matrix = this.svgTarget.getScreenCTM()
    if (!matrix) return null

    const point = new DOMPoint(event.clientX, event.clientY).matrixTransform(matrix.inverse())
    return { x: clamp(point.x, BOUNDS.minX, BOUNDS.maxX), y: clamp(point.y, BOUNDS.minY, BOUNDS.maxY) }
  }

  // --- dessin ---

  render() {
    const { A, B, C, kM, kN, lock } = this.state
    const M = lerp(A, B, kM)
    const N = lerp(A, C, kN)
    const G = { x: (A.x + B.x + C.x) / 3, y: (A.y + B.y + C.y) / 3 }
    const same = kM * kN > 0
    const parallel = Math.abs(kM - kN) < 1e-9
    const imposed = lock || (parallel && same)

    this.abcTarget.setAttribute("points", this.polygon(A, B, C))
    this.amnTarget.setAttribute("points", this.polygon(A, M, N))
    this.setLine(this.d1Target, extend(A, B, -4, 4))
    this.setLine(this.d2Target, extend(A, C, -4, 4))
    this.setLine(this.bcTarget, extend(B, C, -0.2, 1.2))
    this.setLine(this.mnTarget, extend(M, N, -0.2, 1.2))
    this.mnTarget.dataset.tone = imposed ? "parallel" : "free"

    const places = { A, B, C, M, N }
    const labels = { A: away(A, G), B: away(B, G), C: away(C, G), M: side(M, A, B, C), N: side(N, A, C, B) }
    this.dotTargets.forEach((dot) => this.setCircle(dot, places[dot.dataset.point]))
    this.hitTargets.forEach((hit) => this.setCircle(hit, places[hit.dataset.point]))
    this.nameTargets.forEach((name) => {
      const label = labels[name.dataset.point]
      name.setAttribute("x", round(label.x))
      name.setAttribute("y", round(label.y))
    })

    const AB = length(A, B)
    const AC = length(A, C)
    const BC = length(B, C)
    const MN = length(M, N)
    const measures = { AM: Math.abs(kM) * AB, AN: Math.abs(kN) * AC, MN, AB, AC, BC }
    this.cellTargets.forEach((cell) => { cell.textContent = fixed(measures[cell.dataset.cell] / SCALE, 1) })
    const ratios = [Math.abs(kM), Math.abs(kN), MN / BC]
    this.ratioTargets.forEach((ratio, index) => {
      ratio.textContent = fixed(ratios[index], 2)
      if (index === 2) ratio.dataset.dim = String(!imposed)
    })

    this.configTarget.textContent = !same ? this.configOtherValue : (kM < 0 ? this.configButterflyValue : this.configTriangleValue)
    this.renderStatus({ lock, same, parallel })
    this.lockTarget.textContent = lock ? this.lockFreeValue : this.lockImposeValue
    this.sizeHits()
  }

  renderStatus({ lock, same, parallel }) {
    let text = this.statusContraposedValue
    let tone = "error"
    if (lock) [text, tone] = [this.statusLockedValue, "success"]
    else if (!same) [text, tone] = [this.statusOrderValue, "warning"]
    else if (parallel) [text, tone] = [this.statusConverseValue, "success"]

    this.statusTarget.textContent = text
    this.statusTarget.dataset.tone = tone
  }

  sizeHits() {
    const width = this.svgTarget.getBoundingClientRect().width
    const scale = width > 0 ? width / WIDTH : 1
    const radius = String(round(Math.max(HIT_RADIUS, HIT_SCREEN / scale)))
    this.hitTargets.forEach((hit) => hit.setAttribute("r", radius))
  }

  polygon(...points) {
    return points.map((point) => `${round(point.x)},${round(point.y)}`).join(" ")
  }

  setLine(line, { x1, y1, x2, y2 }) {
    line.setAttribute("x1", round(x1))
    line.setAttribute("y1", round(y1))
    line.setAttribute("x2", round(x2))
    line.setAttribute("y2", round(y2))
  }

  setCircle(circle, point) {
    circle.setAttribute("cx", round(point.x))
    circle.setAttribute("cy", round(point.y))
  }
}
