// Mesure navigateur des pages par rôle (chantier pages-sous-600ms) : les pages relevées par script/mesure/pages.rb
// (tmp/mesure-pages.json), ouvertes dans Chromium à 390 px, sur l'application lancée en production locale par
// script/mesure/pages --navigateur. Playwright installé globalement :
//
//   NODE_PATH=$(npm root -g) node script/mesure/pages_navigateur.cjs http://localhost:3999
//
// Par rôle, MESURE_NAV_PASSES (3) passes, chacune dans un navigateur neuf (cache vide) : connexion par le formulaire,
// puis chaque page ouverte par une navigation complète. La première page d'une passe paie les assets (« à froid »),
// les suivantes les trouvent en cache. Par page : octets transférés (HTML et ressources hors cache), DOMContentLoaded et
// load ; médiane des passes. Écrit tmp/mesure-pages-navigateur.json.
const { chromium } = require("playwright")
const fs = require("fs")

const base = process.argv[2] || "http://localhost:3999"
const passes = Number(process.env.MESURE_NAV_PASSES || 3)
const data = JSON.parse(fs.readFileSync("tmp/mesure-pages.json", "utf8"))
const median = (values) => values.slice().sort((a, b) => a - b)[Math.floor((values.length - 1) / 2)]

async function timing(page) {
  return page.evaluate(() => {
    const [nav] = performance.getEntriesByType("navigation")
    const resources = performance.getEntriesByType("resource")
    const bytes = nav.transferSize + resources.reduce((sum, r) => sum + (r.transferSize || 0), 0)
    return { bytes, dcl: nav.domContentLoadedEventEnd, load: nav.loadEventEnd, requests: 1 + resources.filter((r) => r.transferSize > 0).length }
  })
}

async function signIn(page, contact) {
  await page.goto(`${base}/login`)
  await page.fill("input[name='session[contact]']", contact)
  await page.fill("input[name='session[pin]']", data.pin)
  await Promise.all([page.waitForURL((url) => !url.pathname.startsWith("/login")), page.press("input[name='session[pin]']", "Enter")])
}

async function passFor(browser, role, rows) {
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true })
  const page = await context.newPage()
  if (role !== "visiteur") await signIn(page, data.accounts[role])
  const out = {}
  for (const row of rows) {
    await page.goto(`${base}${row.path}`, { waitUntil: "load" })
    await page.waitForTimeout(50)
    out[row.page] = await timing(page)
  }
  await context.close()
  return out
}

;(async () => {
  const browser = await chromium.launch()
  const results = []
  const roles = [...new Set(data.rows.map((row) => row.role))]
  for (const role of roles) {
    // Un cadre Turbo (en-tête Turbo-Frame) n'est pas une page : il n'est pas ouvert dans le navigateur.
    const rows = data.rows.filter((row) => row.role === role && !Object.keys(row.headers || {}).length)
    const runs = []
    for (let i = 0; i < passes; i++) runs.push(await passFor(browser, role, rows))
    rows.forEach((row, index) => {
      const pick = (key) => median(runs.map((run) => run[row.page][key]))
      results.push({ role, page: row.page, froid: index === 0, ko: Math.round(pick("bytes") / 102.4) / 10, requetes: pick("requests"), dcl: Math.round(pick("dcl")), load: Math.round(pick("load")) })
    })
  }
  await browser.close()
  console.log("| Rôle | Page | Ko transférés | Requêtes réseau | DOMContentLoaded ms | load ms |")
  console.log("|---|---|--:|--:|--:|--:|")
  for (const r of results) console.log(`| ${r.role} | ${r.page}${r.froid ? " (cache vide)" : ""} | ${r.ko} | ${r.requetes} | ${r.dcl} | ${r.load} |`)
  fs.writeFileSync("tmp/mesure-pages-navigateur.json", JSON.stringify(results, null, 2))
})().catch((error) => {
  console.error(error)
  process.exit(1)
})
