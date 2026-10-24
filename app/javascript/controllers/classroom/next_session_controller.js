// ⚡ FRONT · classroom/next_session_controller — « Prochaine séance : lundi 26 oct. » sous les jours de séance
// Rôle : à chaque case cochée, la première date strictement après aujourd'hui (celui du serveur) qui tombe un jour coché ; aucun jour, ligne cachée ; un jour coché efface l'erreur « Cochez au moins un jour »
// ADR  : 0072 · UDR : XXXX-ecrans-enseignant-sans-repetition (§3.13) · sans JavaScript, la ligne reste cachée (hidden)
import { Controller } from "@hotwired/stimulus"

const DAY = 24 * 60 * 60 * 1000
const FORMAT = { weekday: "long", day: "numeric", month: "short", timeZone: "UTC" }

export default class extends Controller {
  static targets = [ "day", "line", "date", "error" ]
  static values = { today: String, locale: { type: String, default: "fr-FR" } }

  connect() { this.update() }

  update() {
    const days = this.dayTargets.filter((box) => box.checked).map((box) => Number(box.value))
    const next = this.nextAfter(days)

    if (days.length > 0 && this.hasErrorTarget) this.errorTarget.hidden = true
    this.lineTarget.hidden = next === null
    if (next) this.dateTarget.textContent = new Intl.DateTimeFormat(this.localeValue, FORMAT).format(next)
  }

  // Dates en UTC à minuit : la date du serveur (Abidjan) ne bouge pas avec le fuseau du téléphone. 1 = lundi … 6 = samedi.
  nextAfter(weekdays) {
    if (weekdays.length === 0) return null

    const today = Date.parse(`${this.todayValue}T00:00:00Z`)
    for (let step = 1; step <= 7; step++) {
      const date = new Date(today + step * DAY)
      if (weekdays.includes(((date.getUTCDay() + 6) % 7) + 1)) return date
    }
    return null
  }
}
