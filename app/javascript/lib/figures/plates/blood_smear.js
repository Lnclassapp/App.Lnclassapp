// ⚡ FRONT · lib/figures/plates/blood_smear — la planche du frottis sanguin (champ de microscope)
// Rôle : déclare le titre, les 6 parties (nom français, ancre) et trace des hématies sans noyau, trois leucocytes (noyau plurilobé, rond, en haricot), des plaquettes dans le plasma
// ADR  : 0117-figures-des-matieres-de-3eme (§4.2 plate) · UDR : 0142-dessin-des-figures-de-3eme (§3 plate) · lu par lib/figures/plate

export const TITLE = "Frottis sanguin (au microscope)"

const FIELD = { x: 320, y: 252, r: 150 }
const NEUTROPHIL = { x: 262, y: 196, r: 23 }
const LYMPHOCYTE = { x: 394, y: 214, r: 18 }
const MONOCYTE = { x: 336, y: 330, r: 29 }
const PLATELETS = [[372, 150], [246, 322], [412, 292], [306, 196], [276, 262], [380, 360], [232, 232]]
const FIRST_RED = [246, 282]
const GAP = [440, 262]

// Des hématies (disques de 13 à 15 unités de rayon) posées sur une grille irrégulière, à l'écart des leucocytes, des plaquettes et du point d'ancre du plasma.
function reds() {
  let seed = 7
  const next = () => {
    seed = (seed * 48271) % 2147483647
    return seed / 2147483647
  }
  const others = [NEUTROPHIL, LYMPHOCYTE, MONOCYTE]
  const cells = [{ x: FIRST_RED[0], y: FIRST_RED[1], r: 16 }]
  for (let y = FIELD.y - 130; y <= FIELD.y + 130; y += 29) {
    for (let x = FIELD.x - 140; x <= FIELD.x + 140; x += 31) {
      const r = 13 + Math.round(next() * 2)
      const c = { x: x + (next() - 0.5) * 6 + (Math.round((y - FIELD.y) / 29) % 2) * 15, y: y + (next() - 0.5) * 5, r }
      const inside = Math.hypot(c.x - FIELD.x, c.y - FIELD.y) <= FIELD.r - r - 3
      const clear = others.every((o) => Math.hypot(c.x - o.x, c.y - o.y) >= o.r + r + 4)
        && PLATELETS.every(([px, py]) => Math.hypot(c.x - px, c.y - py) >= r + 7)
        && Math.hypot(c.x - GAP[0], c.y - GAP[1]) >= r + 14
      const free = cells.every((o) => Math.hypot(c.x - o.x, c.y - o.y) >= o.r + r + 1.5)
      if (inside && clear && free) cells.push(c)
    }
  }
  return cells
}

export const PARTS = {
  red_blood_cell: { name: "hématie", anchor: [FIRST_RED[0] + 9, FIRST_RED[1]] },
  neutrophil: { name: "polynucléaire", anchor: [NEUTROPHIL.x - 14, NEUTROPHIL.y + 8] },
  lymphocyte: { name: "lymphocyte", anchor: [LYMPHOCYTE.x + 6, LYMPHOCYTE.y + 4] },
  monocyte: { name: "monocyte", anchor: [MONOCYTE.x + 17, MONOCYTE.y + 12] },
  platelet: { name: "plaquette sanguine", anchor: [PLATELETS[0][0], PLATELETS[0][1]] },
  plasma: { name: "plasma", anchor: [GAP[0], GAP[1]] }
}

export function draw(group, { highlighted, el, sketch, part, pattern }) {
  const dots = pattern("grain", 5, (node) => el("circle", { cx: 2.5, cy: 2.5, r: 0.8, fill: "ink", "fill-opacity": 0.55 }, node))
  const sparse = pattern("sparse", 7, (node) => el("circle", { cx: 3.5, cy: 3.5, r: 0.9, fill: "muted" }, node))

  part("plasma", "circle", { cx: FIELD.x, cy: FIELD.y, r: FIELD.r, "stroke-width": 2.5 }, group)

  // Les hématies : disques biconcaves sans noyau, bord plus dense, centre plus clair.
  reds().forEach(({ x, y, r }) => {
    sketch("circle", { cx: x, cy: y, r, fill: "paper", stroke: "none" }, group)
    part("red_blood_cell", "circle", { cx: x, cy: y, r, texture: sparse }, group)
    sketch("circle", { cx: x, cy: y, r: r * 0.45, fill: highlighted.has("red_blood_cell") ? "none" : "paper", stroke: "muted", "stroke-width": 0.8 }, group)
  })

  PLATELETS.forEach(([x, y]) => {
    part("platelet", "path", { d: `M${x - 4} ${y - 1} L${x - 1} ${y - 4} L${x + 3} ${y - 3} L${x + 5} ${y + 1} L${x + 1} ${y + 4} L${x - 3} ${y + 3} Z`, fill: "ink", "fill-opacity": 0.5, "stroke-width": 1 }, group)
  })

  // Polynucléaire : cytoplasme granuleux, noyau en trois lobes reliés.
  const n = NEUTROPHIL
  sketch("circle", { cx: n.x, cy: n.y, r: n.r, fill: "paper", stroke: "none" }, group)
  part("neutrophil", "circle", { cx: n.x, cy: n.y, r: n.r, texture: dots }, group)
  sketch("path", { d: `M${n.x - 9} ${n.y - 3} L${n.x + 2} ${n.y + 7} L${n.x + 10} ${n.y - 6}`, "stroke-width": 2.5 }, group)
  ;[[-9, -3], [2, 7], [10, -6]].forEach(([dx, dy]) => sketch("circle", { cx: n.x + dx, cy: n.y + dy, r: 6.5, fill: "ink", "fill-opacity": 0.6 }, group))

  // Lymphocyte : un gros noyau rond qui occupe presque toute la cellule.
  const l = LYMPHOCYTE
  part("lymphocyte", "circle", { cx: l.x, cy: l.y, r: l.r }, group)
  sketch("circle", { cx: l.x, cy: l.y, r: l.r - 3.5, fill: "ink", "fill-opacity": 0.6 }, group)

  // Monocyte : la plus grosse cellule, noyau en haricot.
  const m = MONOCYTE
  part("monocyte", "circle", { cx: m.x, cy: m.y, r: m.r }, group)
  sketch("path", { d: `M${m.x - 18} ${m.y - 6} C${m.x - 14} ${m.y - 20} ${m.x + 10} ${m.y - 22} ${m.x + 18} ${m.y - 6} C${m.x + 22} ${m.y + 4} ${m.x + 12} ${m.y + 8} ${m.x + 6} ${m.y + 2} C${m.x + 2} ${m.y - 4} ${m.x - 6} ${m.y - 2} ${m.x - 8} ${m.y + 8} C${m.x - 12} ${m.y + 14} ${m.x - 20} ${m.y + 6} ${m.x - 18} ${m.y - 6} Z`, fill: "ink", "fill-opacity": 0.6 }, group)
}
