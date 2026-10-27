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

    # Les infobulles des paliers et de la maîtrise se lisent sur 20 (UDR-0131), calculées depuis les seuils de Grading.
    def badges_tip
      grading = Entities::Assessment::Grading
      t("shared.info_tips.badges", bronze: grading.grade_on_20(grading::PASS_THRESHOLD),
                                   silver: grading.grade_on_20(grading::MASTERY_THRESHOLD), gold: grading.grade_on_20(grading::GOLD_THRESHOLD))
    end

    def mastery_tip
      grading = Entities::Assessment::Grading
      acquired = grading.grade_on_20(grading::MASTERY_THRESHOLD)
      t("shared.info_tips.mastery", acquired:, fragile: grading.grade_on_20(grading::PASS_THRESHOLD), below_acquired: acquired - 1)
    end

    def grade_label(score)
      t("assessment.badges.grade", grade: Entities::Assessment::Grading.grade_on_20(score))
    end

    # CA-F3 : verte dès la note d'« Acquis » (14/20), lue comme elle s'affiche ; en encre sinon. Jamais rouge.
    def grade_class(score)
      grading = Entities::Assessment::Grading
      return "text-ink" if score.nil?

      grading.grade_on_20(score) >= grading.grade_on_20(grading::MASTERY_THRESHOLD) ? "text-success" : "text-ink"
    end

    # « Or 3 » : trophée du palier, son nom et son compte ; nil à zéro (un badge à zéro est caché).
    def badge_pill(level, count:)
      return if count.zero?

      icon = comprehension_trophy(ComprehensionHelper::BADGE_ICON_CLASSES.fetch(level.to_sym))
      tag.span(safe_join([ icon, badge_label(level), count ], " "), class: BADGE_PILL)
    end
  end
end
