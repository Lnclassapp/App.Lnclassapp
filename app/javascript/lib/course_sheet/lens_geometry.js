// ⚡ FRONT · lib/course_sheet/lens_geometry — l'optique et les gestes partagés par le simulateur et l'entraînement de la fiche Lentilles
// Rôle : les trois rayons particuliers, l'image, l'application ; le dessin des rayons ; glisser un point au doigt, à la souris ou aux flèches ; zones de toucher de 44 px
// ADR  : 0110-fiche-de-cours-en-donnees-importees (chantier contenu-en-blocs, 318) · mêmes formules que Catalog::CourseSheetLensHelper (la position de départ, calculée côté serveur)

const SVG_NS = "http://www.w3.org/2000/svg"
const FOCUS_TOLERANCE = 0.06
const SAME_SIZE = 0.03
const HIT_SCREEN = 22
const ARROWS = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] }

export const IMAGE_MAX = 40
export const clamp = (value, min, max) => Math.max(min, Math.min(max, value))
export const round1 = (value) => Math.round(value * 10) / 10
const round2 = (value) => Math.round(value * 100) / 100

// Un nombre à la française, au dixième : « 2 », « 2,5 ».
export const fr = (value) => String(round1(value)).replace(".", ",")

// « %{nom} » d'un texte de la locale.
export const fill = (template, values) => template.replace(/%\{(\w+)\}/g, (_, key) => values[key])

export const set = (element, attributes) => {
  for (const [name, value] of Object.entries(attributes)) element.setAttribute(name, typeof value === "number" ? round2(value) : value)
}

// La pointe d'une flèche de 10 unités sur 5 de demi-largeur, du côté de l'axe.
export function head(x, y, axis) {
  const sign = y < axis ? 1 : -1
  return [[x, y], [x - 5, y + 10 * sign], [x + 5, y + 10 * sign]].map(([px, py]) => `${round2(px)},${round2(py)}`).join(" ")
}

// o : abscisse de la lentille, ax : ordonnée de l'axe, s : unités par cm, w : largeur du dessin ; d : OA, h : AB, f : distance focale, en cm.
// → { rays: [{ x1, y1, x2, y2, ray, virtual }], image: { distance, gain, x, y, virtual } | null }
export function scene(o, ax, s, w, d, h, f) {
  const xb = o - d * s
  const yb = ax - h * s
  const rays = []
  const add = (x1, y1, x2, y2, ray, virtual = false) => rays.push({ x1, y1, x2, y2, ray, virtual })
  add(xb, yb, o, yb, 1)
  add(o, yb, w, yb + (ax - yb) / (f * s) * (w - o), 1)
  add(xb, yb, w, yb + (ax - yb) / (d * s) * (w - xb), 2)
  if (Math.abs(d - f) <= FOCUS_TOLERANCE) return { rays, image: null }

  const y3 = ax + (yb - ax) * (f / (f - d))
  if (d < f) add(o - f * s, ax, xb, yb, 3, true)
  add(xb, yb, o, y3, 3)
  add(o, y3, w, y3, 3)
  const distance = d * f / (d - f)
  const gain = -distance / d
  const image = { distance, gain, x: o + distance * s, y: ax - gain * h * s, virtual: distance < 0 }
  if (image.virtual) {
    add(o, yb, image.x, image.y, 1, true)
    add(xb, yb, image.x, image.y, 2, true)
    add(o, y3, image.x, image.y, 3, true)
  }
  return { rays, image }
}

// « magnifier » (objet entre la lentille et le foyer), « projector » (entre F et 2F), « photo » (au-delà de 2F), null (au foyer).
export const application = (d, f) => (Math.abs(d - f) <= FOCUS_TOLERANCE ? null : d < f ? "magnifier" : d < 2 * f ? "projector" : "photo")

// « bigger », « smaller » ou « same », d'après le gain d'une image réelle.
export function sizeOf(gain) {
  const size = Math.abs(gain)
  return size > 1 + SAME_SIZE ? "bigger" : size < 1 - SAME_SIZE ? "smaller" : "same"
}

// Les rayons du serveur sont remplacés par ceux de la nouvelle position.
export function drawRays(group, rays) {
  group.replaceChildren(...rays.map((ray) => {
    const line = document.createElementNS(SVG_NS, "line")
    set(line, { class: "sheet-lens-ray", x1: ray.x1, y1: ray.y1, x2: ray.x2, y2: ray.y2 })
    line.dataset.ray = String(ray.ray)
    line.dataset.virtual = String(ray.virtual)
    return line
  }))
}

// Les gestes d'un dessin : un point se prend par sa zone de toucher `[data-hit]`, se glisse (move) ou se pousse aux flèches (key).
// Majuscule pour de petits pas. Le rayon des zones de toucher suit la largeur du dessin : 22 px d'écran au moins.
export function attach(svg, signal, { width, height, move, key }) {
  let held = null
  svg.addEventListener("pointerdown", (event) => {
    const hit = event.target.closest("[data-hit]")
    if (!hit) return

    event.preventDefault()
    held = hit.dataset.hit
    try {
      svg.setPointerCapture(event.pointerId)
    } catch {
      // Pointeur déjà relâché : le glissement ne démarre pas.
      held = null
    }
  }, { signal })

  svg.addEventListener("pointermove", (event) => {
    const matrix = svg.getScreenCTM()
    if (!held || !matrix) return

    const point = new DOMPoint(event.clientX, event.clientY).matrixTransform(matrix.inverse())
    move(held, { x: clamp(point.x, 0, width), y: clamp(point.y, 0, height) })
  }, { signal })

  for (const type of ["pointerup", "pointercancel"]) svg.addEventListener(type, () => { held = null }, { signal })

  svg.addEventListener("keydown", (event) => {
    const hit = event.target.closest("[data-hit]")
    const direction = ARROWS[event.key]
    if (!hit || !direction) return

    event.preventDefault()
    key(hit.dataset.hit, direction, event.shiftKey)
  }, { signal })

  const hits = [...svg.querySelectorAll("[data-hit]")].map((hit) => [hit, Number(hit.getAttribute("r"))])
  const observer = new ResizeObserver(() => {
    const scale = svg.getBoundingClientRect().width / width || 1
    for (const [hit, radius] of hits) set(hit, { r: Math.max(radius, HIT_SCREEN / scale) })
  })
  observer.observe(svg)
  signal.addEventListener("abort", () => observer.disconnect())
}
