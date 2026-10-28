// ⚡ FRONT · lib/course_sheet/lens_simulator — le simulateur d'une lentille convergente : B, F et F′ se déplacent, les rayons, l'image et les mesures suivent
// Rôle : charge la position de départ lue sur la figure (`data-d`, `data-h`, `data-f`, `data-grid`), recalcule les trois rayons, l'image (réelle ou virtuelle, en pointillés), l'application, la grille et les boutons
// ADR  : 0110-fiche-de-cours-en-donnees-importees (chantier contenu-en-blocs, 318) · formules de la maquette Fiche Lentilles.dc.html (rays, renderVals) · chargé à la demande par course_sheet/lens_simulator_controller

import { IMAGE_MAX, application, attach, clamp, drawRays, fill, fr, head, round1, scene, set, sizeOf } from "./lens_geometry"

// La lentille en (300, 170) du dessin de 560 x 300 ; 20 unités par centimètre. Mêmes valeurs que kinds/_lens_simulator.
const O = 300
const AX = 170
const S = 20
const WIDTH = 560
const HEIGHT = 300
const RANGE = { d: [0.5, 14.5], h: [0.5, 6.5], f: [1, 7] }
const PRESETS = { photo: [12, 2, 3], projector: [4, 1.5, 3], magnifier: [2, 1.5, 4] }

export class LensSimulator {
  constructor(element) {
    this.element = element
    this.texts = JSON.parse(element.dataset.texts)
    this.state = { d: Number(element.dataset.d), h: Number(element.dataset.h), f: Number(element.dataset.f), grid: element.dataset.grid === "true" }
    this.abort = new AbortController()
    const { signal } = this.abort

    // Les gestes ne s'installent qu'une fois le premier dessin réussi : une erreur de render() ne laisse pas une figure à moitié vivante.
    this.render()
    attach(element.querySelector("svg"), signal, {
      width: WIDTH,
      height: HEIGHT,
      move: (hit, point) => this.drag(hit, point),
      key: (hit, [dx, dy], fine) => this.nudge(hit, dx, dy, fine ? 0.1 : 0.5)
    })
    element.addEventListener("click", (event) => this.click(event), { signal })
    element.dataset.ready = "true"
  }

  destroy() {
    this.abort.abort()
  }

  // --- gestes ---

  drag(hit, point) {
    if (hit === "B") this.update({ d: (O - point.x) / S, h: (AX - point.y) / S })
    else this.update({ f: (hit === "F" ? O - point.x : point.x - O) / S })
  }

  // Les flèches : B se déplace en x et en y, F et F′ le long de l'axe (F à gauche de la lentille, F′ à droite).
  nudge(hit, dx, dy, step) {
    const { d, h, f } = this.state
    if (hit === "B") this.update({ d: d - dx * step, h: h - dy * step })
    else this.update({ f: f + (hit === "F" ? -dx : dx) * step })
  }

  click(event) {
    const preset = event.target.closest("[data-preset]")
    if (preset) {
      const [d, h, f] = PRESETS[preset.dataset.preset]
      this.update({ d, h, f })
    } else if (event.target.closest("[data-role='grid-toggle']")) {
      this.update({ grid: !this.state.grid })
    }
  }

  update(change) {
    for (const key of Object.keys(RANGE)) {
      if (key in change) this.state[key] = round1(clamp(change[key], ...RANGE[key]))
    }
    if ("grid" in change) this.state.grid = change.grid
    this.render()
  }

  // --- dessin ---

  q(role) {
    return this.element.querySelector(`[data-role='${role}']`)
  }

  render() {
    const { d, h, f, grid } = this.state
    const { rays, image } = scene(O, AX, S, WIDTH, d, h, f)
    const t = this.texts
    const bx = O - d * S
    const by = AX - h * S
    const shown = image !== null && Math.abs(image.distance) < IMAGE_MAX

    this.q("grid").dataset.visible = String(grid)
    drawRays(this.q("rays"), rays)
    set(this.q("object-line"), { x1: bx, y1: AX, x2: bx, y2: by })
    set(this.q("object-head"), { points: head(bx, by, AX) })
    set(this.q("label-a"), { x: bx })
    set(this.q("label-b"), { x: bx - 14, y: by - 6 })
    set(this.q("dot-b"), { cx: bx, cy: by })
    for (const [name, x] of [["f", O - f * S], ["fp", O + f * S]]) {
      set(this.q(`label-${name}`), { x })
      set(this.q(`dot-${name}`), { cx: x })
    }
    set(this.element.querySelector("[data-hit='F']"), { cx: O - f * S })
    set(this.element.querySelector("[data-hit='Fp']"), { cx: O + f * S })
    set(this.element.querySelector("[data-hit='B']"), { cx: bx, cy: by })

    this.q("image").dataset.visible = String(shown)
    if (shown) this.renderImage(image)

    const cm = (value) => fill(t.cm, { value: fr(value) })
    const kind = application(d, f)
    this.q("oa").textContent = cm(d)
    this.q("f").textContent = cm(f)
    this.q("size").textContent = `${cm(h)} / ${image ? cm(Math.abs(image.gain) * h) : t.none_value}`
    this.q("application").textContent = t[`application_${kind ?? "none"}`]

    let [oap, nature, tone] = [t.oap_infinite, t.nature_none, "warning"]
    if (image?.virtual) [oap, nature, tone] = [fill(t.oap_virtual, { value: fr(-image.distance) }), t.nature_virtual, "note"]
    else if (image) [oap, nature, tone] = [fill(t.oap_real, { value: fr(image.distance) }), fill(t.nature_real, { size: t[`size_${sizeOf(image.gain)}`] }), "success"]
    // Une image qui existe mais sort du dessin (OA′ ≥ 40 cm) le dit : sinon la figure semble vide sans raison.
    const state = image === null ? "none" : shown ? (image.virtual ? "virtual" : "real") : "far"
    this.q("oap").textContent = oap
    this.q("nature").textContent = nature
    this.q("nature").dataset.tone = tone
    this.q("status").textContent = t[`status_${state}`]
    this.q("status").dataset.tone = { none: "warning", far: "warning", virtual: "note", real: "success" }[state]

    for (const button of this.element.querySelectorAll("[data-preset]")) {
      if (button.dataset.preset === kind) button.setAttribute("aria-current", "true")
      else button.removeAttribute("aria-current")
    }
    this.q("grid-toggle").textContent = grid ? t.grid_hide : t.grid_show
  }

  renderImage(image) {
    const above = image.y < AX
    set(this.q("image-line"), { x1: image.x, y1: AX, x2: image.x, y2: image.y })
    this.q("image-line").dataset.virtual = String(image.virtual)
    set(this.q("image-head"), { points: head(image.x, image.y, AX) })
    set(this.q("label-ap"), { x: image.x, y: above ? 188 : 162 })
    set(this.q("label-bp"), { x: image.x + 15, y: above ? image.y - 4 : image.y + 16 })
  }
}
