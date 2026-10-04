// Mesure navigateur (chantier politique-cache) : ce que la personne attend vraiment, du clic à la page chargée, sur
// des pages publiques (sans compte). Chromium headless, via Playwright installé globalement :
//
//   NODE_PATH=$(npm root -g) node script/perf/measure_browser.cjs                 # https://lnclass.com
//   NODE_PATH=$(npm root -g) node script/perf/measure_browser.cjs https://app-develop.lnclass.com
//
// Par page : PERF_RUNS (10 par défaut) visites dans un navigateur neuf (première visite : cache vide), puis autant de
// visites répétées dans le même navigateur (assets en cache). On lit la Navigation Timing de la page : premier octet
// du HTML, DOMContentLoaded, load, et les ressources téléchargées hors cache. Le script se lance 3 fois ; on retient la
// médiane des 3. HTTPS_PROXY, s'il est défini, est passé à Chromium. Écrit tmp/perf-browser.json.
const { chromium } = require("playwright")
const fs = require("fs")

const BASE = process.argv[2] || "https://lnclass.com"
const RUNS = Number(process.env.PERF_RUNS || 10)
const PATHS = ["/", "/login"]

const median = (values) => {
  const sorted = [...values].sort((a, b) => a - b)
  return sorted[Math.round((sorted.length - 1) * 0.5)]
}

async function visit(page, url) {
  await page.goto(url, { waitUntil: "load" })
  return page.evaluate(() => {
    const nav = performance.getEntriesByType("navigation")[0]
    const fetched = performance.getEntriesByType("resource").filter((entry) => entry.transferSize > 0)
    return { ttfb: nav.responseStart, dcl: nav.domContentLoadedEventEnd, load: nav.loadEventEnd, fetched: fetched.length }
  })
}

async function measure(browser, path) {
  const first = []
  const repeat = []
  for (let i = 0; i < RUNS; i++) {
    const context = await browser.newContext()
    const page = await context.newPage()
    first.push(await visit(page, BASE + path))
    repeat.push(await visit(page, BASE + path))
    await context.close()
  }
  const summarize = (samples) => Object.fromEntries(
    ["ttfb", "dcl", "load", "fetched"].map((key) => [key, Math.round(median(samples.map((sample) => sample[key])))])
  )
  return { path, first: summarize(first), repeat: summarize(repeat) }
}

async function main() {
  const proxy = process.env.HTTPS_PROXY ? { server: process.env.HTTPS_PROXY } : undefined
  const browser = await chromium.launch({ proxy })
  const results = []
  for (const path of PATHS) results.push(await measure(browser, path))
  await browser.close()

  console.log(`Cible : ${BASE} · ${RUNS} visites par ligne · ${new Date().toISOString()}\n`)
  console.log("| Page | Visite | Premier octet ms | DOMContentLoaded ms | load ms | Ressources hors cache |")
  console.log("|---|---|--:|--:|--:|--:|")
  for (const row of results) {
    for (const [label, values] of [["première (cache vide)", row.first], ["répétée (cache chaud)", row.repeat]]) {
      console.log(`| ${row.path} | ${label} | ${values.ttfb} | ${values.dcl} | ${values.load} | ${values.fetched} |`)
    }
  }
  fs.mkdirSync("tmp", { recursive: true })
  fs.writeFileSync("tmp/perf-browser.json", JSON.stringify({ target: BASE, results }, null, 2))
}

main()
