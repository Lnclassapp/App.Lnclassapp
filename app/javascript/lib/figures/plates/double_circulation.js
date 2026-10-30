// ⚡ FRONT · lib/figures/plates/double_circulation — la planche du schéma de la double circulation (cœur droit à gauche de l'image, cœur gauche à droite)
// Rôle : déclare le titre, les 8 parties (nom français, ancre) et trace poumons, organes, deux cœurs et quatre vaisseaux fléchés ; sang pauvre en O₂ en tirets, sang riche en O₂ en trait plein
// ADR  : XXXX-figures-des-matieres-de-3eme (§4.2 plate) · UDR : XXXX-figures-des-matieres-de-3eme (§3 plate) · lu par lib/figures/plate

export const TITLE = "Double circulation"

export const PARTS = {
  right_heart: { name: "cœur droit", anchor: [276, 282] },
  left_heart: { name: "cœur gauche", anchor: [364, 262] },
  lungs: { name: "poumons", anchor: [262, 98] },
  organs: { name: "organes", anchor: [380, 404] },
  pulmonary_artery: { name: "artère pulmonaire", anchor: [268, 172] },
  pulmonary_veins: { name: "veines pulmonaires", anchor: [372, 172] },
  aorta: { name: "aorte", anchor: [418, 320] },
  vena_cava: { name: "veines caves", anchor: [222, 320] }
}

export function draw(group, { el, sketch, part, pattern, defs, uid, label }) {
  const alveoli = pattern("alveoli", 9, (node) => el("circle", { cx: 4.5, cy: 4.5, r: 2.4, fill: "none", stroke: "muted", "stroke-width": 0.8 }, node))
  const capillaries = pattern("capillaries", 12, (node) => el("path", { d: "M0 6 Q3 1 6 6 T12 6", fill: "none", stroke: "muted", "stroke-width": 0.8 }, node))
  const poor = pattern("poor", 6, (node) => el("path", { d: "M0 6 L6 0", stroke: "muted", "stroke-width": 0.8 }, node))

  const arrow = uid("arrow")
  const marker = el("marker", { id: arrow, viewBox: "0 0 10 10", refX: 8, refY: 5, markerWidth: 11, markerHeight: 11, markerUnits: "userSpaceOnUse", orient: "auto" }, defs)
  el("path", { d: "M0 0 L10 5 L0 10 Z", fill: "ink", stroke: "none" }, marker)

  // Les deux réseaux de capillaires : poumons en haut, organes en bas.
  part("lungs", "path", { d: "M222 100 C222 70 262 62 292 70 C310 76 330 76 348 70 C378 62 418 70 418 100 C418 124 396 134 372 134 H268 C244 134 222 124 222 100 Z", texture: alveoli, "stroke-width": 2 }, group)
  part("organs", "path", { d: "M214 372 H426 Q440 372 440 386 V418 Q440 432 426 432 H214 Q200 432 200 418 V386 Q200 372 214 372 Z", texture: capillaries, "stroke-width": 2 }, group)

  // Les vaisseaux : tirets pour le sang pauvre en O₂, trait plein pour le sang riche en O₂.
  const vessel = (id, d, dashed) => part(id, "path", { d, fill: "none", "stroke-width": 3.2, "stroke-dasharray": dashed ? "8 4" : "0", "stroke-linecap": "butt", "marker-end": `url(#${arrow})` }, group)
  vessel("vena_cava", "M222 372 V256 H234", true)
  vessel("pulmonary_artery", "M268 210 V138", true)
  vessel("pulmonary_veins", "M372 136 V208", false)
  vessel("aorta", "M404 256 H418 V370", false)

  // Les deux cœurs : le droit (sang pauvre en O₂) est hachuré, le gauche (sang riche en O₂) reste blanc.
  part("right_heart", "path", { d: "M238 222 Q238 210 250 210 H302 Q314 210 314 222 V288 Q314 300 302 300 H250 Q238 300 238 288 Z", texture: poor, "stroke-width": 2 }, group)
  part("left_heart", "path", { d: "M326 222 Q326 210 338 210 H390 Q402 210 402 222 V288 Q402 300 390 300 H338 Q326 300 326 288 Z", "stroke-width": 2 }, group)

  sketch("path", { d: "M180 452 H204", "stroke-dasharray": "8 4", "stroke-width": 2.5, "stroke-linecap": "butt" }, group)
  label(group, 210, 456, "sang pauvre en O₂ : tirets, hachures", { anchor: "start", tone: "muted", size: 11 })
  sketch("path", { d: "M180 470 H204", "stroke-width": 2.5, "stroke-linecap": "butt" }, group)
  label(group, 210, 474, "sang riche en O₂ : trait plein", { anchor: "start", tone: "muted", size: 11 })
}
