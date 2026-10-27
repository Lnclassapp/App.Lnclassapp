// ⚡ FRONT · generators/thales_ratio — générateur « Entraînement illimité » de la fiche Thalès : un énoncé de proportionnalité tiré au hasard
// Rôle : tire une configuration (triangle ou papillon), un rapport k et la longueur à calculer (AN, MN ou AC) ; mêmes listes et mêmes textes que la maquette (genNew)
// ADR  : XXXX-fiche-de-cours-en-donnees-importees (chantier contenu-en-blocs) · interface : voir generators/bank.js (create(block) → { next() → {text, answer, solution, unit, ask} })
import { formatFr } from "./bank"

export const kind = "thales_ratio"

const RATIOS = [0.25, 0.4, 0.5, 0.6, 0.75, 0.8]
const AB_LENGTHS = [5, 6, 8, 10, 12, 15, 20]
const AC_LENGTHS = [4, 5, 6, 8, 9, 10, 12, 15]
const BC_LENGTHS = [3, 4, 5, 6, 7, 8, 9, 10, 12]
const UNKNOWNS = ["AN", "MN", "AC"]

const pick = (list) => list[Math.floor(Math.random() * list.length)]
const twoDecimals = (value) => +value.toFixed(2)

// Un énoncé : { text, answer, solution, unit, ask }, tout en texte brut (practice_controller l'écrit avec textContent).
function draw() {
  const butterfly = Math.random() < 0.5
  const k = pick(RATIOS)
  const AB = pick(AB_LENGTHS)
  const AC = pick(AC_LENGTHS)
  const BC = pick(BC_LENGTHS)
  const AM = twoDecimals(k * AB)
  const AN = twoDecimals(k * AC)
  const MN = twoDecimals(k * BC)
  const ask = pick(UNKNOWNS)
  const position = butterfly ? "A est entre B et M, et entre C et N." : "M appartient à [AB] et N appartient à [AC]."
  const [fAM, fAB, fAC, fBC, fAN, fMN] = [AM, AB, AC, BC, AN, MN].map(formatFr)
  let given
  let answer
  let solution

  if (ask === "AN") {
    given = `AM = ${fAM} cm, AB = ${fAB} cm, AC = ${fAC} cm et BC = ${fBC} cm`
    answer = AN
    solution = `AM/AB = AN/AC, soit ${fAM}/${fAB} = AN/${fAC}. Donc AN = ${fAM} × ${fAC} ÷ ${fAB} = ${fAN} cm.`
  } else if (ask === "MN") {
    given = `AM = ${fAM} cm, AB = ${fAB} cm, AC = ${fAC} cm et BC = ${fBC} cm`
    answer = MN
    solution = `AM/AB = MN/BC, soit ${fAM}/${fAB} = MN/${fBC}. Donc MN = ${fAM} × ${fBC} ÷ ${fAB} = ${fMN} cm.`
  } else {
    given = `AM = ${fAM} cm, AB = ${fAB} cm et AN = ${fAN} cm`
    answer = AC
    solution = `AM/AB = AN/AC, soit ${fAM}/${fAB} = ${fAN}/AC. Donc AC = ${fAN} × ${fAB} ÷ ${fAM} = ${fAC} cm.`
  }

  const text = `Configuration ${butterfly ? "papillon" : "triangle"}. Les droites (BM) et (CN) sont sécantes en A et (MN) // (BC). ${position} On donne ${given}. Calculer ${ask}.`
  return { text, answer, solution, unit: "cm", ask }
}

export function create() {
  return { next: draw }
}
