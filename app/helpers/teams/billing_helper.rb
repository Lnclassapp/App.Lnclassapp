# 🌐 UI · Teams::BillingHelper — la plage d'une semaine de la caisse, écrite à la française
# Rôle : `billing_week_range` rend « du 6 au 12 novembre », « du 30 octobre au 1er novembre » ; le premier du mois prend son « er »
# ADR  : cartes-activation (contexte billing, §4.7) · UDR : caisse-equipe §3.1
module Teams
  module BillingHelper
    def billing_week_range(week)
      from = week.starts_on
      to = week.ends_on
      if from.month == to.month
        t("teams.billing.cashboxes.week.same_month", from: billing_day(from), to: billing_day(to), month: l(to, format: "%B"))
      else
        t("teams.billing.cashboxes.week.two_months", from: billing_day(from), from_month: l(from, format: "%B"), to: billing_day(to), to_month: l(to, format: "%B"))
      end
    end

    private

    def billing_day(date) = date.day == 1 ? t("teams.billing.cashboxes.week.first_day") : date.day.to_s
  end
end
