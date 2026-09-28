# 🧠 DOMAINE · Entities::Classroom::ClassroomPlanDefaults
# Rôle : nombres par défaut d'une ligne nouvelle du barème (couple lié, niveau créé) ; une ligne existante n'est jamais écrasée
# ADR  : 0058 (D1, décidé par le porteur le 2026-09-28)
module Entities
  module Classroom
    module ClassroomPlanDefaults
      # « Par série » de l'ancien barème : 2nde, 1ère et tout autre niveau du second cycle.
      PER_SERIES = { "public" => 6, "private" => 3 }.freeze
      # Tle : les nombres de l'ancien barème par série ; toute autre série prend PER_SERIES.
      TLE = { "c" => { "public" => 2, "private" => 1 }, "d" => { "public" => 6, "private" => 3 },
              "a1" => { "public" => 3, "private" => 2 }, "a2" => { "public" => 2, "private" => 2 } }.freeze
      # Premier cycle : seulement les codes de l'ancien barème ; un autre niveau n'a pas de règle sûre et reste non défini.
      FIRST_CYCLE = { "6eme" => { "public" => 4, "private" => 2 }, "5eme" => { "public" => 4, "private" => 2 },
                      "4eme" => { "public" => 10, "private" => 4 }, "3eme" => { "public" => 10, "private" => 4 } }.freeze

      # series : nil pour un niveau du premier cycle. → { "public" => n, "private" => n } | nil (aucune règle)
      def self.counts_for(level:, series:)
        return FIRST_CYCLE[level.slug] if series.nil?
        return TLE.fetch(series.slug, PER_SERIES) if level.slug == "tle"

        PER_SERIES
      end

      # Les entrées à créer : un nombre par type encore absent du barème (même 0 n'est jamais écrasé). → [ClassroomPlan::Entry]
      def self.missing_entries(plan:, level:, series:)
        counts = counts_for(level:, series:) || {}
        counts.filter_map do |school_type, count|
          next unless plan.count(school_type:, level_id: level.id, series_id: series&.id).nil?

          ClassroomPlan::Entry.new(school_type:, level_id: level.id, series_id: series&.id, count:)
        end
      end

      # Écrit les entrées manquantes et trace chacune (source « auto »). classroom_plan, audit_log : ports. → [Entry]
      def self.fill(classroom_plan:, audit_log:, actor:, level:, series:, at:)
        entries = missing_entries(plan: classroom_plan.plan, level:, series:)
        return entries if entries.empty?

        classroom_plan.save(entries:, at:)
        entries.each do |entry|
          audit_log.record(action: "classroom_plan.changed", actor_id: actor.user_id, at:, subject_type: "Level", subject_id: level.id,
                           metadata: { school_type: entry.school_type, level: level.slug, series: series&.slug, from: nil,
                                       to: entry.count, source: "auto" })
        end
        entries
      end
    end
  end
end
