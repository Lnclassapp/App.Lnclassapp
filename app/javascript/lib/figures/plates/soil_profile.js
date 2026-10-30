// ⚡ FRONT · lib/figures/plates/soil_profile — la planche du profil de sol (coupe verticale en bandes)
// Rôle : déclare le titre, les 6 parties (nom français, ancre) et trace litière, horizon humifère, horizon d'accumulation, roche mère altérée, roche mère et racines, chaque horizon avec son motif
// ADR  : XXXX-figures-des-matieres-de-3eme (§4.2 plate) · UDR : XXXX-figures-des-matieres-de-3eme (§3 plate) · lu par lib/figures/plate

export const TITLE = "Profil de sol"

const LEFT = 190
const RIGHT = 450
const COLUMNS = 6
const X = Array.from({ length: COLUMNS + 1 }, (_, index) => LEFT + (index * (RIGHT - LEFT)) / COLUMNS)

// Une limite entre deux horizons : des points à ordonnée presque constante (le relief naturel d'une coupe).
const boundary = (y, bumps, shifts = []) => X.map((x, index) => [x + (shifts[index] ?? 0), y + bumps[index]])

const SURFACE = boundary(92, [0, 3, -2, 2, -3, 2, 0])
const HUMUS_BASE = boundary(162, [0, 4, -3, 3, -2, 4, 0])
const ACCUMULATION_BASE = boundary(250, [0, 3, -4, 2, 4, -3, 0], [0, 4, -3, 5, -4, 3, 0])
const MIDDLE = boundary(276, [0, -3, 4, -2, 3, -4, 0], [0, -8, 7, -5, 9, -6, 0])
const LOWER = boundary(306, [0, 4, -3, 3, -4, 3, 0], [0, 8, -7, 6, -9, 7, 0])
const BEDROCK_TOP = boundary(342, [0, -3, 3, -2, 4, -3, 0], [0, -4, 5, -3, 4, -5, 0])
const LAYERS = [ACCUMULATION_BASE, MIDDLE, LOWER, BEDROCK_TOP]

const forward = (line) => line.map(([x, y], index) => `${index === 0 ? "M" : "L"}${x} ${y}`).join(" ")
const backward = (line) => [...line].reverse().map(([x, y]) => `L${x} ${y}`).join(" ")
const band = (top, bottom) => `${forward(top)} ${backward(bottom)} Z`

// Les blocs de la roche mère altérée : des quadrilatères entre les lignes du quadrillage, rétrécis de 2 unités pour laisser voir les fissures.
function blocks() {
  const result = []
  for (let row = 0; row < LAYERS.length - 1; row += 1) {
    for (let col = 0; col < COLUMNS; col += 1) {
      const corners = [LAYERS[row][col], LAYERS[row][col + 1], LAYERS[row + 1][col + 1], LAYERS[row + 1][col]]
      const cx = corners.reduce((sum, [x]) => sum + x, 0) / 4
      const cy = corners.reduce((sum, [, y]) => sum + y, 0) / 4
      const shrunk = corners.map(([x, y]) => {
        const length = Math.hypot(cx - x, cy - y)
        return [Math.round((x + ((cx - x) * 3) / length) * 10) / 10, Math.round((y + ((cy - y) * 3) / length) * 10) / 10]
      })
      result.push({ cx: Math.round(cx), cy: Math.round(cy), d: `${forward(shrunk)} Z` })
    }
  }
  return result
}

const BLOCKS = blocks()
const ROCK_ANCHOR = BLOCKS[COLUMNS + 4]

export const PARTS = {
  litter: { name: "litière", anchor: [214, 80] },
  humus_horizon: { name: "horizon humifère", anchor: [424, 128] },
  accumulation_horizon: { name: "horizon d'accumulation", anchor: [214, 206] },
  weathered_rock: { name: "roche mère altérée", anchor: [ROCK_ANCHOR.cx, ROCK_ANCHOR.cy] },
  bedrock: { name: "roche mère", anchor: [214, 390] },
  roots: { name: "racines", anchor: [330, 150] }
}

export function draw(group, { el, sketch, part, pattern }) {
  const leaves = pattern("leaves", 13, (node) => {
    el("ellipse", { cx: 6.5, cy: 6.5, rx: 5.5, ry: 2.4, transform: "rotate(-35 6.5 6.5)", fill: "paper", stroke: "ink", "stroke-width": 0.9 }, node)
    el("path", { d: "M2 10 L11 3", stroke: "ink", "stroke-width": 0.7 }, node)
  })
  const humus = pattern("humus", 9, (node) => {
    el("rect", { x: 0, y: 0, width: 9, height: 9, fill: "ink", "fill-opacity": 0.22 }, node)
    el("circle", { cx: 2, cy: 2.5, r: 1, fill: "ink" }, node)
    el("circle", { cx: 6.5, cy: 6, r: 1.1, fill: "ink" }, node)
  })
  const accumulation = pattern("accumulation", 14, (node) => {
    el("path", { d: "M1 4 H7 M8 11 H13", stroke: "ink", "stroke-width": 1.1 }, node)
  })
  const fines = pattern("fines", 6, (node) => el("circle", { cx: 3, cy: 3, r: 0.8, fill: "muted" }, node))
  const rock = pattern("rock", 10, (node) => {
    el("path", { d: "M0 0 L10 10 M10 0 L0 10", stroke: "muted", "stroke-width": 0.8 }, node)
  })

  // Les horizons, de la surface à la roche mère.
  const litterTop = SURFACE.map(([x, y], index) => [x, y - 26 + (index % 2) * 4])
  part("litter", "path", { d: band(litterTop, SURFACE), texture: leaves }, group)
  part("humus_horizon", "path", { d: band(SURFACE, HUMUS_BASE), texture: humus }, group)
  part("accumulation_horizon", "path", { d: band(HUMUS_BASE, ACCUMULATION_BASE), texture: accumulation }, group)
  part("weathered_rock", "path", { d: band(ACCUMULATION_BASE, BEDROCK_TOP), texture: fines }, group)
  BLOCKS.forEach(({ d }) => part("weathered_rock", "path", { d, "stroke-width": 1.2 }, group))
  const floor = BEDROCK_TOP.map(([x, y]) => [x, y + 76])
  floor[0][1] = floor[COLUMNS][1] = 418
  part("bedrock", "path", { d: band(BEDROCK_TOP, floor), texture: rock, "stroke-width": 2 }, group)
  sketch("path", { d: "M300 352 L322 380 L310 410 M392 350 L380 382 L400 414", "stroke-width": 1.4 }, group)

  // Le plant et ses racines : une racine principale et des racines secondaires qui traversent la litière puis les deux horizons supérieurs.
  sketch("path", { d: "M330 90 V46 M330 62 C320 56 312 56 306 62 C314 68 322 68 330 62 M330 52 C340 44 350 44 356 50 C348 56 340 58 330 52", "stroke-width": 1.8 }, group)
  ;[
    "M330 92 C328 130 334 170 326 238",
    "M329 118 C312 124 298 126 282 140",
    "M332 148 C350 154 366 152 384 166",
    "M328 184 C312 192 300 198 286 214",
    "M327 208 C344 214 358 218 372 232"
  ].forEach((d) => part("roots", "path", { d, fill: "none", "stroke-width": 2.4 }, group))
}
