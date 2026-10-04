# 🌐 UI · Assessment::ComprehensionHelper — couleur, icône et libellé de la compréhension d'un exercice assigné
# Rôle : seul endroit où une catégorie ou un signe de progrès devient une classe, une icône ou un texte (écrans enseignant)
# ADR  : 0033, 0079 · UDR : 0072 (§3.2, §3.3)
module Assessment
  module ComprehensionHelper
    DOT_CLASSES = { struggling: "bg-struggling", fragile: "bg-fragile", acquired: "bg-success" }.freeze
    SOFT_CLASSES = { struggling: "bg-struggling-soft", fragile: "bg-fragile-soft", acquired: "bg-success-soft" }.freeze
    TREND_ICONS = { progress: "arrow-trending-up", decline: "arrow-trending-down",
                    stable: "arrow-long-right", stagnant: "arrow-long-right" }.freeze
    # Les tons de BadgesHelper::BADGE_LEVEL_TONES, appliqués à l'icône seule ; un palier à 0 s'atténue (UDR-0072 §3.3).
    BADGE_ICON_CLASSES = { bronze: "text-warning", silver: "text-mute", gold: "text-gold", diamond: "text-info" }.freeze

    # category : :struggling, :fragile, :acquired, ou nil (moins de 5 faits : pas encore lisible).
    def comprehension_dot_class(category)
      category.nil? ? "bg-line" : DOT_CLASSES.fetch(category)
    end

    def comprehension_soft_class(category)
      category.nil? ? "bg-mist" : SOFT_CLASSES.fetch(category)
    end

    def comprehension_label(category)
      t("assessment.comprehension.categories.#{category || :unreadable}")
    end

    # trend : :progress, :decline, :stable, :stagnant, ou nil (un seul essai : un libellé, pas d'icône).
    def trend_icon(trend)
      TREND_ICONS.fetch(trend) unless trend.nil?
    end

    def trend_label(trend)
      t("assessment.comprehension.trends.#{trend || :single}")
    end

    def comprehension_badge_class(level, count)
      count.zero? ? "text-line" : BADGE_ICON_CLASSES.fetch(level)
    end
  end
end
