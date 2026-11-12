// ⚡ FRONT · offline-copy — la copie faite hors ligne : corrige sur le téléphone, range la copie en file, affiche la note PROVISOIRE
// Rôle : au rendu, lit les champs (mêmes noms que la copie en ligne), corrige avec offline/grader.js, range { client_copy_id, started_at, submitted_at, answers, provisional_percent, pack_token } dans la base locale ; jamais une note envoyée au serveur
// ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.4, §4.5, menace R1, R3) · UDR : hors-connexion §3.4 (stockage plein : message, jamais avalé), §3.5 (note provisoire) · contrats store.js et grader.js gelés
import { Controller } from "@hotwired/stimulus"
import { currentKey, getPack, listCopies, putCopy } from "../offline/store.js"
import { gradeCopy } from "../offline/grader.js"

const STREAK = 3
const PAUSE_WINDOW_MS = 30 * 60 * 1000
const FIELD = /^copy\[answers\]\[(\d+)\]\[(display_order|response_text|blanks)\](?:\[(\d*)\])?$/
const ANSWER_FIELDS = /\[(?:display_order|response_text|blanks)\b/

// Les champs postés d'un formulaire (FormData.entries()) → { <id de question> : { display_order: [], response_text, blanks: { "0": … } } }.
export function parseFields(entries) {
  const responses = {}
  for (const [ name, value ] of entries) {
    const match = FIELD.exec(name)
    if (!match || typeof value !== "string") continue

    const [ , id, field, index ] = match
    const answer = (responses[id] ??= {})
    if (field === "display_order") (answer.display_order ??= []).push(value)
    else if (field === "blanks") (answer.blanks ??= {})[index] = value
    else answer.response_text = value
  }
  return responses
}

// RestartPause.resume_at : trois copies d'affilée (moins de 30 minutes d'écart), puis 30 minutes de pause. completions : des heures (ms). → ms | null
export function resumeAt(completions, now) {
  const last = [ ...completions ].sort((a, b) => a - b).slice(-STREAK)
  if (last.length !== STREAK || !last.slice(1).every((time, index) => time - last[index] < PAUSE_WINDOW_MS)) return null

  const resume = last[STREAK - 1] + PAUSE_WINDOW_MS
  return now < resume ? resume : null
}

// Le texte de la bonne réponse d'une question notée, tiré du paquet (écrit avec textContent, jamais en HTML).
export function solutionText(question) {
  const answers = question.answers
  const cases = Array.from({ length: Math.max(0, ...answers.map((answer) => answer.blank ?? 0)) + 1 }, (_, blank) => answers.filter((answer) => (answer.blank ?? 0) === blank))
  switch (question.kind) {
    case "choice": return answers.filter((answer) => answer.correct).map((answer) => answer.content).join(" ; ")
    case "select": return cases.map((options) => options.find((answer) => answer.correct)?.content ?? "").join(" ; ")
    case "fill_blank": return cases.map((accepted) => accepted.map((answer) => answer.content).join(" / ")).join(" ; ")
    case "numeric": return cases.map((accepted) => [ accepted[0]?.content, question.unit ].filter(Boolean).join(" ")).join(" ; ")
    case "ordering": return [ ...answers ].sort((a, b) => a.position - b.position).map((answer) => answer.content).join(" → ")
    case "matching": return [ ...answers ].sort((a, b) => a.position - b.position).map((answer) => `${answer.content} → ${answer.match_content}`).join(" ; ")
    default: return ""
  }
}

// Une ligne du résultat par question : verdict, énoncé, bonne réponse (questions notées seulement), explication.
export function resultRows(pack, graded) {
  return pack.questions.map((question, index) => ({
    verdict: graded.results[index].verdict,
    content: question.content,
    solution: graded.results[index].verdict === "unscored" ? "" : solutionText(question),
    explanation: question.explanation || ""
  }))
}

export default class extends Controller {
  static targets = [ "counter", "question", "notSaved", "result", "paused", "resultFailed", "submitButton" ]
  static values = { exercise: String, total: Number, counter: String, timeFormat: String }

  async connect() {
    this.startedAt = new Date().toISOString()
    this.count()
    try {
      const key = currentKey()
      if (!key) return

      const copies = await listCopies(key)
      const times = copies.filter((copy) => copy.exercise_public_id === this.exerciseValue && copy.status !== "rejected").map((copy) => Date.parse(copy.submitted_at))
      const resume = resumeAt(times.filter(Number.isFinite), Date.now())
      if (resume) this.showPaused(resume)
    } catch (error) {
      // La pause se rejoue au serveur : une base illisible ne bloque pas la copie.
      console.warn("copie hors ligne : pause locale non vérifiée", error)
    }
  }

  async submit(event) {
    event.preventDefault()
    if (this.storing) return

    this.storing = true
    if (this.hasSubmitButtonTarget) this.submitButtonTarget.disabled = true
    const stored = await this.store()
    if (!stored) {
      this.storing = false
      if (this.hasSubmitButtonTarget) this.submitButtonTarget.disabled = false
      return
    }

    try {
      this.showResult(stored.pack, stored.graded)
    } catch (error) {
      // La copie est gardée : seule la note ne s'affiche pas.
      console.error("copie hors ligne : note non affichée", error)
      if (this.hasResultFailedTarget) this.resultFailedTarget.hidden = false
      if (this.hasSubmitButtonTarget) this.submitButtonTarget.hidden = true
    }
  }

  // Corrige et range la copie. → { pack, graded } ou null : UDR §3.4, la copie n'est pas rangée, l'élève le sait (message, jamais avalé)
  // et ses réponses restent dans le formulaire.
  async store() {
    try {
      const key = currentKey()
      const pack = key && await getPack(key, this.exerciseValue)
      if (!pack) throw new Error("paquet de corrigé absent")

      const graded = gradeCopy(pack.questions, parseFields(this.fields()))
      await putCopy(key, {
        client_copy_id: crypto.randomUUID(), exercise_public_id: this.exerciseValue, pack_token: pack.token, started_at: this.startedAt,
        submitted_at: new Date().toISOString(), answers: graded.answers, provisional_percent: graded.percent
      })
      return { pack, graded }
    } catch (error) {
      console.error("copie hors ligne non gardée", error)
      this.notSavedTarget.hidden = false
      this.notSavedTarget.scrollIntoView?.({ block: "center" })
      return null
    }
  }

  fields() { return Array.from(new FormData(this.element).entries()) }

  // « n/T répondues » : une question l'est quand sa saisie est complète (comme la copie en ligne).
  count() {
    if (!this.hasCounterTarget) return

    const answered = this.questionTargets.filter((question) => this.answered(question)).length
    this.counterTarget.textContent = this.counterValue.replace("%{answered}", answered).replace("%{total}", this.totalValue)
  }

  answered(question) {
    const expected = question.querySelector("[data-expected-count]")
    if (expected) return question.querySelectorAll("input[type=checkbox]:checked").length === Number(expected.dataset.expectedCount)

    const fields = [ ...question.querySelectorAll("input, select, textarea") ].filter((field) => ANSWER_FIELDS.test(field.name))
    if (fields.some((field) => field.type === "radio")) return fields.some((field) => field.checked)

    return fields.length > 0 && fields.every((field) => field.value.trim() !== "")
  }

  // La note remplace la feuille (#copy-sheet), focus sur son titre (UDR §3.5).
  showResult(pack, graded) {
    const section = this.resultTarget.content.cloneNode(true)
    const percent = section.querySelector("[data-percent]")
    percent.textContent = percent.textContent.replace("%{percent}", graded.percent)
    const list = section.querySelector("[data-questions]")
    const template = section.querySelector("template[data-item]")
    for (const row of resultRows(pack, graded)) list.append(this.item(template, row))
    this.element.closest("#copy-sheet").replaceChildren(section)
    document.getElementById("offline_result_title")?.focus()
  }

  item(template, row) {
    const item = template.content.cloneNode(true)
    const verdict = item.querySelector("[data-verdict]")
    verdict.textContent = verdict.dataset[`${row.verdict}Text`]
    const icon = item.querySelector(`[data-icon="${row.verdict}"]`)
    if (icon) icon.hidden = false
    item.querySelector("[data-content]").textContent = row.content
    this.fill(item.querySelector("[data-solution]"), "[data-solution-text]", row.solution)
    this.fill(item.querySelector("[data-explanation]"), "[data-explanation-text]", row.explanation)
    return item
  }

  fill(block, textSelector, text) {
    if (!text) return

    block.querySelector(textSelector).textContent = text
    block.hidden = false
  }

  // Pause de « Recommencer » : le message existant remplace les questions et le pied de la feuille (heure de reprise au format du serveur).
  showPaused(resume) {
    const time = new Date(resume)
    const two = (number) => String(number).padStart(2, "0")
    const text = this.timeFormatValue.replace("%H", two(time.getHours())).replace("%M", two(time.getMinutes()))
    const message = this.pausedTarget.content.cloneNode(true)
    const paragraph = message.querySelector("p")
    paragraph.textContent = paragraph.textContent.replace("%{time}", text)
    const [ first, ...others ] = this.element.querySelectorAll("[data-pausable]")
    first.replaceWith(message)
    others.forEach((element) => element.remove())
  }
}
