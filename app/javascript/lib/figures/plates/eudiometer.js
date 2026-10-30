// ⚡ FRONT · lib/figures/plates/eudiometer — la planche de l'eudiomètre (tube gradué retourné sur une cuve à eau)
// Rôle : déclare le titre, les 7 parties (nom français, ancre) et trace le tube, sa graduation, les électrodes et l'étincelle, le mélange gazeux, l'eau montée dans le tube et la cuve
// ADR  : XXXX-figures-des-matieres-de-3eme (§4.2 plate) · UDR : XXXX-figures-des-matieres-de-3eme (§3 plate) · lu par lib/figures/plate

export const TITLE = "Eudiomètre"

const TUBE_LEFT = 290
const TUBE_RIGHT = 350
const TUBE_TOP = 70
const TUBE_BOTTOM = 390
const WATER_LEVEL = 250
const SURFACE = 360
const SPARK_Y = 100

export const PARTS = {
  tube: { name: "tube gradué", anchor: [TUBE_LEFT, 130] },
  scale: { name: "graduation", anchor: [346, 170] },
  electrodes: { name: "électrodes", anchor: [308, 62] },
  spark: { name: "étincelle", anchor: [326, SPARK_Y + 2] },
  gas_mixture: { name: "mélange de dihydrogène et de dioxygène", anchor: [302, 200] },
  water: { name: "eau", anchor: [306, 320] },
  trough: { name: "cuve à eau", anchor: [190, 380] }
}

export function draw(group, { el, sketch, part, pattern, label }) {
  const bubbles = pattern("bubbles", 14, (node) => {
    el("circle", { cx: 4, cy: 4, r: 1.6, fill: "none", stroke: "muted", "stroke-width": 0.8 }, node)
    el("circle", { cx: 10, cy: 10, r: 1.2, fill: "none", stroke: "muted", "stroke-width": 0.8 }, node)
  })
  const waves = pattern("waves", 12, (node) => el("path", { d: "M0 6 Q3 3 6 6 T12 6", fill: "none", stroke: "muted", "stroke-width": 0.8 }, node))

  // L'eau de la cuve et celle du tube : même partie, même motif.
  part("water", "rect", { x: 191, y: SURFACE, width: 258, height: 59, texture: waves, stroke: "none" }, group)
  part("water", "rect", { x: TUBE_LEFT + 1, y: WATER_LEVEL, width: TUBE_RIGHT - TUBE_LEFT - 2, height: TUBE_BOTTOM - WATER_LEVEL, texture: waves, stroke: "none" }, group)
  sketch("path", { d: `M${TUBE_LEFT} ${WATER_LEVEL} Q320 ${WATER_LEVEL + 5} ${TUBE_RIGHT} ${WATER_LEVEL}`, "stroke-width": 1.2 }, group)
  sketch("path", { d: `M191 ${SURFACE} H${TUBE_LEFT - 2} M${TUBE_RIGHT + 2} ${SURFACE} H449`, "stroke-width": 1.2 }, group)

  // Le mélange gazeux, au-dessus de l'eau du tube.
  part("gas_mixture", "rect", { x: TUBE_LEFT + 1, y: TUBE_TOP + 1, width: TUBE_RIGHT - TUBE_LEFT - 2, height: WATER_LEVEL - TUBE_TOP - 1, texture: bubbles, stroke: "none" }, group)
  label(group, 320, 225, "H₂ + O₂", { size: 12 })

  // Les électrodes traversent le haut du tube ; l'étincelle jaillit entre leurs pointes.
  part("electrodes", "path", { d: `M308 52 V${SPARK_Y + 8} M332 52 V${SPARK_Y + 8}`, fill: "none", "stroke-width": 4 }, group)
  part("spark", "path", { d: "M324 88 L314 104 L321 104 L316 120 L330 100 L323 100 Z", fill: "accent", "stroke-width": 1 }, group)

  // La graduation, sur le bord droit du tube.
  const ticks = Array.from({ length: 12 }, (_, index) => `M${TUBE_RIGHT} ${130 + index * 20} H${index % 2 === 0 ? TUBE_RIGHT - 16 : TUBE_RIGHT - 9}`).join(" ")
  part("scale", "path", { d: ticks, fill: "none", "stroke-width": 1.5 }, group)

  part("tube", "path", { d: `M${TUBE_LEFT} ${TUBE_BOTTOM} V${TUBE_TOP} H${TUBE_RIGHT} V${TUBE_BOTTOM}`, fill: "none", "stroke-width": 2.5 }, group)
  part("trough", "path", { d: "M190 340 V420 H450 V340", fill: "none", "stroke-width": 2.5 }, group)
}
