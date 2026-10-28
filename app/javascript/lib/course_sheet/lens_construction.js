// ⚡ FRONT · lib/course_sheet/lens_construction — « Place l'image » : un énoncé de lentille, B′ à glisser sur le quadrillage, Vérifier, solution, nouvel exercice, score
// Rôle : tire un énoncé (f, OA, AB), place le marqueur au demi-carreau, juge à ±0,5 carreau, compte chaque énoncé une seule fois, dessine la solution (rayons et image)
// ADR  : 0110-fiche-de-cours-en-donnees-importees (chantier contenu-en-blocs, 318) · formules de la maquette Fiche Lentilles.dc.html (PROBS, prCheck) · chargé à la demande par course_sheet/lens_construction_controller

import { attach, clamp, drawRays, fill, fr, head, scene, set } from "./lens_geometry"

// La lentille en (260, 130) du dessin de 560 x 260 ; 20 unités par centimètre. Mêmes valeurs que kinds/_lens_construction.
const O = 260
const AX = 130
const S = 20
const WIDTH = 560
const HEIGHT = 260
const TOLERANCE = 0.5
const START = { x: 5, y: -1 }
// [f, OA, AB] en cm : le premier est celui que le serveur dessine.
const PROBLEMS = [[2, 3, 1.5], [2, 4, 2], [2, 6, 3], [3, 6, 2], [3, 4.5, 1.5], [4, 8, 2], [3, 12, 3], [4, 6, 1.5], [4, 2, 1.5], [6, 3, 1], [3, 2, 1.5], [5, 10, 2], [2, 3, 2]]

const half = (value) => Math.round(value * 2) / 2

export class LensConstruction {
  constructor(element) {
    this.element = element
    this.texts = JSON.parse(element.dataset.texts)
    this.score = { ok: 0, total: 0 }
    this.index = 0
    this.abort = new AbortController()
    const { signal } = this.abort

    // Les gestes ne s'installent qu'une fois le premier énoncé dessiné : une erreur de load() ne laisse pas un exercice à moitié vivant.
    this.load(Math.floor(Math.random() * PROBLEMS.length))
    this.renderScore()
    attach(element.querySelector("svg"), signal, {
      width: WIDTH,
      height: HEIGHT,
      move: (_hit, point) => this.place({ x: half((point.x - O) / S), y: half((AX - point.y) / S) }),
      key: (_hit, [dx, dy]) => this.place({ x: this.mark.x + dx * TOLERANCE, y: this.mark.y - dy * TOLERANCE })
    })
    element.addEventListener("click", (event) => this.click(event), { signal })
    element.dataset.ready = "true"
  }

  destroy() {
    this.abort.abort()
  }

  q(role) {
    return this.element.querySelector(`[data-role='${role}']`)
  }

  click(event) {
    const button = event.target.closest("button[data-role]")
    if (button?.dataset.role === "check") this.check()
    else if (button?.dataset.role === "solution-toggle") this.toggleSolution()
    else if (button?.dataset.role === "next") this.load((this.index + 1 + Math.floor(Math.random() * (PROBLEMS.length - 1))) % PROBLEMS.length)
  }

  // --- énoncé ---

  load(index) {
    this.index = index
    const [f, d, h] = PROBLEMS[index]
    Object.assign(this.element.dataset, { f, d, h })
    Object.assign(this, { f, d, h, counted: false })
    this.q("prompt").textContent = fill(this.texts.prompt, { f: fr(f), h: fr(h), d: fr(d) })
    this.clearMessage()
    this.showSolution(false)

    const bx = O - d * S
    const by = AX - h * S
    set(this.q("object-line"), { x1: bx, y1: AX, x2: bx, y2: by })
    set(this.q("object-head"), { points: head(bx, by, AX) })
    set(this.q("label-a"), { x: bx })
    set(this.q("label-b"), { x: bx - 14, y: by - 4 })
    for (const [name, x] of [["f", O - f * S], ["fp", O + f * S]]) {
      set(this.q(`label-${name}`), { x })
      set(this.q(`dot-${name}`), { cx: x })
    }

    const { rays, image } = scene(O, AX, S, WIDTH, d, h, f)
    drawRays(this.q("rays"), rays)
    this.answer = { x: image.distance, y: image.gain * h, virtual: image.virtual }
    set(this.q("image-line"), { x1: image.x, y1: AX, x2: image.x, y2: image.y })
    this.q("image-line").dataset.virtual = String(image.virtual)
    set(this.q("image-head"), { points: head(image.x, image.y, AX) })
    this.place({ ...START })
  }

  // --- marqueur ---

  place(mark) {
    this.mark = { x: clamp(mark.x, -O / S, (WIDTH - O) / S), y: clamp(mark.y, -(HEIGHT - AX) / S, AX / S) }
    const x = O + this.mark.x * S
    const y = AX - this.mark.y * S
    set(this.q("marker"), { cx: x, cy: y })
    set(this.element.querySelector("[data-hit='marker']"), { cx: x, cy: y })
    set(this.q("marker-guide"), { x1: x, y1: AX, x2: x, y2: y })
    set(this.q("marker-label"), { x: x > WIDTH - 40 ? x - 24 : x + 24, y: y < AX ? y - 8 : y + 20 })
    this.clearMessage()
  }

  // --- jugement ---

  check() {
    const ok = Math.abs(this.mark.x - this.answer.x) <= TOLERANCE && Math.abs(this.mark.y - this.answer.y) <= TOLERANCE
    if (!this.counted) {
      this.counted = true
      this.score = { ok: this.score.ok + (ok ? 1 : 0), total: this.score.total + 1 }
      this.renderScore()
    }

    const t = this.texts
    const right = fill(this.answer.virtual ? t.right_virtual : t.right_real, { size: fr(Math.abs(this.answer.y)) })
    this.q("message").textContent = ok ? `${t.right_start} ${right}` : t.wrong
    this.q("message").dataset.state = ok ? "correct" : "wrong"
  }

  toggleSolution() {
    this.showSolution(this.q("solution").dataset.visible !== "true")
  }

  showSolution(visible) {
    this.q("solution").dataset.visible = String(visible)
    const button = this.q("solution-toggle")
    button.textContent = visible ? this.texts.solution_hide : this.texts.solution_show
    button.setAttribute("aria-expanded", String(visible))
  }

  clearMessage() {
    this.q("message").textContent = ""
    delete this.q("message").dataset.state
  }

  renderScore() {
    this.q("score").textContent = this.texts.score.replace("{ok}", this.score.ok).replace("{total}", this.score.total)
  }
}
