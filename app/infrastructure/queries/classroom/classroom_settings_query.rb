# 🔌 INFRA · Queries::Classroom::ClassroomSettingsQuery
# Rôle : ce que la modale « Modifier la classe » préremplit : nom, préfixe fixe du barème, suffixe, plafond, effectif présent
# ADR  : 0098 · UDR : 0110 · une classe de l'établissement donné et de l'année en cours, sinon nil
module Queries
  module Classroom
    class ClassroomSettingsQuery
      NUMBERING = Entities::Classroom::ClassroomNumbering
      NAME_MAX = Entities::Classroom::Classroom::NAME_MAX

      Row = Data.define(:public_id, :name, :prefix, :level_slug, :status, :max_students, :headcount) do
        def suffix = NUMBERING.suffix_of(name:, prefix:)
        # Le nom saisi librement avant l'ADR-0098 ne vient pas du préfixe : il sera remplacé (UDR-0110).
        def free_name? = suffix.empty?
        def archived? = status == "archived"
        # Place du suffixe dans les 15 caractères, après le préfixe et son espace.
        def suffix_max = NAME_MAX - prefix.length - 1
      end

      COLUMNS = [ "classrooms.id", "classrooms.public_id", "classrooms.name", "levels.name", "series.name", "levels.slug",
                  "classrooms.status", "classrooms.max_students" ].freeze

      # school : { id: } (direction, current_actor.school_id) ou { public_id: } (équipe, fiche d'un établissement). → Row | nil
      def call(public_id:, school:, on: Date.current)
        id, public_id, name, level_name, series_name, level_slug, status, max_students =
          Orm::Classroom.joins(:level, :school).left_joins(:series)
                        .where(public_id:, school_year: Entities::Classroom::SchoolYear.current(on), schools: school)
                        .pick(*COLUMNS)
        return if id.nil?

        Row.new(public_id:, name:, prefix: NUMBERING.prefix(level_name:, series_name:), level_slug:, status:, max_students:,
                headcount: Orm::ClassroomStudent.where(classroom_id: id, left_at: nil).count)
      end
    end
  end
end
