# 🌐 UI · Assessment::BadgesHelper — badges, maîtrise et note sur 20 d'un exercice
# Rôle : libellés des quatre paliers (Bronze, Argent, Or, Diamant) et de la maîtrise, tirés des seuils de Grading
# ADR  : 0033, 0105 · UDR : 0007, 0128
module Assessment
  module BadgesHelper
    BADGE_LEVEL_TONES = { bronze: :warning, silver: :neutral, gold: :gold, diamond: :info }.freeze

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

    # Les infobulles des paliers et de la maîtrise se lisent sur 20 (UDR-0128), calculées depuis les seuils de Grading.
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
  end
end
