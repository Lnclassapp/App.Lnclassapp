# 🌐 UI · DueDateHelper — l'échéance d'un exercice assigné, seul endroit où elle se formate
# Rôle : `due_badge` l'étiquette de l'élève ; `due_for_teacher` la date absolue de l'enseignant ; `due_closing` la date en fin de phrase
# ADR  : 0072 · UDR : 0062 (§3.1)
module DueDateHelper
  # Jours restants avant l'échéance : aujourd'hui et demain ont leur mot ; de 2 à 7 jours, le nom du jour suffit.
  CLOSE = { 0 => :today, 1 => :tomorrow }.freeze
  WEEK = (2..7)

  # Faute d'heure de séance, « moins de 24 h » se lit en jours : aujourd'hui et demain sont ambre (ADR-0072 §4.4).
  # → étiquette `ui_badge`, ou nil sans échéance ou pour un exercice terminé.
  def due_badge(due_on, today: Time.zone.today, done: false, size: :sm)
    return if due_on.nil? || done

    days = (due_on - today).to_i
    return ui_badge(due_label(days, due_on), tone: :warning, size:, icon: "exclamation-circle") if days.negative?

    ui_badge(due_label(days, due_on), tone: CLOSE.key?(days) ? :warning : :neutral, size:, icon: "clock")
  end

  # Date toujours absolue, pour qu'une capture reste juste le lendemain : « Pour jeu. 8 oct. », ou « Sans date limite ».
  def due_for_teacher(due_on)
    return t("due_dates.teacher.none") if due_on.nil?

    t("due_dates.teacher.due", date: l(due_on, format: :due_short))
  end

  # En fin de phrase (toast d'assignation, UDR-0062 §3.4) : « jeudi 8 oct. », « jeudi 6 mai. ». Le point abréviatif
  # du mois tient lieu de point final ; un mois écrit en entier reçoit le sien.
  def due_closing(due_on)
    date = l(due_on, format: :due_long)
    date.end_with?(".") ? date : "#{date}."
  end

  private

  def due_label(days, due_on)
    return t("due_dates.badge.#{CLOSE.fetch(days)}") if CLOSE.key?(days)
    return t("due_dates.badge.weekday", day: l(due_on, format: :due_weekday)) if WEEK.cover?(days)
    return t("due_dates.badge.later", date: l(due_on, format: :due_short)) if days.positive?
    return t("due_dates.badge.late_yesterday") if days == -1

    t("due_dates.badge.late", date: l(due_on, format: :due_long))
  end
end
