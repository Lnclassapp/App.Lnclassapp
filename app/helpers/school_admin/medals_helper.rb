# 🌐 UI · SchoolAdmin::MedalsHelper — la répartition de médailles lue par la direction
# Rôle : « 8 Bronze  6 Argent  3 Or » en trophées colorés ; « Pas encore » quand aucune médaille n'est gagnée, jamais une moyenne
# UDR  : médailles (§2.4, §3) · compte par palier d'une classe ou d'un élève, chaque médaille étant celle d'un exercice
module SchoolAdmin
  module MedalsHelper
    # counts : { :bronze => 8, :silver => 6 } (Queries::School::StudentWorkQuery), vide sans médaille.
    def medal_counts(counts)
      items = Entities::Assessment::Grading::BADGE_ORDER.filter_map do |level|
        n = counts[level].to_i
        next unless n.positive?

        tag.span(safe_join([ comprehension_trophy(Assessment::ComprehensionHelper::BADGE_ICON_CLASSES.fetch(level)),
                             tag.span("#{n} #{badge_label(level)}") ], " "), class: "inline-flex items-center gap-1 whitespace-nowrap")
      end
      return tag.span(badge_label(nil), class: "text-mute") if items.empty?

      tag.span(safe_join(items, " "), class: "inline-flex flex-wrap items-center gap-x-3 gap-y-1")
    end
  end
end
