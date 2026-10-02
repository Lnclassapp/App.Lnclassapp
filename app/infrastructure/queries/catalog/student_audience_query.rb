# 🔌 INFRA · Queries::Catalog::StudentAudienceQuery
# Rôle : les (niveau, série) des classes actives de l'élève pour l'année scolaire en cours, adhésions non quittées
# ADR  : 0035 (amendement du 2026-10-01) · UDR : 0013 (amendement du 2026-10-01)
module Queries
  module Catalog
    class StudentAudienceQuery
      # → Entities::Catalog::LevelAudience (vide pour un élève sans classe de l'année)
      def call(student_id:, today: Date.current)
        pairs = Orm::Classroom.joins(:classroom_students)
                              .where(classroom_students: { student_id:, left_at: nil }, status: "active",
                                     school_year: Entities::Classroom::SchoolYear.current(today))
                              .distinct.pluck(:level_id, :series_id)
        Entities::Catalog::LevelAudience.new(pairs:)
      end
    end
  end
end
