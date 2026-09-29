# 🔌 INFRA · Repositories::Classroom::ClassroomPlanRepository
# Rôle : barème des classes générées en base (classroom_plan_entries), lu en une requête, écrit entrée par entrée
# ADR  : 0058
module Repositories
  module Classroom
    class ClassroomPlanRepository
      include Ports::Classroom::ClassroomPlanRepositoryPort

      def plan
        entries = Orm::ClassroomPlanEntry.pluck(:school_type, :level_id, :series_id, :count).map do |school_type, level_id, series_id, count|
          Entities::Classroom::ClassroomPlan::Entry.new(school_type:, level_id:, series_id:, count:)
        end
        Entities::Classroom::ClassroomPlan.new(entries:)
      end

      # Deux entrées au plus par modification (public, privé) : une recherche par clé suffit, sans upsert sur index partiel.
      def save(entries:, at:)
        entries.each do |entry|
          record = Orm::ClassroomPlanEntry.find_or_initialize_by(school_type: entry.school_type, level_id: entry.level_id,
                                                                 series_id: entry.series_id)
          record.created_at ||= at
          record.update!(count: entry.count, updated_at: at)
        end
        true
      end
    end
  end
end
