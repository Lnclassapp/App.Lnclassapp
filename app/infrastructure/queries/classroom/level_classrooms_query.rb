# 🔌 INFRA · Queries::Classroom::LevelClassroomsQuery
# Rôle : classes de la cascade élève : celles, actives et de l'année, d'un niveau d'un établissement actif ; nom et « complète »
# ADR  : 0041, 0062, 0085 · UDR : 0081
module Queries
  module Classroom
    class LevelClassroomsQuery
      # full : l'effectif actif atteint le plafond. Jamais l'effectif, le plafond, un enseignant, un élève ni le jeton (IL-04).
      Row = Data.define(:public_id, :name, :full)

      FULL = Arel.sql(<<~SQL.squish)
        (SELECT COUNT(*) FROM classroom_students
          WHERE classroom_students.classroom_id = classrooms.id AND classroom_students.left_at IS NULL) >= classrooms.max_students
      SQL

      # Lecture publique, sans use case (ADR-0062). Établissement inconnu ou inactif, niveau inconnu → [].
      # → [Row], « 3e 2 » avant « 3e 10 »
      def call(school_public_id:, level_slug:, school_year: Entities::Classroom::SchoolYear.current(Date.current))
        Orm::Classroom.joins(:school, :level)
                      .where(schools: { public_id: school_public_id, status: "active" }, levels: { slug: level_slug },
                             status: "active", school_year:)
                      .pluck(:public_id, :name, FULL).map { Row.new(*it) }.sort_by { natural_key(it.name) }
      end

      private

      # Les nombres se comparent comme des nombres, pas comme du texte.
      def natural_key(name)
        name.scan(/\d+|\D+/).map { |part| part.match?(/\A\d/) ? [ 0, part.to_i ] : [ 1, part ] }
      end
    end
  end
end
