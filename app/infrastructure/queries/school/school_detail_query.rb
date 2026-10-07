# 🔌 INFRA · Queries::School::SchoolDetailQuery
# Rôle : fiche d'un établissement (SC-05) : en-tête, code et lien de l'équipe, classes par niveau, enseignants et leur voie
# ADR  : 0026, 0030, 0041, 0057, 0063, 0082 · UDR : 0036, 0044, 0050, 0078
module Queries
  module School
    class SchoolDetailQuery
      Detail = Data.define(:public_id, :name, :sigle, :drena_name, :school_type, :cycle, :status, :school_code, :school_year, :levels,
                           :teachers, :national_code, :team_invite_token) do
        def classrooms_count = levels.sum { it.classrooms.size }
      end
      Level = Data.define(:name, :classrooms)
      ClassroomRow = Data.define(:public_id, :name, :join_code_display, :students_count, :teacher_names, :status)
      # joined_via : voie d'arrivée (ADR-0082 §4.2) ; referrer_name : « NOM Prénoms » du parrain, nil sans parrain ou anonymisé.
      TeacherRow = Data.define(:name, :material_name, :material_category, :primary, :joined_via, :referrer_name)

      SCHOOL_COLUMNS = %w[schools.id schools.public_id schools.name schools.sigle drenas.name schools.school_type schools.cycle
                          schools.status schools.school_code schools.national_code schools.team_invite_token].freeze
      CLASSROOM_COLUMNS = %w[classrooms.id classrooms.public_id classrooms.name classrooms.join_code classrooms.status
                             levels.name levels.position series.name].freeze
      FULL_NAME = Arel.sql("users.first_name || ' ' || users.last_name")
      TEACHER_COLUMNS = [ FULL_NAME, "materials.name", "materials.category", :primary, "teacher_profiles.joined_via",
                          Arel.sql("referrers.last_name || ' ' || referrers.first_name") ].freeze

      # → Detail | nil
      def call(public_id:, school_year: Entities::Classroom::SchoolYear.current(Date.current))
        id, public_id, name, sigle, drena_name, school_type, cycle, status, school_code, national_code, team_invite_token =
          Orm::School.joins(:drena).where(public_id:).pick(*SCHOOL_COLUMNS)
        return if id.nil?

        Detail.new(public_id:, name:, sigle:, drena_name:, school_type:, cycle:, status:, school_code:, school_year:,
                   levels: levels(id, school_year), teachers: teachers(id), national_code:, team_invite_token:)
      end

      private

      def levels(school_id, school_year)
        classrooms = Orm::Classroom.joins(:level).left_joins(:series).where(school_id:, school_year:).pluck(*CLASSROOM_COLUMNS)
        ids = classrooms.map(&:first)
        students = Orm::ClassroomStudent.where(classroom_id: ids, left_at: nil).group(:classroom_id).count
        teachers = Orm::TeacherClassroom.joins(:teacher).where(classroom_id: ids).order("users.last_name", "users.first_name")
                                        .pluck(:classroom_id, FULL_NAME).group_by(&:first)

        classrooms.sort_by { |_, _, name, _, _, _, position, series| [ position, series.to_s, name[/\d+\z/].to_i, name ] }
                  .chunk_while { |left, right| left[6] == right[6] }
                  .map { |group| Level.new(name: group.first[5], classrooms: group.map { classroom_row(it, students, teachers) }) }
      end

      def classroom_row(values, students, teachers)
        id, public_id, name, join_code, status = values
        ClassroomRow.new(public_id:, name:, join_code_display: Entities::Classroom::JoinCode.display(join_code),
                         students_count: students.fetch(id, 0), teacher_names: teachers.fetch(id, []).map(&:last), status:)
      end

      def teachers(school_id)
        Orm::TeacherSchool.joins(:teacher)
                          .joins("LEFT JOIN teacher_profiles ON teacher_profiles.user_id = teacher_schools.teacher_id")
                          .joins("LEFT JOIN materials ON materials.id = teacher_profiles.material_id")
                          .joins("LEFT JOIN referrals ON referrals.referee_id = teacher_schools.teacher_id")
                          .joins("LEFT JOIN users referrers ON referrers.id = referrals.referrer_id AND referrers.anonymized_at IS NULL")
                          .where(school_id:).order(primary: :desc).order("users.last_name", "users.first_name")
                          .pluck(*TEACHER_COLUMNS).map { TeacherRow.new(*it) }
      end
    end
  end
end
