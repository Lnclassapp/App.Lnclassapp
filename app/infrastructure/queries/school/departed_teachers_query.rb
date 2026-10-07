# 🔌 INFRA · Queries::School::DepartedTeachersQuery
# Rôle : « Enseignants retirés » de la direction : départs ouverts de l'établissement, enseignant sans établissement depuis
# ADR  : 0006, 0071 · UDR : 0056 · deux requêtes, quel que soit le volume
module Queries
  module School
    class DepartedTeachersQuery
      Overview = Data.define(:school_name, :school_active, :teachers)
      Row = Data.define(:public_id, :name, :material_name, :material_category, :detached_at)

      ACTIVE = "active".freeze
      FULL_NAME = Arel.sql("users.first_name || ' ' || users.last_name")
      # Une école principale depuis, quelle qu'elle soit : il n'est plus à réintégrer (ReinstateTeacher, primary_school_id_for).
      WITHOUT_SCHOOL = "NOT EXISTS (SELECT 1 FROM teacher_schools WHERE teacher_schools.teacher_id = " \
                       "teacher_school_departures.teacher_id AND teacher_schools.\"primary\")".freeze

      # school_id vient toujours du compte de la direction (rattachée : SchoolAdmin::BaseController), jamais de l'adresse.
      def call(school_id:)
        name, status = Orm::School.where(id: school_id).pick(:name, :status)
        Overview.new(school_name: name, school_active: status == ACTIVE, teachers: rows(school_id))
      end

      private

      def rows(school_id)
        Orm::TeacherSchoolDeparture.joins(:teacher)
                                   .joins("LEFT JOIN teacher_profiles ON teacher_profiles.user_id = teacher_school_departures.teacher_id")
                                   .joins("LEFT JOIN materials ON materials.id = teacher_profiles.material_id")
                                   .where(school_id:, reinstated_at: nil, users: { anonymized_at: nil })
                                   .where(WITHOUT_SCHOOL)
                                   .order(detached_at: :desc, id: :desc)
                                   .pluck("users.public_id", FULL_NAME, "materials.name", "materials.category", :detached_at)
                                   .map { Row.new(*it) }
      end
    end
  end
end
