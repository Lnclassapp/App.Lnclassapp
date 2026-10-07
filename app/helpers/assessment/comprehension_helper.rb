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
    # Le trophée des paliers, défini une fois par page puis repris par <use> : 28 trophées en ligne pesaient 26,7 Ko sur
    # la page classe (Lot C, D3 ; budget de l'ADR-0067).
    TROPHY_SYMBOL_ID = "comprehension-trophy"
    TROPHY_PATH = File.read(Rails.root.join("vendor/heroicons/20/solid/trophy.svg"))[%r{<path .*?/>}m].freeze

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

    # Le premier appel d'une page émet aussi le <symbol> ; les suivants ne font que le reprendre.
    def comprehension_trophy(css_class)
      icon = tag.svg(tag.use(href: "##{TROPHY_SYMBOL_ID}"), viewBox: "0 0 20 20", fill: "currentColor",
                     class: class_names("size-4 shrink-0", css_class), "aria-hidden": "true", focusable: "false")
      return icon if @comprehension_trophy_defined

      @comprehension_trophy_defined = true
      symbol = tag.symbol(TROPHY_PATH.html_safe, id: TROPHY_SYMBOL_ID, viewBox: "0 0 20 20") # rubocop:disable Rails/OutputSafety -- fichier vendu, jamais une saisie
      safe_join([ tag.svg(symbol, class: "absolute size-0 overflow-hidden", "aria-hidden": "true", focusable: "false"), icon ])
    end
  end
end
