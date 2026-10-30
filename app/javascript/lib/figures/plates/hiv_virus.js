// ⚡ FRONT · lib/figures/plates/hiv_virus — la planche du VIH (virion en coupe)
// Rôle : déclare le titre, les 7 parties (nom français, ancre) et trace l'enveloppe (double trait) hérissée de spicules gp120/gp41, la matrice, la capside conique, l'ARN et la transcriptase inverse
// ADR  : XXXX-figures-des-matieres-de-3eme (§4.2 plate) · UDR : XXXX-figures-des-matieres-de-3eme (§3 plate) · lu par lib/figures/plate

export const TITLE = "Virus de l'immunodéficience humaine (VIH)"

const C = { x: 320, y: 252 }
const TILT = -20
const SCALE = 1.3
const SPIKES = 16

// Un point à `r` du centre, à `deg` degrés dans le sens horaire depuis le haut.
const polar = (r, deg) => [round(C.x + r * Math.sin((deg * Math.PI) / 180)), round(C.y - r * Math.cos((deg * Math.PI) / 180))]
// Un point du repère de la capside (centrée sur le virion, inclinée de TILT degrés, agrandie de SCALE).
const tilt = (x, y) => {
  const a = (TILT * Math.PI) / 180
  return [round(C.x + SCALE * (x * Math.cos(a) - y * Math.sin(a))), round(C.y + SCALE * (x * Math.sin(a) + y * Math.cos(a)))]
}
function round(value) {
  return Math.round(value * 10) / 10
}

export const PARTS = {
  envelope: { name: "enveloppe", anchor: polar(108, 292.5) },
  gp120: { name: "glycoprotéine gp120", anchor: polar(130, 326.25) },
  gp41: { name: "glycoprotéine gp41", anchor: polar(118, 33.75) },
  matrix: { name: "matrice protéique", anchor: polar(94, 247.5) },
  capsid: { name: "capside", anchor: tilt(-20.5, 10) },
  rna: { name: "ARN viral", anchor: tilt(8, -8) },
  reverse_transcriptase: { name: "transcriptase inverse", anchor: tilt(14, -14) }
}

const ring = (outer, inner) => `M${C.x - outer} ${C.y} a${outer} ${outer} 0 1 0 ${2 * outer} 0 a${outer} ${outer} 0 1 0 ${-2 * outer} 0 Z M${C.x - inner} ${C.y} a${inner} ${inner} 0 1 0 ${2 * inner} 0 a${inner} ${inner} 0 1 0 ${-2 * inner} 0 Z`

export function draw(group, { el, sketch, part, pattern }) {
  const lipid = pattern("lipid", 5, (node) => el("circle", { cx: 2.5, cy: 2.5, r: 0.8, fill: "muted" }, node))
  const protein = pattern("protein", 4, (node) => el("path", { d: "M0 4 L4 0", stroke: "muted", "stroke-width": 0.8 }, node))

  // L'enveloppe (double trait) et, juste dessous, la matrice protéique.
  part("envelope", "path", { d: ring(112, 103), "fill-rule": "evenodd", texture: lipid, "stroke-width": 1.8 }, group)
  part("matrix", "path", { d: ring(97, 90), "fill-rule": "evenodd", texture: protein }, group)

  // Les spicules : une tige gp41 qui traverse l'enveloppe, une tête gp120 à l'extérieur.
  for (let index = 0; index < SPIKES; index += 1) {
    const spike = el("g", { transform: `rotate(${(index + 0.5) * (360 / SPIKES)} ${C.x} ${C.y})` }, group)
    part("gp41", "rect", { x: C.x - 2.5, y: C.y - 124, width: 5, height: 34 }, spike)
    part("gp120", "ellipse", { cx: C.x, cy: C.y - 130, rx: 7.5, ry: 5.5 }, spike)
  }

  // La capside : un tronc de cône incliné, large au sommet, contenant deux brins d'ARN et des molécules de transcriptase inverse.
  const capsid = el("g", { transform: `rotate(${TILT} ${C.x} ${C.y}) translate(${C.x} ${C.y}) scale(${SCALE})` }, group)
  part("capsid", "path", { d: "M-35 -50 Q0 -58 35 -50 L12 54 Q0 58 -12 54 Z", "stroke-width": 2 }, capsid)
  sketch("path", { d: "M-31 -45 Q0 -52 31 -45 L9.5 49 Q0 52 -9.5 49 Z", "stroke-width": 0.9 }, capsid)
  part("rna", "path", { d: "M-22 -34 C-8 -28 -26 -16 -10 -8 C6 0 -20 12 -6 24 C0 30 -6 38 -4 44", fill: "none", "stroke-width": 2 }, capsid)
  part("rna", "path", { d: "M20 -34 C6 -28 24 -16 8 -8 C-8 0 18 12 4 24 C-2 30 4 38 2 44", fill: "none", "stroke-width": 2 }, capsid)
  ;[[-22, -24], [14, -14], [-8, 18], [8, 32]].forEach(([x, y]) => part("reverse_transcriptase", "ellipse", { cx: x, cy: y, rx: 6, ry: 4, fill: "ink", "fill-opacity": 0.6, "stroke-width": 1 }, capsid))
}
