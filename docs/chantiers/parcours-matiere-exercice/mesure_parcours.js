// Mesure du parcours « grille des matières → exercice » (chantier parcours-matiere-exercice).
// Usage : node docs/chantiers/parcours-matiere-exercice/mesure_parcours.js [base_url] [contact] [dossier_captures]
// Prérequis : bin/rails s sur base_url (défaut http://localhost:3000), seeds de démo
// (db/seeds/demo/trois_etablissements.rb puis db/seeds/demo/lecons_completes.rb) ; élève de 3e 0131001001, PIN 2468.
// Pour chaque largeur (390 px et 1280 px), suit le chemin le plus court d'un élève qui veut faire un exercice de Maths, et
// rend : le nombre de clics de la grille jusqu'à la feuille de l'exercice en cours, et, par écran intermédiaire, les mots
// visibles (texte rendu de <main>), les mots lus avant la cible du clic suivant et la hauteur à défiler pour l'atteindre.
const { chromium } = require("playwright")

const base = process.argv[2] || "http://localhost:3000"
const contact = process.argv[3] || "0131001001"
const shots = process.argv[4]
const SUBJECT = "mathematiques"
// MODE=lecon : l'élève choisit une leçon au lieu du raccourci de la matière (mesure l'écran de la leçon).
const viaLesson = process.env.MODE === "lecon"

const words = (text) => text.split(/\s+/).filter((w) => /[\p{L}\p{N}]/u.test(w)).length

// Mots rendus dans <main> (hors sr-only et éléments masqués), et mots situés avant la cible dans l'ordre du document.
async function measure(page, target) {
  return page.evaluate((selector) => {
    const main = document.querySelector("main") || document.body
    const target = selector ? document.querySelector(selector) : null
    const walker = document.createTreeWalker(main, NodeFilter.SHOW_TEXT)
    const visible = (el) => {
      for (let e = el; e && e !== document.body; e = e.parentElement) {
        const s = getComputedStyle(e)
        if (s.display === "none" || s.visibility === "hidden" || e.hidden) return false
        if (s.position === "absolute" && s.clip === "rect(0px, 0px, 0px, 0px)") return false
        if (e.classList && e.classList.contains("sr-only")) return false
        if (e.tagName === "TEMPLATE") return false
      }
      return true
    }
    let all = [], before = [], passed = false
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
      if (!node.textContent.trim() || !visible(node.parentElement)) continue
      if (target && !passed && target.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING) passed = true
      all.push(node.textContent)
      if (!passed) before.push(node.textContent)
    }
    const y = target ? target.getBoundingClientRect().top + window.scrollY : null
    return { all: all.join(" "), before: before.join(" "), targetY: y, viewport: window.innerHeight }
  }, target)
}

async function step(page, name, target, log) {
  await page.waitForLoadState("networkidle")
  const m = await measure(page, target)
  const row = { screen: name, url: new URL(page.url()).pathname + new URL(page.url()).search,
                words: words(m.all), wordsBeforeTarget: target ? words(m.before) : null,
                scrollToTarget: target ? Math.max(0, Math.round(m.targetY - m.viewport + 60)) : null }
  log.push(row)
  if (shots) await page.screenshot({ path: `${shots}/${log.width}-${log.length}-${name}.png`, fullPage: false })
  return row
}

async function run(width, height) {
  const browser = await chromium.launch()
  const page = await browser.newPage({ viewport: { width, height } })
  await page.goto(`${base}/login`)
  await page.fill("#session_contact", contact)
  await page.fill("#session_pin", "2468")
  await Promise.all([page.waitForURL(/students/), page.click("form button[type=submit]")])
  const log = []
  log.width = width
  let clicks = 0
  // Le chemin : chaque cible est la première qui existe dans la page, dans l'ordre donné (raccourci d'abord).
  const path = [
    ["accueil", [`#subject_${SUBJECT}`]],
    ["matiere", [...(viaLesson ? [] : ["#material_next_exercise a, #material_next_exercise button",
                                        "#lesson_material_next_exercise a, #lesson_material_next_exercise button"]),
                 "#lessons_list li[id^=lesson_essential_] a", "#courses_groups a[href*='/courses/']"]],
    ["lecon", ["#lesson_next_exercise button, #lesson_next_exercise a[href*='/sessions/']", "#prepare-interros a[href*='/exercises/']"]],
    ["exercice", ["#start-exercise-form button", "a[href*='/sessions/']"]],
  ]
  for (const [name, selectors] of path) {
    if (/\/sessions\//.test(page.url())) break
    await page.waitForTimeout(800)
    let target = null
    for (const s of selectors) if (await page.locator(s).first().isVisible().catch(() => false)) { target = s; break }
    if (!target) { await step(page, name, null, log); break }
    await step(page, name, target, log)
    await page.locator(target).first().scrollIntoViewIfNeeded()
    const before = page.url()
    await page.locator(target).first().click()
    await page.waitForURL((url) => url.toString() !== before, { timeout: 15000 })
    await page.waitForLoadState("networkidle")
    clicks += 1
  }
  const reached = /\/sessions\//.test(page.url())
  await browser.close()
  return { width, clicks, reached, screens: log }
}

;(async () => {
  for (const [w, h] of [[390, 844], [1280, 800]]) console.log(JSON.stringify(await run(w, h)))
})()
