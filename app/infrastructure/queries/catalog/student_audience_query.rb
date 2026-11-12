# 🔌 INFRA · Queries::Catalog::StudentAudienceQuery
# Rôle : les (niveau, série) des classes actives de l'élève pour l'année scolaire en cours, adhésions non quittées ; sans aucune, le niveau de sa dernière classe principale
# ADR  : 0035 (amendements du 2026-10-01 et du 2026-11-12, chantier eleve-sans-prof) · UDR : 0013 (amendement du 2026-10-01)
module Queries
  module Catalog
    class StudentAudienceQuery
      # La dernière adhésion principale : celle encore ouverte d'abord, puis la plus récemment quittée (StudentHomeQuery::LAST_FIRST).
      LAST_FIRST = Arel.sql("classroom_students.left_at DESC NULLS FIRST, classroom_students.joined_at DESC, classroom_students.id DESC")

      # → Entities::Catalog::LevelAudience. Sans classe active de l'année (retiré, classe archivée ou d'une autre année), le
      # dernier niveau connu : celui de sa dernière classe principale (chantier eleve-sans-prof). Vide s'il n'en a jamais eu.
      def call(student_id:, today: Date.current)
        pairs = Orm::Classroom.joins(:classroom_students)
                              .where(classroom_students: { student_id:, left_at: nil }, status: "active",
                                     school_year: Entities::Classroom::SchoolYear.current(today))
                              .distinct.pluck(:level_id, :series_id)
        pairs = last_known(student_id) if pairs.empty?
        Entities::Catalog::LevelAudience.new(pairs:)
      end

      private

      def last_known(student_id)
        pair = Orm::ClassroomStudent.joins(:classroom).where(student_id:, primary: true).order(LAST_FIRST)
                                    .pick("classrooms.level_id", "classrooms.series_id")
        pair ? [ pair ] : []
      end
    end
  end
end
