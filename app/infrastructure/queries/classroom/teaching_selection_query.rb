# 🔌 INFRA · Queries::Classroom::TeachingSelectionQuery
# Rôle : classes actives de l'école principale et de l'année en cours, par niveau, chacune déclarée ou non ; onboarding fini ou non
# ADR  : 0026, 0030, 0041 · UDR : 0025
module Queries
  module Classroom
    class TeachingSelectionQuery
      Row = Data.define(:school_name, :onboarded, :levels) do
        def declared_count = levels.sum { |level| level.classrooms.count(&:declared) }
      end
      LevelRow = Data.define(:name, :classrooms)
      ClassroomRow = Data.define(:public_id, :name, :declared)

      COLUMNS = [ "levels.position", "levels.name", "classrooms.id", "classrooms.public_id", "classrooms.name" ].freeze

      # today : fixe l'année scolaire (ADR-0041).
      def call(teacher_id:, school_id:, today: Date.current)
        classrooms = Orm::Classroom.joins(:level)
                                   .where(school_id:, status: "active", school_year: Entities::Classroom::SchoolYear.current(today))
                                   .pluck(*COLUMNS)
        declared = Orm::TeacherClassroom.where(teacher_id:, classroom_id: classrooms.map { it[2] }).pluck(:classroom_id).to_set

        Row.new(school_name: Orm::School.where(id: school_id).pick(:name), onboarded: onboarded?(teacher_id),
                levels: levels(classrooms, declared))
      end

      private

      # L'onboarding est un état enregistré, jamais déduit des classes déclarées.
      def onboarded?(teacher_id)
        Orm::TeacherProfile.where(user_id: teacher_id).where.not(onboarding_completed_at: nil).exists?
      end

      def levels(classrooms, declared)
        classrooms.group_by { it.first(2) }.sort_by { |(position, _), _| position }.map do |(_, name), rows|
          LevelRow.new(name:, classrooms: rows.sort_by { natural_key(it.last) }.map do |*, id, public_id, classroom_name|
            ClassroomRow.new(public_id:, name: classroom_name, declared: declared.include?(id))
          end)
        end
      end

      # « 6ème 2 » avant « 6ème 10 » : les nombres se comparent comme des nombres, pas comme du texte.
      def natural_key(name)
        name.scan(/\d+|\D+/).map { |part| part.match?(/\A\d/) ? [ 0, part.to_i ] : [ 1, part ] }
      end
    end
  end
end
