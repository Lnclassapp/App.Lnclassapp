// ⚡ FRONT · lib/figures/plates/dynamometer — la planche du dynamomètre à ressort (vue de face, vertical, anneau en haut)
// Rôle : déclare le titre, les 7 parties (nom français, ancre) et trace l'anneau, le tube, le ressort, la graduation en N, l'index devant la graduation, le crochet et le corps suspendu
// ADR  : 0117-figures-des-matieres-de-3eme (§4.2 plate) · UDR : 0142-dessin-des-figures-de-3eme (§3 plate) · lu par lib/figures/plate

export const TITLE = "Dynamomètre à ressort"

const AXIS = 304
const TICK_TOP = 120
const TICK_STEP = 22
const TICKS = 8
const POINTER_Y = TICK_TOP + 4 * TICK_STEP
const SPRING_TOP = 96
const SPRING_STEPS = 8

// Le ressort : un zigzag régulier de l'anneau de tête jusqu'à l'index (le ressort étiré par une force de 4 N).
const SPRING = Array.from({ length: SPRING_STEPS }, (_, index) => [AXIS + (index % 2 === 0 ? 9 : -9), SPRING_TOP + (index + 1) * ((POINTER_Y - SPRING_TOP) / SPRING_STEPS)])

export const PARTS = {
  ring: { name: "anneau", anchor: [AXIS - 16, 62] },
  tube: { name: "tube", anchor: [268, 250] },
  spring: { name: "ressort", anchor: SPRING[3] },
  scale: { name: "graduation (en N)", anchor: [342, 150] },
  pointer: { name: "index", anchor: [328, POINTER_Y] },
  hook: { name: "crochet", anchor: [AXIS, 345] },
  load: { name: "corps suspendu", anchor: [344, 405] }
}

export function draw(group, { sketch, part, label }) {
  // Le tube, creux, qui protège le ressort ; la graduation est portée par une fenêtre à droite.
  part("tube", "rect", { x: 268, y: 90, width: 76, height: 210, rx: 8 }, group)
  sketch("path", { d: `M${AXIS} 78 V90` }, group)

  part("scale", "rect", { x: 318, y: 110, width: 24, height: 172 }, group)
  const ticks = Array.from({ length: TICKS }, (_, index) => `M318 ${TICK_TOP + index * TICK_STEP} H${index % 2 === 0 ? 330 : 325}`).join(" ")
  sketch("path", { d: ticks, "stroke-width": 1.2 }, group)
  for (let index = 0; index < TICKS; index += 1) label(group, 340, TICK_TOP + index * TICK_STEP + 4, String(index), { anchor: "end", size: 9 })
  label(group, 330, 106, "N", { size: 10 })

  // Le ressort, puis la tige qui descend de son extrémité, traverse le fond du tube et porte l'index, le crochet et le corps.
  part("spring", "path", { d: `M${AXIS} ${SPRING_TOP} ${SPRING.map(([x, y]) => `L${x} ${y}`).join(" ")} L${AXIS} ${POINTER_Y}`, fill: "none", "stroke-width": 2 }, group)
  sketch("path", { d: `M${AXIS} ${POINTER_Y} V338`, "stroke-width": 2.5 }, group)
  part("pointer", "path", { d: `M${AXIS} ${POINTER_Y - 4} L328 ${POINTER_Y} L${AXIS} ${POINTER_Y + 4} Z`, fill: "accent", "stroke-width": 1 }, group)

  part("ring", "circle", { cx: AXIS, cy: 62, r: 16, fill: "none", "stroke-width": 3 }, group)
  part("hook", "path", { d: `M${AXIS} 338 V352 A10 10 0 0 0 ${AXIS + 20} 352`, fill: "none", "stroke-width": 3 }, group)

  // Le corps suspendu : une masse marquée, accrochée au creux du crochet.
  sketch("path", { d: `M${AXIS + 10} 362 V378` }, group)
  part("load", "rect", { x: 282, y: 378, width: 62, height: 54, rx: 5 }, group)
  sketch("path", { d: "M294 392 H332 M294 404 H332", "stroke-width": 1 }, group)
}
