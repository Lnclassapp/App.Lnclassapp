# 🌐 UI · Assessment::BadgesHelper — badges, maîtrise et note sur 20 d'un exercice
# Rôle : libellés des quatre paliers (Bronze, Argent, Or, Diamant) et de la maîtrise, tirés des seuils de Grading
# ADR  : 0033, 0106, médailles lues à la clôture · UDR : 0007, 0131, palette froide §3.3, écrans enseignant §3.1
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

    # UDR médailles : la médaille remplace la note à l'écran de l'élève. level : la médaille lue par la query (enregistrée, ou celle de
    # la session, Grading.session_medal), jamais recalculée du score ici : une copie vide n'en a pas ; nil → « Pas encore ».
    # Trophée coloré + nom du palier, « Médaille Or » pour les lecteurs d'écran.
    def medal_tag(level, size: "size-5")
      level = level&.to_sym
      return tag.span(badge_label(nil), class: "text-mute") unless level

      icon = comprehension_trophy(ComprehensionHelper::BADGE_ICON_CLASSES.fetch(level), size:)
      tag.span(safe_join([ icon, tag.span(badge_label(level), "aria-hidden": "true"), tag.span(t("assessment.session_results.badge.label", level: badge_label(level)), class: "sr-only") ], " "),
               class: "inline-flex items-center gap-1 font-display font-medium text-ink")
    end

    # Écrans de l'élève (porteur, 2026-11-24) : la médaille se montre comme une récompense, pastille teintée à sa couleur,
    # trophée sur un rond blanc ; nil → « Pas encore », sans pastille.
    MEDAL_REWARD_TINTS = { bronze: "bg-gold/10", silver: "bg-mist ring-1 ring-line", gold: "bg-gold/25", diamond: "bg-info-soft" }.freeze

    def medal_reward_tag(level)
      level = level&.to_sym
      return tag.span(badge_label(nil), class: "text-sm text-mute") unless level

      trophy = tag.span(comprehension_trophy(ComprehensionHelper::BADGE_ICON_CLASSES.fetch(level), size: "size-4"),
                        class: "grid size-6 place-items-center rounded-full bg-white", "aria-hidden": "true")
      tag.span(safe_join([ trophy, tag.span(badge_label(level), "aria-hidden": "true"),
                           tag.span(t("assessment.session_results.badge.label", level: badge_label(level)), class: "sr-only") ], " "),
               class: class_names("inline-flex items-center gap-1.5 rounded-full py-0.5 pr-2.5 pl-0.5 font-display text-sm font-medium text-ink",
                                  MEDAL_REWARD_TINTS.fetch(level)))
    end

    # La note sur 20 au-dessus de la médaille-récompense, alignées à droite d'une ligne. Une copie vide (sans médaille) n'a pas
    # de note : « Pas encore » seul, jamais « 0/20 ».
    def grade_and_medal(score, level)
      grade = tag.span(grade_label(score), class: "text-base font-medium text-ink tabular-nums", data: { grade: true }) if score && level
      tag.span(safe_join([ grade, medal_reward_tag(level) ].compact, " "), class: "flex flex-col items-end gap-1")
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
