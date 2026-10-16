# 🔌 INFRA · Queries::Classroom::ClassroomChangePreviewQuery
# Rôle : « Changer de classe » : la classe actuelle de l'élève, et la classe visée (cascade ou lien) relue côté serveur pour la confirmation
# ADR  : 0041, 0062, 0085, 0095 · UDR : 0102
module Queries
  module Classroom
    class ClassroomChangePreviewQuery
      # Les identifiants de la cascade (établissement, niveau, DRENA) replient l'étape 1 et la page de confirmation les renvoie.
      Side = Data.define(:public_id, :name, :level_name, :level_slug, :school_name, :school_public_id, :drena_public_id, :full)

      COLUMNS = [ "classrooms.public_id", "classrooms.name", "levels.name", "levels.slug", "schools.name", "schools.public_id",
                  "drenas.public_id", Queries::Classroom::LevelClassroomsQuery::FULL ].freeze

      # La classe principale active de l'élève, dans une classe active. → Side | nil
      def current(student_id:)
        side(classrooms.joins(:classroom_students)
                       .where(status: "active", classroom_students: { student_id:, primary: true, left_at: nil }))
      end

      # ADR-0085 §4.2 : seulement une classe que la cascade propose (active, de l'année, du niveau et de l'établissement
      # actif envoyés). La garde reste ChangeClassroom ; cette lecture ne sert qu'à montrer. → Side | nil
      def chosen(school_public_id:, level_slug:, classroom_public_id:, school_year: Entities::Classroom::SchoolYear.current(Date.current))
        return unless classroom_public_id

        side(classrooms.where(public_id: classroom_public_id, status: "active", school_year:,
                              schools: { public_id: school_public_id, status: "active" }, levels: { slug: level_slug }))
      end

      # ADR-0085 §4.1 : la classe d'un lien valide, active, d'un établissement actif. → Side | nil
      def linked(token:)
        return unless token

        side(classrooms.where(link_token: token, status: "active", schools: { status: "active" }))
      end

      private

      def classrooms = Orm::Classroom.joins(:level, school: :drena)

      def side(scope)
        values = scope.pick(*COLUMNS)
        values && Side.new(*values)
      end
    end
  end
end
