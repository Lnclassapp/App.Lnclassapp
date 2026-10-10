# 🔌 INFRA · Queries::School::SchoolDetailQuery
# Rôle : fiche d'un établissement (SC-05) : en-tête, code et lien de l'équipe, classes par niveau et leur lien (jamais de code de classe), enseignants, leur voie et leur parrain ici
# ADR  : 0026, 0030, 0041, 0057, 0063, 0083, 0085, 0088 · UDR : 0036, 0044, 0050, 0079, 0081 (§3.7), 0083
module Queries
  module School
    class SchoolDetailQuery
      Detail = Data.define(:public_id, :name, :sigle, :drena_name, :school_type, :cycle, :status, :school_code, :school_year, :levels,
                           :teachers, :national_code, :team_invite_token, :archives_shown) do
        # Les classes archivées ne comptent dans aucun total (ADR-0088).
        def classrooms_count = levels.sum { it.classrooms.size }
        def hidden_archives_count = levels.sum(&:hidden_count)
        def archived_total = levels.sum { it.archived.size + it.hidden_count }
      end
      # classrooms : les actives ; archived : les archivées visibles (7 jours, ou toutes avec ?archives=1), en fin de niveau ;
      # hidden_count : celles qui restent masquées. students_count et teachers_count : les actives seules, pour la confirmation.
      Level = Data.define(:name, :slug, :classrooms, :archived, :hidden_count, :students_count, :teachers_count)
      # link_token : le jeton du lien /c/<jeton> (ADR-0085 §4.1), que l'équipe copie.
      ClassroomRow = Data.define(:public_id, :name, :link_token, :students_count, :teacher_names, :status)
      # joined_via : voie d'arrivée (ADR-0083 §4.2) ; referrer_name : « NOM Prénoms » du parrain, nil sans parrain, anonymisé,
      # ou parrain d'un autre établissement (l'enseignant parrainé ailleurs puis rattaché ici garde sa voie, sans nom).
      TeacherRow = Data.define(:name, :material_name, :material_category, :primary, :joined_via, :referrer_name)

      SCHOOL_COLUMNS = %w[schools.id schools.public_id schools.name schools.sigle drenas.name schools.school_type schools.cycle
                          schools.status schools.school_code schools.national_code schools.team_invite_token].freeze
      CLASSROOM_COLUMNS = %w[classrooms.id classrooms.public_id classrooms.name classrooms.link_token classrooms.status
                             levels.name levels.position series.name levels.slug classrooms.archived_at].freeze
      # ADR-0088 : une classe archivée reste visible sept jours.
      ARCHIVE_WINDOW = 7.days
      FULL_NAME = Arel.sql("users.first_name || ' ' || users.last_name")
      TEACHER_COLUMNS = [ FULL_NAME, "materials.name", "materials.category", :primary, "teacher_profiles.joined_via",
                          Arel.sql("referrers.last_name || ' ' || referrers.first_name") ].freeze

      # → Detail | nil
      def call(public_id:, school_year: Entities::Classroom::SchoolYear.current(Date.current), archives: false, now: Time.current)
        id, public_id, name, sigle, drena_name, school_type, cycle, status, school_code, national_code, team_invite_token =
          Orm::School.joins(:drena).where(public_id:).pick(*SCHOOL_COLUMNS)
        return if id.nil?

        Detail.new(public_id:, name:, sigle:, drena_name:, school_type:, cycle:, status:, school_code:, school_year:,
                   levels: levels(id, school_year, archives, now), teachers: teachers(id), national_code:, team_invite_token:,
                   archives_shown: archives)
      end

      private

      def levels(school_id, school_year, archives, now)
        classrooms = Orm::Classroom.joins(:level).left_joins(:series).where(school_id:, school_year:).pluck(*CLASSROOM_COLUMNS)
        ids = classrooms.map(&:first)
        students = Orm::ClassroomStudent.where(classroom_id: ids, left_at: nil).group(:classroom_id).count
        teachers = Orm::TeacherClassroom.joins(:teacher).where(classroom_id: ids).order("users.last_name", "users.first_name")
                                        .pluck(:classroom_id, FULL_NAME, :teacher_id).group_by(&:first)

        classrooms.sort_by { |_, _, name, _, _, _, position, series| [ position, series.to_s, name[/\d+\z/].to_i, name ] }
                  .chunk_while { |left, right| left[6] == right[6] }
                  .map { |group| level(group, students, teachers, archives, now) }
      end

      def level(group, students, teachers, archives, now)
        archived, active = group.partition { it[4] == "archived" }
        shown = archives ? archived : archived.select { it[9] > now - ARCHIVE_WINDOW }
        rows = ->(list) { list.map { classroom_row(it, students, teachers) } }
        Level.new(name: group.first[5], slug: group.first[8], classrooms: rows.(active), archived: rows.(shown),
                  hidden_count: archived.size - shown.size, students_count: active.sum { students.fetch(it.first, 0) },
                  teachers_count: active.flat_map { teachers.fetch(it.first, []).map(&:last) }.uniq.size)
      end

      def classroom_row(values, students, teachers)
        id, public_id, name, link_token, status = values
        ClassroomRow.new(public_id:, name:, link_token:,
                         students_count: students.fetch(id, 0), teacher_names: teachers.fetch(id, []).map { it[1] }, status:)
      end

      def teachers(school_id)
        Orm::TeacherSchool.joins(:teacher)
                          .joins("LEFT JOIN teacher_profiles ON teacher_profiles.user_id = teacher_schools.teacher_id")
                          .joins("LEFT JOIN materials ON materials.id = teacher_profiles.material_id")
                          .joins("LEFT JOIN referrals ON referrals.referee_id = teacher_schools.teacher_id " \
                                 "AND referrals.school_id = teacher_schools.school_id")
                          .joins("LEFT JOIN users referrers ON referrers.id = referrals.referrer_id AND referrers.anonymized_at IS NULL")
                          .where(school_id:).order(primary: :desc).order("users.last_name", "users.first_name")
                          .pluck(*TEACHER_COLUMNS).map { TeacherRow.new(*it) }
      end
    end
  end
end
