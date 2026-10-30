// ⚡ FRONT · lib/figures/plates/female_reproductive_system — la planche de l'appareil reproducteur féminin (vue de face)
// Rôle : déclare le titre, les 7 parties (nom français, ancre) et trace l'utérus (paroi épaisse, muqueuse), les deux trompes à pavillon frangé, les ovaires, le col et le vagin
// ADR  : XXXX-figures-des-matieres-de-3eme (§4.2 plate) · UDR : XXXX-figures-des-matieres-de-3eme (§3 plate) · lu par lib/figures/plate

export const TITLE = "Appareil reproducteur féminin"

export const PARTS = {
  ovary: { name: "ovaire", anchor: [194, 254] },
  oviduct: { name: "trompe (oviducte)", anchor: [228, 166] },
  infundibulum: { name: "pavillon", anchor: [194, 214] },
  uterus: { name: "utérus", anchor: [367, 205] },
  endometrium: { name: "muqueuse utérine", anchor: [322, 216] },
  cervix: { name: "col de l'utérus", anchor: [330, 298] },
  vagina: { name: "vagin", anchor: [332, 392] }
}

export function draw(group, { el, sketch, part, tube, pattern }) {
  const wall = pattern("wall", 6, (node) => el("path", { d: "M0 6 L6 0", stroke: "muted", "stroke-width": 0.7 }, node))
  const lining = pattern("lining", 5, (node) => el("circle", { cx: 2.5, cy: 2.5, r: 0.9, fill: "muted" }, node))

  part("vagina", "path", { d: "M296 316 C294 360 294 410 298 446 M344 316 C346 360 346 410 342 446 M296 316 H344", fill: "paper" }, group)
  part("uterus", "path", { d: "M258 178 C262 160 290 152 320 152 C350 152 378 160 382 178 C384 222 352 266 338 300 H302 C288 266 256 222 258 178 Z", texture: wall }, group)
  part("endometrium", "path", { d: "M283 188 C298 178 342 178 357 188 L331 266 Q320 278 309 266 Z", texture: lining, "stroke-width": 1.8 }, group)
  part("cervix", "path", { d: "M303 272 C305 266 335 266 337 272 L340 316 C330 324 310 324 300 316 Z" }, group)
  sketch("path", { d: "M320 270 V318", "stroke-width": 1, "stroke-dasharray": "2 3" }, group)

  // Une trompe, un pavillon frangé et un ovaire de chaque côté : le côté gauche de l'image est dessiné, le droit en miroir.
  ;[1, -1].forEach((side) => {
    const x = (value) => (side === 1 ? value : 640 - value)
    tube("oviduct", `M${x(264)} 186 C${x(246)} 176 ${x(230)} 162 ${x(212)} 164 C${x(198)} 166 ${x(192)} 182 ${x(194)} 200`, 9, { cap: "butt" })
    part("infundibulum", "path", { d: `M${x(188)} 203 L${x(200)} 203 L${x(214)} 224 L${x(174)} 224 Z` }, group)
    ;[176, 184, 194, 204, 212].forEach((fringe, index) => {
      part("infundibulum", "path", { d: `M${x(fringe)} 224 q${side * (index - 2) * -1.5} 6 ${side * (index - 2) * -1} 12`, fill: "none", "stroke-width": 1.5 }, group)
    })
    part("ovary", "ellipse", { cx: x(194), cy: 254, rx: 22, ry: 16 }, group)
    ;[[186, 250, 4.5], [201, 259, 3.5], [207, 247, 3]].forEach(([cx, cy, r]) => sketch("circle", { cx: x(cx), cy, r, "stroke-width": 1 }, group))
  })
}
