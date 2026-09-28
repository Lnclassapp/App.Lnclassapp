# 🌐 UI · Teams::DashboardsHelper — largeur des barres de la répartition des élèves par niveau (TR-12)
# Rôle : un pourcentage → une des 21 classes littérales de largeur, en pas de 5 % ; sans attribut style (UDR-0005)
# ADR  : 0051, 0062 · UDR : 0005, 0049
module Teams
  module DashboardsHelper
    # Chaînes littérales : Tailwind ne compile que les classes qu'il lit dans les sources.
    BAR_WIDTHS = %w[w-0 w-1/20 w-2/20 w-3/20 w-4/20 w-5/20 w-6/20 w-7/20 w-8/20 w-9/20 w-10/20
                    w-11/20 w-12/20 w-13/20 w-14/20 w-15/20 w-16/20 w-17/20 w-18/20 w-19/20 w-full].freeze

    # Un niveau qui a des élèves garde une barre visible, même sous 2,5 %.
    def dashboard_bar_width(percent)
      step = (percent.clamp(0, 100) / 5.0).round
      step = 1 if step.zero? && percent.positive?
      BAR_WIDTHS.fetch(step)
    end
  end
end
