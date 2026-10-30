// ⚡ FRONT · lib/figures/plates/root_hairs — la planche de la racine et des poils absorbants (médaillon : un poil entre les particules de sol)
// Rôle : déclare le titre, les 9 parties (nom français, ancre) et trace le plant (collet), la racine (coiffe, zone d'allongement, zone pilifère), ses racines secondaires et un médaillon agrandi
// ADR  : 0117-figures-des-matieres-de-3eme (§4.2 plate) · UDR : 0142-dessin-des-figures-de-3eme (§3 plate) · lu par lib/figures/plate

export const TITLE = "Racine et poils absorbants"

const MEDAL = { x: 386, y: 332, r: 72 }
// Le poil : un tube de 10 unités ouvert sur sa cellule (à gauche), refermé en bout arrondi.
const HAIR = "M350 327 C372 327 380 313 398 317 C416 321 420 341 440 343 A5 5 0 0 1 440 353 C420 351 416 331 398 327 C380 323 372 337 350 337"
const PARTICLES = [
  "M376 280 L402 276 L414 290 L404 304 L382 302 Z",
  "M424 286 L446 284 L452 302 L434 314 L420 304 Z",
  "M372 350 L398 346 L414 360 L406 380 L380 382 Z",
  "M424 370 L446 366 L454 386 L436 396 L420 388 Z"
]

export const PARTS = {
  collar: { name: "collet", anchor: [270, 119] },
  main_root: { name: "racine principale", anchor: [270, 150] },
  lateral_root: { name: "racine secondaire", anchor: [236, 180] },
  root_hair_zone: { name: "zone pilifère", anchor: [240, 232] },
  elongation_zone: { name: "zone d'allongement", anchor: [263, 330] },
  root_cap: { name: "coiffe", anchor: [270, 396] },
  root_hair: { name: "poil absorbant", anchor: [398, 322] },
  soil_particle: { name: "particule de sol", anchor: [392, 364] },
  soil_water: { name: "eau du sol", anchor: [366, 300] }
}

export function draw(group, { el, sketch, part, tube, pattern, uid, defs }) {
  const soil = pattern("soil", 9, (node) => {
    el("circle", { cx: 2, cy: 2, r: 0.8, fill: "muted" }, node)
    el("circle", { cx: 6.5, cy: 6, r: 0.8, fill: "muted" }, node)
  })
  const cap = pattern("cap", 5, (node) => el("circle", { cx: 2.5, cy: 2.5, r: 0.8, fill: "ink" }, node))
  const grit = pattern("grit", 6, (node) => el("path", { d: "M0 6 L6 0", stroke: "muted", "stroke-width": 0.8 }, node))
  const water = pattern("water", 12, (node) => el("path", { d: "M0 6 Q3 2 6 6 T12 6", fill: "none", stroke: "muted", "stroke-width": 0.8 }, node))

  // Le sol autour de la racine, sa surface, puis le plant au-dessus.
  sketch("rect", { x: 180, y: 124, width: 280, height: 316, stroke: "none" }, group).style.setProperty("fill", `url(#${soil})`)
  sketch("path", { d: "M180 124 H460", "stroke-width": 2 }, group)
  sketch("path", { d: "M266 124 V72 M274 124 V72", "stroke-width": 1.5 }, group)
  sketch("path", { d: "M270 80 C250 68 236 72 230 84 C244 92 260 90 270 80 Z M270 70 C290 58 304 62 310 74 C296 82 280 80 270 70 Z", fill: "paper" }, group)

  // Les racines secondaires, puis la racine principale par-dessus leur point de départ.
  tube("lateral_root", "M277 140 C300 144 320 154 336 176", 6, { cap: "round" })
  tube("lateral_root", "M263 168 C244 172 226 184 214 206", 6, { cap: "round" })
  part("main_root", "path", { d: "M263 124 V366 C263 384 266 396 270 398 C274 396 277 384 277 366 V124 Z" }, group)

  // Les poils : de plus en plus courts vers le bas (les plus jeunes).
  for (let y = 176; y <= 292; y += 8) {
    const length = 7 + ((292 - y) / 116) * 15
    const side = ((y - 176) / 8) % 2 === 0 ? -1 : 1
    const x = side === -1 ? 263 : 277
    sketch("path", { d: `M${x} ${y} q${side * length * 0.6} ${-3} ${side * length} 2`, "stroke-width": 1.1 }, group)
  }
  part("root_hair_zone", "rect", { x: 240, y: 170, width: 60, height: 128, rx: 10, fill: "ghost", "stroke-width": 1, "stroke-dasharray": "4 3" }, group)
  part("elongation_zone", "rect", { x: 263, y: 298, width: 14, height: 68, fill: "ghost", "stroke-width": 1 }, group)
  part("root_cap", "path", { d: "M263 366 C263 384 266 396 270 398 C274 396 277 384 277 366 Z", fill: "ghost", "stroke-width": 1.2 }, group)
  sketch("path", { d: "M266 372 H274 M266 380 H274 M268 388 H272", "stroke-width": 1 }, group)
  part("collar", "rect", { x: 262, y: 118, width: 16, height: 12, fill: "ghost", "stroke-width": 1.2 }, group)

  // Le repère d'agrandissement : un cercle sur la racine, relié au médaillon.
  sketch("circle", { cx: 287, cy: 262, r: 9, "stroke-width": 1.2, "stroke-dasharray": "3 2" }, group)
  sketch("path", { d: "M293 256 L346 280 M294 270 L322 346", "stroke-width": 1, "stroke-dasharray": "3 3", stroke: "muted" }, group)
  const clip = el("clipPath", { id: uid("medal") }, defs)
  el("circle", { cx: MEDAL.x, cy: MEDAL.y, r: MEDAL.r }, clip)

  // Le médaillon : l'eau du sol remplit les pores, les particules sont des fragments anguleux, le poil prolonge une cellule de la racine.
  part("soil_water", "circle", { cx: MEDAL.x, cy: MEDAL.y, r: MEDAL.r, texture: water, "stroke-width": 2.5 }, group)
  const inside = el("g", { "clip-path": `url(#${uid("medal")})` }, group)
  PARTICLES.forEach((d) => part("soil_particle", "path", { d, texture: grit, "stroke-width": 1.6 }, inside))
  ;[262, 290, 318, 346, 374, 402].forEach((y) => sketch("rect", { x: 306, y, width: 44, height: 28, fill: "paper", "stroke-width": 1.3 }, inside))
  sketch("ellipse", { cx: 330, cy: 332, rx: 8, ry: 6, fill: "ink", "fill-opacity": 0.55, "stroke-width": 1 }, inside)
  part("root_hair", "path", { d: HAIR }, inside)
}
