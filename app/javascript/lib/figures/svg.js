// ⚡ FRONT · lib/figures/svg — les nœuds SVG des figures : createElementNS et textContent, couleurs lues dans les variables CSS
// Rôle : `el` crée un nœud, `fixed` écrit un nombre à la française, `hitRadius` donne une zone de toucher de 48 px à l'écran
// ADR  : XXXX-fiche-de-revision-par-notion-et-figures-parametrees (§4.2, menace) · UDR : XXXX-fiche-de-revision-en-quatre-blocs (§3.3, §3.6)

const NS = "http://www.w3.org/2000/svg"

// Les seules couleurs d'une figure : les jetons du cahier, ou à défaut ceux de l'application (hors cahier).
export const COLOR = {
  ink: "var(--sheet-ink, var(--color-ink))",
  muted: "var(--sheet-muted, var(--color-mute))",
  primary: "var(--sheet-primary, var(--color-brand-strong))",
  accent: "var(--sheet-accent, var(--color-error))",
  success: "var(--sheet-success, var(--color-success))",
  grid: "var(--sheet-field-border, var(--color-line-strong))",
  paper: "var(--sheet-white, var(--color-paper))",
  none: "none"
}

const PAINTS = ["stroke", "fill"]

// Un nœud SVG. `stroke` et `fill` prennent un nom de COLOR (jamais une couleur) ; `text` écrit le contenu par textContent.
export function el(tag, attrs = {}, parent = null) {
  const node = document.createElementNS(NS, tag)
  for (const [name, value] of Object.entries(attrs)) {
    if (PAINTS.includes(name)) node.style.setProperty(name, COLOR[value] ?? COLOR.none)
    else if (name === "text") node.textContent = String(value)
    else node.setAttribute(name, String(value))
  }
  parent?.appendChild(node)
  return node
}

export function root(width, height) {
  const svg = el("svg", { viewBox: `0 0 ${width} ${height}`, preserveAspectRatio: "xMidYMid meet", focusable: "false" })
  svg.style.touchAction = "none"
  svg.style.userSelect = "none"
  return svg
}

// Une étiquette lisible sur tout fond : un halo de la couleur du papier.
export function label(parent, x, y, text, { anchor = "middle", tone = "ink", size = 13 } = {}) {
  const node = el("text", { x: round(x), y: round(y), "text-anchor": anchor, "font-size": size, fill: tone, text }, parent)
  node.style.paintOrder = "stroke"
  // Le contrôleur agrandit le texte quand la figure est affichée petite (téléphone) : --figure-text, de 1 à 1,4.
  node.style.fontSize = `calc(${size}px * var(--figure-text, 1))`
  node.style.stroke = COLOR.paper
  node.style.strokeWidth = "3px"
  node.style.fontFamily = "inherit"
  return node
}

export const round = (value) => Math.round(value * 100) / 100

// Un nombre à la française, deux décimales au plus (la décimale fixe si `digits` est donné), signe moins typographique.
export function fixed(value, digits = null) {
  const text = digits === null ? String(round(value)) : value.toFixed(digits)
  return text.replace(".", ",").replace("-", "−")
}

// Rayon (unités du dessin) d'une zone de toucher de 48 px de diamètre pour un dessin de `width` unités affiché sur `shown` px.
export function hitRadius(width, shown) {
  const scale = shown > 0 ? width / shown : 1
  return round(Math.max(24 * scale, 12))
}

export function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value))
}
