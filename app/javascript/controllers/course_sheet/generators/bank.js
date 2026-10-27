// ⚡ FRONT · generators/bank — générateur « banque d'énoncés » de « Je m'entraîne » et règle numérique commune des fiches
// Rôle : tire un énoncé de la banque du document ; exporte parseNumber/isNumericCorrect/formatFr (même règle que Entities::Catalog::NumericAnswer)
// ADR  : XXXX-fiche-de-cours-en-donnees-importees (chantier contenu-en-blocs) · interface de générateur : create(block) → { next() → {text, answer, solution, unit, ask?} }

// Interface d'un générateur (Lot D : generators/thales_ratio.js l'implémente) : le fichier exporte `kind` (le `kind` du bloc `practice`)
// et `create(block)` qui rend un objet à méthode `next()`. `next()` rend { text, answer (nombre), solution, unit ("cm"), ask? ("AN") } ;
// `ask` est le libellé du champ (« AN = »), absent pour la banque. Tout est du texte brut : practice_controller l'écrit avec textContent.
export const kind = "bank"

export const TOLERANCE = 0.011
const NUMBER = /^[+-]?(\d+\.?\d*|\.\d+)$/

// « 3,6 », « 3.6 », « 3 , 6 », « −1,5 », « 3/5 » → nombre ; vide ou illisible → null.
export function parseNumber(input) {
  const text = String(input ?? "").replace(/\s/g, "").replace(/−/g, "-").replace(/,/g, ".")
  if (text === "") return null

  const parts = text.split("/")
  if (parts.length > 2 || !parts.every((part) => NUMBER.test(part))) return null

  const [numerator, denominator] = parts.map(Number)
  if (parts.length === 1) return numerator
  return denominator === 0 ? null : numerator / denominator
}

export function isNumericCorrect(input, expected, tolerance = TOLERANCE) {
  const value = parseNumber(input)
  return value !== null && Math.abs(value - expected) < tolerance
}

// Deux décimales au plus, virgule française : 3.6 → « 3,6 ».
export function formatFr(value) {
  return String(+Number(value).toFixed(2)).replace(".", ",")
}

export function create(block) {
  const items = Array.isArray(block?.bank) ? block.bank : []
  let previous = -1

  return {
    next() {
      if (items.length === 0) return null

      let index = Math.floor(Math.random() * items.length)
      if (items.length > 1 && index === previous) index = (index + 1 + Math.floor(Math.random() * (items.length - 1))) % items.length
      previous = index

      const item = items[index]
      return { text: item.prompt, answer: Number(item.answer), solution: item.solution, unit: "" }
    }
  }
}
