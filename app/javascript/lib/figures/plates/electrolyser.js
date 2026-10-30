// ⚡ FRONT · lib/figures/plates/electrolyser — la planche de l'électrolyseur de laboratoire (cuve, deux électrodes, deux tubes de recueil)
// Rôle : déclare le titre, les 9 parties (nom français, ancre) et trace le générateur, la cuve et son électrolyte, l'anode (+) et la cathode (−) sous leurs tubes retournés, avec deux fois plus de dihydrogène que de dioxygène
// ADR  : 0117-figures-des-matieres-de-3eme (§4.2 plate) · UDR : 0142-dessin-des-figures-de-3eme (§3 plate) · lu par lib/figures/plate

export const TITLE = "Électrolyseur (électrolyse de l'eau)"

const ANODE_X = 270
const CATHODE_X = 370
const HALF = 22
const TUBE_TOP = 150
const TUBE_BOTTOM = 370
const OXYGEN_HEIGHT = 50
const HYDROGEN_HEIGHT = 2 * OXYGEN_HEIGHT
const LIQUID = 330
const VESSEL_BOTTOM = 420

export const PARTS = {
  generator: { name: "générateur", anchor: [266, 74] },
  vessel: { name: "cuve", anchor: [426, 412] },
  electrolyte: { name: "eau additionnée de soude", anchor: [230, 338] },
  anode: { name: "anode (reliée au +)", anchor: [ANODE_X - 5, 395] },
  cathode: { name: "cathode (reliée au −)", anchor: [CATHODE_X + 5, 350] },
  oxygen_tube: { name: "tube de dioxygène", anchor: [ANODE_X - HALF, 240] },
  hydrogen_tube: { name: "tube de dihydrogène", anchor: [CATHODE_X + HALF, 290] },
  oxygen: { name: "dioxygène", anchor: [ANODE_X - 12, TUBE_TOP + 12] },
  hydrogen: { name: "dihydrogène", anchor: [CATHODE_X + 12, TUBE_TOP + 14] }
}

export function draw(group, { el, sketch, part, pattern, label }) {
  const waves = pattern("waves", 12, (node) => el("path", { d: "M0 6 Q3 3 6 6 T12 6", fill: "none", stroke: "muted", "stroke-width": 0.8 }, node))
  const bubbles = pattern("bubbles", 12, (node) => el("circle", { cx: 6, cy: 6, r: 1.5, fill: "none", stroke: "muted", "stroke-width": 0.8 }, node))

  // Le générateur : un boîtier à deux bornes, + à gauche (relié à l'anode), − à droite (relié à la cathode) ; les fils passent sous la cuve.
  part("generator", "rect", { x: 266, y: 46, width: 108, height: 56, rx: 6 }, group)
  label(group, 320, 80, "G", { size: 18 })
  label(group, 286, 92, "+", { size: 14 })
  label(group, 354, 92, "−", { size: 14 })
  sketch("path", { d: `M286 102 V112 H196 V438 H${ANODE_X} V${VESSEL_BOTTOM}`, "stroke-width": 1.8 }, group)
  sketch("path", { d: `M354 102 V112 H444 V438 H${CATHODE_X} V${VESSEL_BOTTOM}`, "stroke-width": 1.8 }, group)

  // L'électrolyte : dans la cuve, et dans chaque tube sous le gaz recueilli.
  part("electrolyte", "rect", { x: 215, y: LIQUID, width: 210, height: VESSEL_BOTTOM - LIQUID - 1, texture: waves, stroke: "none" }, group)
  ;[[ANODE_X, OXYGEN_HEIGHT], [CATHODE_X, HYDROGEN_HEIGHT]].forEach(([x, gas]) => {
    part("electrolyte", "rect", { x: x - HALF + 1, y: TUBE_TOP + gas, width: 2 * HALF - 2, height: TUBE_BOTTOM - TUBE_TOP - gas, texture: waves, stroke: "none" }, group)
  })
  sketch("path", { d: `M215 ${LIQUID} H${ANODE_X - HALF} M${ANODE_X + HALF} ${LIQUID} H${CATHODE_X - HALF} M${CATHODE_X + HALF} ${LIQUID} H425`, "stroke-width": 1.2 }, group)

  // Les gaz recueillis : le volume de dihydrogène (cathode) est le double de celui de dioxygène (anode).
  part("oxygen", "rect", { x: ANODE_X - HALF + 1, y: TUBE_TOP + 1, width: 2 * HALF - 2, height: OXYGEN_HEIGHT - 1, texture: bubbles, stroke: "none" }, group)
  part("hydrogen", "rect", { x: CATHODE_X - HALF + 1, y: TUBE_TOP + 1, width: 2 * HALF - 2, height: HYDROGEN_HEIGHT - 1, texture: bubbles, stroke: "none" }, group)
  label(group, ANODE_X, TUBE_TOP + 36, "O₂", { size: 13 })
  label(group, CATHODE_X, TUBE_TOP + 76, "H₂", { size: 13 })
  ;[ANODE_X, CATHODE_X].forEach((x) => {
    sketch("circle", { cx: x - 4, cy: 312, r: 2.2, stroke: "muted", "stroke-width": 1 }, group)
    sketch("circle", { cx: x + 5, cy: 296, r: 2.2, stroke: "muted", "stroke-width": 1 }, group)
    sketch("circle", { cx: x - 3, cy: 280, r: 2.2, stroke: "muted", "stroke-width": 1 }, group)
  })

  // Les électrodes, qui traversent le fond de la cuve et montent dans les tubes.
  part("anode", "rect", { x: ANODE_X - 5, y: 300, width: 10, height: VESSEL_BOTTOM - 300, fill: "muted" }, group)
  part("cathode", "rect", { x: CATHODE_X - 5, y: 300, width: 10, height: VESSEL_BOTTOM - 300, fill: "muted" }, group)

  // Les tubes retournés : fermés en haut par un robinet, ouverts sous la surface.
  const bell = (x) => `M${x - HALF} ${TUBE_BOTTOM} V${TUBE_TOP} H${x + HALF} V${TUBE_BOTTOM}`
  part("oxygen_tube", "path", { d: bell(ANODE_X), fill: "none", "stroke-width": 2.5 }, group)
  part("hydrogen_tube", "path", { d: bell(CATHODE_X), fill: "none", "stroke-width": 2.5 }, group)
  ;[ANODE_X, CATHODE_X].forEach((x) => sketch("path", { d: `M${x - 8} ${TUBE_TOP} V${TUBE_TOP - 10} H${x + 8} V${TUBE_TOP}` }, group))

  part("vessel", "path", { d: `M214 290 V${VESSEL_BOTTOM} H426 V290`, fill: "none", "stroke-width": 2.5 }, group)
}
