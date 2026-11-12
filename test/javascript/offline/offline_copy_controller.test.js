// hors-connexion Lot B, CA-7 : la copie rendue hors ligne est rangée en file (UUID, heures de l'appareil, réponses, note provisoire, jeton), sans note envoyée.
// Lancer : node --test test/javascript/offline/offline_copy_controller.test.js (IndexedDB, DOM et Stimulus simulés).
import "./stimulus_base.js"
import { test, beforeEach } from "node:test"
import assert from "node:assert/strict"
import { createFakeIndexedDB } from "./fake_indexeddb.js"
import * as store from "../../../app/javascript/offline/store.js"
import OfflineCopyController, { parseFields, resumeAt, solutionText, resultRows } from "../../../app/javascript/offline/controllers/copy_controller.js"

const KEY = "0123456789abcdef"
const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
const MINUTE = 60_000

const answer = (position, content, extra = {}) => ({ position, content, match_content: null, correct: false, blank: 0, ...extra })
const PACK = {
  exercise_public_id: "EX1", token: "jeton-signé", digest: "0123456789abcdef", issued_at: "2026-11-12T09:00:00Z",
  questions: [
    { id: 11, kind: "choice", question_type: "single_choice", content: "Capitale ?", explanation: "Abidjan est la capitale économique.", points: "1.0", unit: null, numeric_tolerance: null,
      answers: [ answer(1, "Abidjan", { correct: true }), answer(2, "Dakar") ], display: [ 1, 0 ] },
    { id: 12, kind: "written", question_type: "written", content: "Explique", explanation: "Corrigé type", points: "1.0", unit: null, numeric_tolerance: null, answers: [] }
  ]
}
const FIELDS = [ [ "copy[answers][11][display_order][]", "1" ], [ "copy[answers][12][response_text]", "Mon texte" ] ]

let fake, controller, shown, now

beforeEach(() => {
  fake = createFakeIndexedDB()
  globalThis.indexedDB = fake
  globalThis.document = { querySelector: () => ({ content: KEY }) }
  shown = { result: null, paused: null, notSaved: { hidden: true }, resultFailed: { hidden: true }, submitButton: { hidden: false, disabled: false } }
  controller = Object.create(OfflineCopyController.prototype)
  Object.defineProperties(controller, {
    exerciseValue: { value: "EX1" }, totalValue: { value: 1, configurable: true }, counterValue: { value: "%{answered}/%{total} répondues" },
    timeFormatValue: { value: "%H h %M" }, hasCounterTarget: { value: false, configurable: true }, notSavedTarget: { value: shown.notSaved },
    hasResultFailedTarget: { value: true }, hasSubmitButtonTarget: { value: true },
    resultFailedTarget: { value: shown.resultFailed }, submitButtonTarget: { value: shown.submitButton }
  })
  controller.fields = () => FIELDS
  controller.showResult = (pack, graded) => { shown.result = { pack, graded } }
  controller.showPaused = (resume) => { shown.paused = resume }
  now = Date.now()
})

const submit = () => controller.submit({ preventDefault() { shown.prevented = true } })
const copies = () => store.listCopies(KEY)

test("parseFields lit les noms de champs de la copie en ligne", () => {
  assert.deepEqual(parseFields([
    [ "copy[answers][5][display_order][]", "2" ], [ "copy[answers][5][display_order][]", "0" ], [ "copy[answers][6][response_text]", "x" ],
    [ "copy[answers][7][blanks][0]", "a" ], [ "copy[answers][7][blanks][1]", "" ], [ "authenticity_token", "abc" ], [ "copy[answers][8][inconnu]", "z" ]
  ]), { 5: { display_order: [ "2", "0" ] }, 6: { response_text: "x" }, 7: { blanks: { 0: "a", 1: "" } } })
})

test("rendre la copie : rangée en file avec UUID v4, heures de l'appareil, réponses, note provisoire et jeton ; aucune note envoyée comme score", async () => {
  await store.putPack(KEY, PACK)
  await controller.connect()
  await submit()

  assert.equal(shown.prevented, true)
  const [ copy ] = await copies()
  assert.match(copy.client_copy_id, UUID_V4)
  assert.equal(copy.status, "pending")
  assert.equal(copy.exercise_public_id, "EX1")
  assert.equal(copy.pack_token, "jeton-signé")
  assert.equal(copy.provisional_percent, 100)
  assert.deepEqual(copy.answers, { 11: { display_order: [ 1 ] }, 12: { response_text: "Mon texte" } })
  assert.ok(Date.parse(copy.started_at) <= Date.parse(copy.submitted_at))
  assert.ok(Math.abs(Date.parse(copy.submitted_at) - Date.now()) < 5000)
  assert.equal(Object.keys(copy).includes("score"), false)
  assert.equal(shown.result.graded.percent, 100)
  assert.equal(shown.notSaved.hidden, true)
})

test("deux appuis sans attendre : une seule copie rangée (verrou)", async () => {
  await store.putPack(KEY, PACK)
  await controller.connect()
  await Promise.all([ submit(), submit() ])

  assert.equal((await copies()).length, 1)
})

test("deux rendus distincts successifs ont deux identifiants", async () => {
  await store.putPack(KEY, PACK)
  await controller.connect()
  await submit()
  controller.storing = false
  await submit()

  const ids = (await copies()).map((copy) => copy.client_copy_id)
  assert.equal(new Set(ids).size, 2)
})

test("échec du rangement : le verrou est libéré, un nouvel essai est possible", async () => {
  await store.putPack(KEY, PACK)
  await controller.connect()
  fake.failNextPut = new DOMException("plein", "QuotaExceededError")
  const original = console.error
  console.error = () => {}
  try { await submit() } finally { console.error = original }
  await submit()

  assert.equal((await copies()).length, 1)
  assert.equal(controller.storing, true)
})

test("note impossible à afficher : copie gardée, console.error, message neutre, bouton masqué", async () => {
  await store.putPack(KEY, PACK)
  await controller.connect()
  controller.showResult = () => { throw new Error("gabarit cassé") }
  const errors = []
  const original = console.error
  console.error = (...args) => errors.push(args)
  try { await submit() } finally { console.error = original }

  assert.equal((await copies()).length, 1)
  assert.equal(errors.length, 1)
  assert.equal(shown.resultFailed.hidden, false)
  assert.equal(shown.submitButton.hidden, true)
})

test("started_at est l'heure d'ouverture de la page, avant le rendu", async () => {
  await store.putPack(KEY, PACK)
  await controller.connect()
  const opened = controller.startedAt
  await new Promise((resolve) => setTimeout(resolve, 15))
  await submit()

  const [ copy ] = await copies()
  assert.equal(copy.started_at, opened)
  assert.notEqual(copy.started_at, copy.submitted_at)
})

test("stockage plein : la copie n'est pas rangée, le message §3.4 s'affiche, la note ne s'affiche pas", async () => {
  await store.putPack(KEY, PACK)
  await controller.connect()
  fake.failNextPut = new DOMException("plein", "QuotaExceededError")
  const errors = []
  const original = console.error
  console.error = (...args) => errors.push(args)
  try { await submit() } finally { console.error = original }

  assert.deepEqual(await copies(), [])
  assert.equal(shown.notSaved.hidden, false)
  assert.equal(shown.result, null)
  assert.equal(errors.length, 1, "l'erreur n'est jamais avalée")
})

test("base indisponible : même message, rien n'est rangé", async () => {
  await store.putPack(KEY, PACK)
  await controller.connect()
  fake.failOpen = new Error("refusé")
  const original = console.error
  console.error = () => {}
  try { await submit() } finally { console.error = original }

  assert.equal(shown.notSaved.hidden, false)
  assert.equal(shown.result, null)
})

test("paquet absent (purgé ou expiré) : message, rien n'est rangé", async () => {
  await controller.connect()
  const original = console.error
  console.error = () => {}
  try { await submit() } finally { console.error = original }

  assert.equal(shown.notSaved.hidden, false)
  assert.deepEqual(await copies(), [])
})

test("resumeAt rejoue RestartPause : trois copies à moins de 30 minutes d'écart, puis pause de 30 minutes", () => {
  const t0 = 1_000_000_000
  const three = [ t0, t0 + 10 * MINUTE, t0 + 20 * MINUTE ]
  assert.equal(resumeAt(three, t0 + 25 * MINUTE), t0 + 50 * MINUTE)
  assert.equal(resumeAt(three, t0 + 51 * MINUTE), null)
  assert.equal(resumeAt(three.slice(1), t0 + 25 * MINUTE), null)
  assert.equal(resumeAt([ t0, t0 + 40 * MINUTE, t0 + 50 * MINUTE ], t0 + 55 * MINUTE), null)
  assert.equal(resumeAt([ t0 + 20 * MINUTE, t0, t0 + 10 * MINUTE, t0 - 2 * 60 * MINUTE ], t0 + 25 * MINUTE), t0 + 50 * MINUTE)
})

test("trois copies récentes en file de cet exercice : la pause est affichée à l'ouverture ; une copie rejetée ou d'un autre exercice ne compte pas", async () => {
  const stamp = (minutes) => new Date(now - minutes * MINUTE).toISOString()
  const copy = (id, minutes, extra = {}) => store.putCopy(KEY, { client_copy_id: id, exercise_public_id: "EX1", pack_token: "t", started_at: stamp(minutes + 1), submitted_at: stamp(minutes), answers: {}, provisional_percent: 0, ...extra })
  await copy("c1", 20)
  await copy("c2", 10)
  await copy("c3", 2, { exercise_public_id: "AUTRE" })
  await controller.connect()
  assert.equal(shown.paused, null)

  await copy("c4", 2, { status: "rejected" })
  await controller.connect()
  assert.equal(shown.paused, null)

  await copy("c5", 1)
  await controller.connect()
  assert.ok(shown.paused > now)
})

test("une base illisible à l'ouverture ne bloque pas la copie (la pause se rejoue au serveur)", async () => {
  fake.failOpen = new Error("refusé")
  const original = console.warn
  console.warn = () => {}
  try { await controller.connect() } finally { console.warn = original }

  assert.equal(shown.paused, null)
})

test("solutionText : la bonne réponse de chaque type, lue dans le paquet", () => {
  const a = answer
  assert.equal(solutionText({ kind: "choice", answers: [ a(1, "A", { correct: true }), a(2, "B"), a(3, "C", { correct: true }) ] }), "A ; C")
  assert.equal(solutionText({ kind: "select", answers: [ a(1, "a", { correct: true }), a(2, "b"), a(3, "c", { blank: 1 }), a(4, "d", { blank: 1, correct: true }) ] }), "a ; d")
  assert.equal(solutionText({ kind: "fill_blank", answers: [ a(1, "Abidjan"), a(2, "Abidjan (CI)") ] }), "Abidjan / Abidjan (CI)")
  assert.equal(solutionText({ kind: "numeric", unit: "cm", answers: [ a(1, "4.8") ] }), "4.8 cm")
  assert.equal(solutionText({ kind: "ordering", answers: [ a(2, "Deux"), a(1, "Un") ] }), "Un → Deux")
  assert.equal(solutionText({ kind: "matching", answers: [ a(1, "L1", { match_content: "R1" }), a(2, "L2", { match_content: "R2" }) ] }), "L1 → R1 ; L2 → R2")
  assert.equal(solutionText({ kind: "written", answers: [] }), "")
})

test("resultRows : verdict, énoncé, bonne réponse des seules questions notées, explication", () => {
  const rows = resultRows(PACK, { results: [ { verdict: "correct" }, { verdict: "unscored" } ] })
  assert.deepEqual(rows, [
    { verdict: "correct", content: "Capitale ?", solution: "Abidjan", explanation: "Abidjan est la capitale économique." },
    { verdict: "unscored", content: "Explique", solution: "", explanation: "Corrigé type" }
  ])
})

test("count : « n/T répondues » ; une question à cocher l'est au bon nombre de cases, une liste de champs quand tous sont remplis", () => {
  const field = (name, extra = {}) => ({ name, value: "", type: "text", checked: false, ...extra })
  const question = (fields, expected) => ({
    querySelector: () => (expected ? { dataset: { expectedCount: String(expected) } } : null),
    querySelectorAll: (selector) => (selector.includes("checkbox") ? fields.filter((f) => f.checked) : fields)
  })
  const radio = question([ field("copy[answers][1][display_order][]", { type: "radio", checked: true }), field("copy[answers][1][display_order][]", { type: "radio" }) ])
  const two = question([ field("copy[answers][2][display_order][]", { type: "checkbox", checked: true }) ], 2)
  const text = question([ field("copy[answers][3][response_text]", { value: " 4,8 " }) ])
  const empty = question([ field("copy[answers][4][response_text]", { value: "  " }) ])
  const counter = { textContent: "" }
  Object.defineProperties(controller, { hasCounterTarget: { value: true }, counterTarget: { value: counter }, questionTargets: { value: [ radio, two, text, empty ] }, totalValue: { value: 4 } })

  controller.count()

  assert.equal(counter.textContent, "2/4 répondues")
})
