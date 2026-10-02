# 🔌 INFRA · Queries::Classroom::StudentClassroomQuery
# Rôle : « Ma classe » (CL-22) : la classe principale active de l'élève et ses cours assignés actifs et publiés, sans élèves
# ADR  : 0026, 0035, 0048 · UDR : 0011 · le code de la classe vient de ClassroomHeaderQuery, sous ReadClassroomPolicy
module Queries
  module Classroom
    class StudentClassroomQuery
      # courses : les CourseRow de ClassroomOverviewQuery, lus sans show_roster — la liste nominative n'est jamais lue.
      Row = Data.define(:public_id, :classroom_name, :level_name, :series_name, :school_name, :school_year, :courses)

      COLUMNS = [ "classrooms.public_id", "classrooms.name", "levels.name", "series.name", "schools.name",
                  "classrooms.school_year" ].freeze

      # → Row | nil (aucune classe principale active : l'élève n'a pas de classe à ouvrir)
      def call(student_id:)
        primary = Orm::ClassroomStudent.where(student_id:, primary: true, left_at: nil).select(:classroom_id)
        public_id, classroom_name, level_name, series_name, school_name, school_year =
          Orm::Classroom.joins(:level, :school).left_joins(:series).where(id: primary, status: "active").pick(*COLUMNS)
        return if public_id.nil?

        Row.new(public_id:, classroom_name:, level_name:, series_name:, school_name:, school_year:,
                courses: ClassroomOverviewQuery.new.call(public_id:, show_roster: false).courses)
      end
    end
  end
end
