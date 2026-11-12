// hors-connexion Lot B, CA-6 : le correcteur JavaScript rend, pour chaque cas de la table partagée, le verdict des règles Ruby.
// Le même fichier (test/fixtures/files/offline/grading_cases.json) est joué par offline_grading_parity_test.rb.
// Lancer : node --test test/javascript/offline/grader.test.js
import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { gradeQuestion, gradeCopy, share, pointsPercent } from "../../../app/javascript/offline/grader.js"

const table = JSON.parse(readFileSync(new URL("../../fixtures/files/offline/grading_cases.json", import.meta.url), "utf8"))

for (const entry of table.questions) {
  test(`cas « ${entry.name} »`, () => {
    const outcome = gradeQuestion(entry.question, entry.response)
    const picked = Object.fromEntries(Object.keys(entry.expected).map((key) => [ key, outcome[key] ]))
    assert.deepEqual(picked, entry.expected)
  })
}

for (const entry of table.scores) {
  test(`note « ${entry.name} »`, () => {
    const graded = entry.cases.flatMap((reference) => {
      const [ points, name ] = reference.startsWith("@") ? reference.slice(1).split(/:(.*)/s) : [ null, reference ]
      const found = table.questions.find((candidate) => candidate.name === name)
      assert.ok(found, `cas inconnu : ${name}`)
      const question = { ...found.question, points: points ?? found.question.points }
      const outcome = gradeQuestion(question, found.response)
      return outcome.graded === false ? [] : [ [ question.points, share(question, outcome) ] ]
    })
    assert.equal(pointsPercent(graded), entry.percent)
  })
}

test("la table couvre chaque type de question", () => {
  const types = new Set(table.questions.map((entry) => entry.question.question_type))
  for (const type of [ "true_false", "single_choice", "multiple_correct_2", "multiple_correct_3", "fill_blank", "numeric", "ordering", "matching", "select", "written", "notebook" ]) {
    assert.ok(types.has(type), type)
  }
})

test("gradeCopy : la note, les verdicts et les réponses à ranger (jamais une réponse mal formée ni vide)", () => {
  const find = (name) => table.questions.find((entry) => entry.name === name)
  const good = { ...find("choix unique juste").question, id: 11 }
  const wrong = { ...find("liste fausse").question, id: 12 }
  const bad = { ...find("choix unique deux cochés").question, id: 13 }
  const empty = { ...find("trou vide").question, id: 14 }
  const written = { ...find("rédigée jamais notée").question, id: 15 }
  const notebook = { ...find("cahier jamais noté").question, id: 16 }

  const copy = gradeCopy([ good, wrong, bad, empty, written, notebook ], {
    11: { display_order: [ "1" ] }, 12: { display_order: [ "0" ] }, 13: { display_order: [ "1", "2" ] }, 14: { response_text: "  " },
    15: { response_text: "Mon texte" }, 16: {}
  })

  assert.equal(copy.percent, 25)
  assert.deepEqual(copy.results.map((result) => result.verdict), [ "correct", "wrong", "wrong", "wrong", "unscored", "unscored" ])
  assert.deepEqual(copy.answers, { 11: { display_order: [ 1 ] }, 12: { display_order: [ 0 ] }, 15: { response_text: "Mon texte" } })
})

test("gradeCopy : une question sans réponse postée est vide", () => {
  const question = { ...table.questions[0].question, id: 21 }
  const copy = gradeCopy([ question ], {})
  assert.equal(copy.percent, 0)
  assert.deepEqual(copy.answers, {})
})
