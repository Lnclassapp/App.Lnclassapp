// ⚡ FRONT · offline/grader — corrige une copie hors ligne exactement comme le domaine Ruby (note PROVISOIRE, le serveur recorrige à l'envoi)
// Rôle : rejoue Question#correct? des types notés et Grading.points_percent ; written et notebook ne sont jamais notés ; une réponse vide ou mal formée vaut 0
// ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.4, menace R1) · table de cas partagée avec Ruby : test/fixtures/files/offline/grading_cases.json
// Contrat de la réponse postée : { display_order: ["2", …], response_text: "…", blanks: { "0": "…" } } (les champs de la copie en ligne), indices d'affichage lus dans question.display (liste de rangs : un rang est l'indice d'une proposition dans question.answers, le paquet ne porte aucun identifiant de proposition).

const WHITESPACE = "\\t-\\r \\u0085\\u00a0\\u1680\\u2000-\\u200a\\u2028\\u2029\\u202f\\u205f\\u3000" // [[:space:]] de Ruby
const EDGE_SPACES = new RegExp(`^[${WHITESPACE}]+|[${WHITESPACE}]+$`, "gu")
const ANY_SPACES = new RegExp(`[${WHITESPACE}]+`, "gu")
const THOUSANDS = /(?<=\d)[   ](?=\d)/g
const NUMBER = /^-?\d+(?:\.\d+)?$/
const UNIT_FORBIDDEN = /[\d,.+\-−]/
const SHORT_MAX = 200 // AttemptInput::RESPONSE_TEXT_MAX
const WRITTEN_MAX = 2000
const BLANKS_MAX = 6
const EXPECTED = { true_false: 1, single_choice: 1, multiple_correct_2: 2, multiple_correct_3: 3 }
const MALFORMED = Symbol("malformed")

// String#strip de Ruby : espaces ASCII et nul seulement.
const rubyStrip = (text) => text.replace(/^[\t\n\v\f\r \0]+|[\t\n\v\f\r \0]+$/g, "")
const clean = (text) => rubyStrip(text.replace(/\r\n/g, "\n"))
const stripEdges = (text) => text.replace(EDGE_SPACES, "")

// QuestionKinds::FillBlank.normalize
export function normalize(text) {
  return String(text ?? "").normalize("NFD").replace(/\p{Mn}/gu, "").toLowerCase()
    .replace(/[œæ]/g, (ligature) => (ligature === "œ" ? "oe" : "ae"))
    .replace(/[’‘ʼ]/g, "'").replace(/[‐-―−]/g, "-").replace(ANY_SPACES, " ").replace(/^ +| +$/g, "")
}

// Décimaux exacts (BigDecimal) : { int, scale } ; null si le texte n'est pas un nombre.
function decimal(text) {
  if (!NUMBER.test(text)) return null

  const negative = text.startsWith("-")
  const [ whole, fraction = "" ] = text.replace("-", "").split(".")
  const int = BigInt(whole + fraction)
  return { int: negative ? -int : int, scale: fraction.length }
}

// QuestionKinds::Numeric.parse
function parse(text) {
  return decimal(stripEdges(String(text ?? "")).replace(/−/g, "-").replace(THOUSANDS, "").replace(/,/g, "."))
}

// QuestionKinds::Numeric.without_unit
function withoutUnit(text, unit) {
  const given = stripEdges(String(text ?? ""))
  const wanted = rubyStrip(String(unit ?? ""))
  if (wanted === "" || UNIT_FORBIDDEN.test(wanted) || !given.endsWith(wanted)) return text

  return given.slice(0, given.length - wanted.length)
}

const read = (question, text) => parse(withoutUnit(text, question.unit))

function withinTolerance(value, wanted, tolerance) {
  const scale = Math.max(value.scale, wanted.scale, tolerance.scale)
  const at = (number) => number.int * 10n ** BigInt(scale - number.scale)
  const gap = at(value) - at(wanted)
  return (gap < 0n ? -gap : gap) <= at(tolerance)
}

const blanksOf = (question) => Math.max(0, ...question.answers.map((answer) => answer.blank ?? 0)) + 1
// Blanks.cases : les réponses rangées par case.
const ranked = (question) => question.answers.map((answer, rank) => ({ ...answer, rank }))
const casesOf = (question) => Array.from({ length: blanksOf(question) }, (_, blank) => ranked(question).filter((answer) => (answer.blank ?? 0) === blank))
const isMultiBlank = (question) => blanksOf(question) > 1 && [ "numeric", "fill_blank", "select" ].includes(question.kind)

// Ce que dit la copie postée pour une question : AttemptInput + CopyInput (question vide, indices illisibles = -1).
function readAttempt(raw) {
  const fields = raw && typeof raw === "object" ? raw : {}
  const posted = fields.display_order == null ? [] : [].concat(fields.display_order)
  const order = posted.map((value) => (/^\d+$/.test(String(value)) ? Number.parseInt(value, 10) : -1))
  const text = fields.response_text == null ? null : clean(String(fields.response_text))
  const { list, unreadable } = readBlanks(fields.blanks)
  const blank = posted.every((value) => rubyStrip(String(value)) === "") && (text === null || text === "") && list.every((entry) => rubyStrip(entry) === "")
  return { order, text, blanks: list, unreadable, blank }
}

function readBlanks(raw) {
  if (raw == null) return { list: [], unreadable: false }

  const pairs = Array.isArray(raw) ? raw.map((value, index) => [ index, value ]) : Object.entries(raw)
  const unreadable = pairs.length > BLANKS_MAX || pairs.some(([ key, value ]) => !/^\d+$/.test(String(key)) || Number(key) >= BLANKS_MAX || typeof value !== "string")
  if (unreadable) return { list: [], unreadable }

  const list = []
  for (const [ key, value ] of pairs) list[Number(key)] = clean(value)
  return { list: Array.from(list, (entry) => entry ?? ""), unreadable }
}

// AnswerShuffle.pick et .select : les indices d'affichage rendus en rangs, dans l'ordre posté ; mal formés → [].
const pick = (display, indices) => (JSON.stringify([ ...indices ].sort((a, b) => a - b)) === JSON.stringify(display.map((_, index) => index)) ? indices.map((index) => display[index]) : [])
const choose = (display, indices) => (new Set(indices).size === indices.length && indices.every((index) => index >= 0 && index < display.length) ? indices.map((index) => display[index]) : [])

const sameIds = (left, right) => left.length === right.length && left.every((id, index) => id === right[index])
const byPosition = (question) => ranked(question).sort((a, b) => a.position - b.position).map((answer) => answer.rank)
const correctIds = (question) => ranked(question).filter((answer) => answer.correct).map((answer) => answer.rank)
const sorted = (ids) => [ ...ids ].sort((a, b) => a - b)

// → { well_formed, blank_results } ou null (réponse mal formée). Chaque type rejoue ses règles Ruby.
function judge(question, attempt) {
  if (attempt.unreadable) return null

  const display = question.display ?? []
  switch (question.kind) {
    case "choice": return judgeChoice(question, choose(display, attempt.order))
    case "ordering":
    case "matching": return judgeOrder(question, pick(display, attempt.order))
    case "select": return isMultiBlank(question) ? judgeSelectCases(question, attempt, display) : judgeSelect(question, choose(display, attempt.order))
    case "fill_blank": return judgeText(question, attempt, fillBlankResults)
    case "numeric": return judgeText(question, attempt, numericResults)
    default: return null
  }
}

function judgeChoice(question, ids) {
  if (ids.length !== EXPECTED[question.question_type]) return null

  return { blank_results: [ sameIds(sorted(ids), sorted(correctIds(question))) ] }
}

function judgeSelect(question, ids) {
  if (ids.length !== 1) return null

  return { blank_results: [ sameIds(ids, correctIds(question)) ] }
}

function judgeOrder(question, ids) {
  if (ids.length === 0 || ids.length !== question.answers.length) return null

  return { blank_results: [ sameIds(ids, byPosition(question)) ] }
}

// Une liste à plusieurs cases : un indice d'affichage par case, vide = case laissée vide ; une proposition d'une autre case est refusée.
function judgeSelectCases(question, attempt, display) {
  const cases = casesOf(question)
  const posted = [ ...attempt.blanks, ...Array(Math.max(cases.length - attempt.blanks.length, 0)).fill("") ]
  const ids = posted.map((index) => {
    if (rubyStrip(index) === "") return null
    return /^\d+$/.test(index) && Number(index) < display.length ? display[Number(index)] : MALFORMED
  })
  const placed = ids.length === cases.length && ids.every((id, rank) => id === null || cases[rank].some((answer) => answer.rank === id))
  if (!placed) return null

  return { blank_results: ids.map((id, rank) => id !== null && cases[rank].find((answer) => answer.correct)?.rank === id) }
}

// Texte à trous et nombre : un texte (une case) ou un texte par case, les cases vides admises quand il y en a plusieurs.
function judgeText(question, attempt, results) {
  const multi = isMultiBlank(question)
  const cases = blanksOf(question)
  if (multi) {
    const texts = [ ...attempt.blanks, ...Array(Math.max(cases - attempt.blanks.length, 0)).fill("") ]
    if (texts.length !== cases || texts.some((text) => text.length > SHORT_MAX)) return null
    if (question.kind === "numeric" && texts.some((text) => stripEdges(text) !== "" && read(question, text) === null)) return null

    return { blank_results: results(question, texts) }
  }

  const text = attempt.text ?? ""
  if (text.length > SHORT_MAX) return null
  if (question.kind === "fill_blank" ? normalize(text) === "" : read(question, text) === null) return null

  return { blank_results: results(question, [ text ]) }
}

function fillBlankResults(question, texts) {
  return casesOf(question).map((accepted, index) => {
    const given = normalize(texts[index])
    return given !== "" && accepted.some((answer) => normalize(answer.content) === given)
  })
}

function numericResults(question, texts) {
  const tolerance = decimal(question.numeric_tolerance ?? "0")
  return casesOf(question).map((accepted, index) => {
    const value = read(question, texts[index])
    const wanted = accepted[0] ? parse(accepted[0].content) : null
    return value !== null && wanted !== null && withinTolerance(value, wanted, tolerance)
  })
}

// La réponse à ranger dans la copie, au format que le serveur lit (CopyInput) ; jamais une réponse vide ou mal formée.
function storable(question, attempt) {
  if (isMultiBlank(question)) return { blanks: Object.fromEntries(attempt.blanks.map((text, index) => [ String(index), text ])) }
  if ([ "fill_blank", "numeric", "written" ].includes(question.kind)) return { response_text: attempt.text }

  return { display_order: attempt.order }
}

const UNANSWERED = Object.freeze({ answered: false, well_formed: null, blank_results: null, correct: false })

// → { graded, answered, well_formed, blank_results, correct, answer } ; answer : ce qui se range dans la copie, ou null.
export function gradeQuestion(question, response) {
  if (question.kind === "notebook") return { graded: false, answered: false, well_formed: null, blank_results: null, correct: false, answer: null }

  const attempt = readAttempt(response)
  if (question.kind === "written") return gradeWritten(attempt)
  if (attempt.blank) return { graded: true, ...UNANSWERED, answer: null }

  const judged = judge(question, attempt)
  if (judged === null) return { graded: true, answered: true, well_formed: false, blank_results: null, correct: false, answer: null }

  return { graded: true, answered: true, well_formed: true, blank_results: judged.blank_results, correct: judged.blank_results.every(Boolean), answer: storable(question, attempt) }
}

// Une réponse rédigée n'est jamais notée ; son texte part avec la copie (2 000 caractères au plus).
function gradeWritten(attempt) {
  const answered = !attempt.blank
  const wellFormed = answered ? [ ...(attempt.text ?? "") ].length <= WRITTEN_MAX && !(attempt.text ?? "").includes("\0") : null
  const answer = answered && wellFormed ? { response_text: attempt.text } : null
  return { graded: false, answered, well_formed: wellFormed, blank_results: null, correct: false, answer }
}

// Grading.share_of : [numérateur, dénominateur] de la part des points d'une question.
export function share(question, outcome) {
  if (!outcome.well_formed) return [ 0, 1 ]

  const blanks = blanksOf(question)
  if (blanks === 1) return [ outcome.correct ? 1 : 0, 1 ]

  return [ outcome.blank_results.filter(Boolean).length, blanks ]
}

// Grading.points_percent : graded = [[points, [numérateur, dénominateur]]], arrondi vers le bas une seule fois. Entiers exacts (BigInt).
export function pointsPercent(graded) {
  const halves = (points) => BigInt(Math.round(Number(points) * 2))
  const total = graded.reduce((sum, [ points ]) => sum + halves(points), 0n)
  if (total === 0n) return 0

  const weighted = graded.reduce((sum, [ points, [ numerator, denominator ] ]) => sum + halves(points) * BigInt(numerator) * BigInt(60 / denominator), 0n)
  return Number((weighted * 100n) / (total * 60n))
}

// La copie entière. questions : celles du paquet ; responses : { <id de question> : réponse postée }.
// → { percent, results: [{ question_id, verdict: correct|wrong|unscored, … }], answers: { <id> : réponse à ranger } }
export function gradeCopy(questions, responses) {
  const graded = []
  const answers = {}
  const results = questions.map((question) => {
    const outcome = gradeQuestion(question, responses?.[question.id])
    if (outcome.graded) graded.push([ question.points, share(question, outcome) ])
    if (outcome.answer) answers[question.id] = outcome.answer
    const verdict = !outcome.graded ? "unscored" : outcome.correct ? "correct" : "wrong"
    return { question_id: question.id, verdict, answered: outcome.answered, well_formed: outcome.well_formed, blank_results: outcome.blank_results, correct: outcome.correct }
  })
  return { percent: pointsPercent(graded), results, answers }
}
