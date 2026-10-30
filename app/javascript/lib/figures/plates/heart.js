// ⚡ FRONT · lib/figures/plates/heart — la planche du cœur (coupe longitudinale, vue de face : le côté droit du cœur est à gauche de l'image)
// Rôle : déclare le titre, les 12 parties (nom français, ancre) et trace oreillettes, ventricules (paroi gauche plus épaisse), cloison, valvules, gros vaisseaux
// ADR  : XXXX-figures-des-matieres-de-3eme (§4.2 plate) · UDR : XXXX-figures-des-matieres-de-3eme (§3 plate) · lu par lib/figures/plate

export const TITLE = "Cœur (coupe longitudinale)"

export const PARTS = {
  right_atrium: { name: "oreillette droite", anchor: [256, 214] },
  left_atrium: { name: "oreillette gauche", anchor: [396, 218] },
  right_ventricle: { name: "ventricule droit", anchor: [285, 320] },
  left_ventricle: { name: "ventricule gauche", anchor: [362, 340] },
  septum: { name: "cloison", anchor: [333, 348] },
  aorta: { name: "aorte", anchor: [340, 200] },
  pulmonary_artery: { name: "artère pulmonaire", anchor: [306, 200] },
  superior_vena_cava: { name: "veine cave supérieure", anchor: [247, 100] },
  inferior_vena_cava: { name: "veine cave inférieure", anchor: [206, 350] },
  pulmonary_veins: { name: "veines pulmonaires", anchor: [446, 214] },
  tricuspid_valve: { name: "valvule auriculo-ventriculaire droite", anchor: [260, 252] },
  mitral_valve: { name: "valvule auriculo-ventriculaire gauche", anchor: [378, 256] }
}

export function draw(group, { el, sketch, part, tube, pattern }) {
  const muscle = pattern("muscle", 6, (node) => el("path", { d: "M0 6 L6 0", stroke: "muted", "stroke-width": 0.7 }, node))

  // Le muscle cardiaque : le contour des ventricules, hachuré ; les cavités le creusent, la paroi gauche reste plus épaisse.
  sketch("path", { d: "M226 246 C222 330 262 408 352 452 C414 412 432 340 424 246 Z", fill: "paper" }, group)
  sketch("path", { d: "M226 246 C222 330 262 408 352 452 C414 412 432 340 424 246 Z", stroke: "none" }, group).style.setProperty("fill", `url(#${muscle})`)
  part("right_ventricle", "path", { d: "M244 246 H316 C318 300 326 360 338 420 C278 384 242 320 244 246 Z" }, group)
  part("left_ventricle", "path", { d: "M330 246 H392 C396 320 380 392 352 420 C340 360 332 300 330 246 Z" }, group)
  part("septum", "path", { d: "M316 246 H330 C332 300 340 360 352 420 L338 420 C326 360 318 300 316 246 Z", texture: muscle }, group)

  // Valvules auriculo-ventriculaires : deux valves qui pendent dans le ventricule.
  part("tricuspid_valve", "path", { d: "M246 246 L264 246 L284 278 Z", fill: "paper" }, group)
  part("tricuspid_valve", "path", { d: "M316 246 L302 246 L290 276 Z", fill: "paper" }, group)
  part("mitral_valve", "path", { d: "M392 246 L376 246 L366 280 Z", fill: "paper" }, group)
  part("mitral_valve", "path", { d: "M360 246 L372 246 L362 278 Z", fill: "paper" }, group)

  // Les oreillettes, à paroi mince.
  part("right_atrium", "path", { d: "M224 246 H292 V196 C292 168 274 156 254 158 C232 160 218 182 220 210 C220 226 222 238 224 246 Z" }, group)
  part("left_atrium", "path", { d: "M360 246 H424 C430 220 424 192 402 182 C380 172 360 184 360 206 Z" }, group)

  // Les gros vaisseaux : tubes à bouts ouverts, qui débouchent dans les cavités.
  tube("inferior_vena_cava", "M206 430 V250 C206 232 214 226 232 226", 20, { cap: "butt" })
  tube("superior_vena_cava", "M247 50 V172", 20, { cap: "butt" })
  tube("pulmonary_veins", "M470 214 H414 M470 236 H416", 14, { cap: "butt" })
  tube("pulmonary_artery", "M306 258 V172 C306 156 318 150 336 150 C360 150 384 144 396 122 M306 172 C306 150 292 134 272 124", 16, { cap: "butt" })
  tube("aorta", "M340 258 V140 C340 98 386 84 418 104 C440 118 446 146 446 172", 22, { cap: "butt" })
}
