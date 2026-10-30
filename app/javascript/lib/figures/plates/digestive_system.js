// ⚡ FRONT · lib/figures/plates/digestive_system — la planche de l'appareil digestif (vue de face, côté droit du sujet à gauche de l'image)
// Rôle : déclare le titre, les 11 parties (nom français, ancre) et trace le tube digestif continu bouche → anus avec ses glandes annexes
// ADR  : 0117-figures-des-matieres-de-3eme (§4.2 plate) · UDR : 0142-dessin-des-figures-de-3eme (§3 plate) · lu par lib/figures/plate

export const TITLE = "Appareil digestif"

export const PARTS = {
  mouth: { name: "bouche", anchor: [322, 96] },
  salivary_glands: { name: "glandes salivaires", anchor: [289, 101] },
  oesophagus: { name: "œsophage", anchor: [320, 150] },
  stomach: { name: "estomac", anchor: [372, 240] },
  liver: { name: "foie", anchor: [284, 220] },
  gallbladder: { name: "vésicule biliaire", anchor: [304, 263] },
  pancreas: { name: "pancréas", anchor: [360, 298] },
  small_intestine: { name: "intestin grêle", anchor: [330, 370] },
  large_intestine: { name: "gros intestin", anchor: [259, 370] },
  rectum: { name: "rectum", anchor: [317, 434] },
  anus: { name: "anus", anchor: [320, 448] }
}

export function draw(group, { part, tube, sketch }) {
  // Le sujet : tête, cou, tronc.
  sketch("ellipse", { cx: 320, cy: 76, rx: 31, ry: 39, fill: "paper" }, group)
  sketch("path", { d: "M306 108 L306 128 M334 108 L334 128" }, group)
  sketch("path", { d: "M306 126 C270 130 232 134 224 162 C216 202 226 262 236 322 C240 362 244 410 250 462 L390 462 C396 410 400 362 404 322 C414 262 424 202 416 162 C408 134 370 130 334 126", fill: "paper" }, group)
  sketch("path", { d: "M309 68 h4 M327 68 h4 M320 74 v7", "stroke-width": 2 }, group)

  tube("oesophagus", "M320 102 V160 C320 180 326 192 338 202", 8, group)
  part("salivary_glands", "ellipse", { cx: 289, cy: 101, rx: 7, ry: 11 }, group)
  part("salivary_glands", "ellipse", { cx: 351, cy: 101, rx: 7, ry: 11 }, group)
  part("mouth", "path", { d: "M306 96 Q320 90 334 96 Q320 108 306 96 Z" }, group)
  sketch("path", { d: "M306 96 Q320 98 334 96", "stroke-width": 1 }, group)

  // Le gros intestin en cadre (ascendant, transverse, descendant) puis le sigmoïde ; le grêle passe devant.
  tube("large_intestine", "M259 408 V338 Q259 323 274 323 H366 Q381 323 381 338 V400 C381 432 345 440 320 428", 12, group)
  part("pancreas", "path", { d: "M326 291 C340 283 368 283 388 289 C393 298 384 306 370 308 C352 310 336 310 326 308 Z" }, group)
  part("liver", "path", { d: "M250 200 C268 186 310 186 334 202 C338 216 330 232 316 242 C296 252 270 250 258 236 C248 224 246 210 250 200 Z" }, group)
  part("gallbladder", "path", { d: "M300 246 C312 246 314 260 309 271 C305 278 298 274 297 263 C296 254 297 248 300 246 Z" }, group)
  part("stomach", "path", { d: "M334 200 C350 190 380 196 386 226 C392 258 376 288 346 288 C332 288 322 282 320 274 C326 266 336 270 344 264 C356 254 352 236 342 226 C336 220 332 212 334 200 Z" }, group)
  tube("small_intestine", "M322 278 C314 292 306 304 306 322 V340 H284 a7.5 7.5 0 0 0 0 15 H352 a7.5 7.5 0 0 1 0 15 H284 a7.5 7.5 0 0 0 0 15 H352 a7.5 7.5 0 0 1 0 15 H284 a7.5 7.5 0 0 0 0 15 H262", 8, group)
  tube("rectum", "M320 427 V441", 11, group)
  part("anus", "ellipse", { cx: 320, cy: 448, rx: 8, ry: 4.5 }, group)
}
