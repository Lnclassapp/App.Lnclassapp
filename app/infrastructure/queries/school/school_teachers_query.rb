# 🔌 INFRA · Queries::School::SchoolTeachersQuery
# Rôle : « Enseignants » de la direction : enseignants non anonymisés, matière, classes de l'année ; public_id et prénom pour « Retirer »
# ADR  : 0062, 0063, 0065, 0071 · UDR : 0052, 0056 · trois requêtes, quel que soit le volume
module Queries
  module School
    class SchoolTeachersQuery
      Overview = Data.define(:school_name, :teachers)
      TeacherRow = Data.define(:public_id, :first_name, :name, :material_name, :material_category, :classroom_names)

      FULL_NAME = Arel.sql("users.first_name || ' ' || users.last_name")

      # school_id vient toujours du compte de la direction (ADR-0065), jamais de l'adresse.
      def call(school_id:, school_year: Entities::Classroom::SchoolYear.current(Date.current))
        classrooms = classroom_names(school_id, school_year)
        teachers = teachers(school_id).map do |id, public_id, first_name, name, material_name, material_category|
          TeacherRow.new(public_id:, first_name:, name:, material_name:, material_category:, classroom_names: classrooms.fetch(id, []))
        end
        Overview.new(school_name: Orm::School.where(id: school_id).pick(:name), teachers:)
      end

      private

      # Un enseignant en attente n'a pas de ligne teacher_schools (ADR-0063) : il n'en est pas.
      def teachers(school_id)
        Orm::TeacherSchool.joins(:teacher)
                          .joins("LEFT JOIN teacher_profiles ON teacher_profiles.user_id = teacher_schools.teacher_id")
                          .joins("LEFT JOIN materials ON materials.id = teacher_profiles.material_id")
                          .where(school_id:, users: { anonymized_at: nil })
                          .order("users.last_name", "users.first_name")
                          .pluck(:teacher_id, "users.public_id", "users.first_name", FULL_NAME, "materials.name", "materials.category")
      end

      def classroom_names(school_id, school_year)
        Orm::TeacherClassroom.joins(classroom: :level)
                             .where(classrooms: { school_id:, school_year:, status: "active" })
                             .order("levels.position", "classrooms.name")
                             .pluck(:teacher_id, "classrooms.name")
                             .group_by(&:first).transform_values { it.map(&:last) }
      end
    end
  end
end
