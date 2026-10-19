# 🔌 INFRA · Queries::School::DepartedTeachersQuery
# Rôle : « Enseignants retirés » de la direction : départs ouverts de l'établissement, enseignant qui n'y est plus rattaché,
#        qu'il ait un autre établissement ou non ; rien n'en dit l'autre établissement
# ADR  : 0006, 0071, 0094, 0103 · UDR : 0056, 0100 (§3.3), 0127 (§3.5) · deux requêtes, quel que soit le volume
module Queries
  module School
    class DepartedTeachersQuery
      Overview = Data.define(:school_name, :school_active, :teachers)
      # materials : ses matières dans cet établissement, gardées après le retrait (ADR-0103 §4.1).
      Row = Data.define(:public_id, :name, :materials, :detached_at)

      ACTIVE = "active".freeze
      FULL_NAME = Arel.sql("users.first_name || ' ' || users.last_name")
      # Rattaché de nouveau à CET établissement : il n'est plus à réintégrer. Un autre établissement ne compte pas (ADR-0094).
      NOT_BACK = "NOT EXISTS (SELECT 1 FROM teacher_schools WHERE teacher_schools.teacher_id = " \
                 "teacher_school_departures.teacher_id AND teacher_schools.school_id = teacher_school_departures.school_id)".freeze

      # school_id vient toujours du compte de la direction (rattachée : SchoolAdmin::BaseController), jamais de l'adresse.
      def call(school_id:)
        name, status = Orm::School.where(id: school_id).pick(:name, :status)
        Overview.new(school_name: name, school_active: status == ACTIVE, teachers: rows(school_id))
      end

      private

      def rows(school_id)
        materials = Queries::Identity::TeacherMaterialsQuery.column(teacher: "teacher_school_departures.teacher_id",
                                                                    school: "teacher_school_departures.school_id")
        Orm::TeacherSchoolDeparture.joins(:teacher)
                                   .where(school_id:, reinstated_at: nil, users: { anonymized_at: nil })
                                   .where(NOT_BACK)
                                   .order(detached_at: :desc, id: :desc)
                                   .pluck("users.public_id", FULL_NAME, materials, :detached_at)
                                   .map do |public_id, name, tags, detached_at|
                                     Row.new(public_id:, name:, materials: Queries::Identity::TeacherMaterialsQuery.from_json(tags), detached_at:)
                                   end
      end
    end
  end
end
