# 🌐 UI · Assessment::BadgesHelper — badges, maîtrise et note sur 20 d'un exercice
# Rôle : libellés des quatre paliers (Bronze, Argent, Or, Diamant) et de la maîtrise, tirés des seuils de Grading
# ADR  : 0033, 0106 · UDR : 0007, 0131, palette froide §3.3, écrans enseignant §3.1
module Assessment
  module BadgesHelper
    BADGE_LEVEL_TONES = { bronze: :warning, silver: :neutral, gold: :gold, diamond: :info }.freeze
    # UDR enseignant §3.1 : la pastille qui porte un trophée est neutre ; la couleur du palier va sur l'icône seule.
    BADGE_PILL = "ui-badge ui-badge-md border border-line bg-mist text-ink"

    # level : :bronze, :silver, :gold, :diamond, ou nil (aucun palier atteint).
    def badge_label(level)
      t("assessment.badges.levels.#{level || :none}")
    end

    def badge_tone(level)
      BADGE_LEVEL_TONES.fetch(level.to_s.to_sym, :neutral)
    end

    def mastery_label(score)
      t("assessment.badges.mastery.#{Entities::Assessment::Grading.mastery_for(score)}")
    end

    # UDR médailles : l'infobulle des médailles se lit en mots, sans chiffre. Celle de la maîtrise (enseignant) se lit encore sur 20 (UDR-0131).
    def badges_tip = t("shared.info_tips.badges")

    def mastery_tip
      grading = Entities::Assessment::Grading
      acquired = grading.grade_on_20(grading::MASTERY_THRESHOLD)
      t("shared.info_tips.mastery", acquired:, fragile: grading.grade_on_20(grading::PASS_THRESHOLD), below_acquired: acquired - 1)
    end

    # UDR médailles : la médaille remplace la note à l'écran de l'élève. Un exercice traité donne au moins Bronze ; nil → « Pas encore ».
    # Trophée coloré + nom du palier, « Médaille Or » pour les lecteurs d'écran.
    def medal_tag(score, size: "size-5")
      level = Entities::Assessment::Grading.badge_for(score) if score
      return tag.span(badge_label(nil), class: "text-mute") unless level

      icon = comprehension_trophy(ComprehensionHelper::BADGE_ICON_CLASSES.fetch(level), size:)
      tag.span(safe_join([ icon, tag.span(badge_label(level), "aria-hidden": "true"), tag.span(t("assessment.session_results.badge.label", level: badge_label(level)), class: "sr-only") ], " "),
               class: "inline-flex items-center gap-1 font-display font-medium text-ink")
    end

    # La médaille au-dessus de `level`, ou nil au Diamant.
    def next_medal(level)
      order = Entities::Assessment::Grading::BADGE_ORDER
      order[order.index(level.to_sym) + 1] if level
    end

    def grade_label(score)
      t("assessment.badges.grade", grade: Entities::Assessment::Grading.grade_on_20(score))
    end

    # « Or 3 » : trophée du palier, son nom et son compte ; nil à zéro (un badge à zéro est caché).
    def badge_pill(level, count:)
      return if count.zero?

      icon = comprehension_trophy(ComprehensionHelper::BADGE_ICON_CLASSES.fetch(level.to_sym))
      tag.span(safe_join([ icon, badge_label(level), count ], " "), class: BADGE_PILL)
    end
  end
end
