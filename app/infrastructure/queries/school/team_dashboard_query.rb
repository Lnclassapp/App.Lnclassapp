# 🔌 INFRA · Queries::School::TeamDashboardQuery
# Rôle : pilotage de l'équipe (TR-10, TR-12) : indicateurs, élèves par niveau, par DRENA ou par établissement, derniers inscrits
# ADR  : 0040, 0041, 0049, 0062, 0082, 0084, 0085 · UDR : 0049, 0078 · un nombre fixe de requêtes groupées, quel que soit le volume
module Queries
  module School
    class TeamDashboardQuery
      # school_rows : sous un filtre DRENA, les lignes de tous ses établissements (DrenaSchoolsQuery#rows), lues avec les
      # chiffres ; nil en vue nationale.
      Row = Data.define(:period, :school_year, :drena, :accounts, :signups_count, :active_students_count,
                        :completed_sessions_count, :average_score, :assignments_count, :app_openers, :schools, :classrooms_count,
                        :levels, :placed_students_count, :unplaced_students_count, :drenas, :school_rows, :recent_signups)
      Filter = Data.define(:public_id, :name)
      # team : nil sous un filtre DRENA, l'équipe n'ayant pas de territoire.
      Accounts = Data.define(:students, :teachers, :team)
      # ADR-0082 §4.4 : comptes ouverts depuis l'icône de l'app installée (navigateur ou Android) pendant la période, par
      # rôle ; android_students, ADR-0084 §4.6 : ceux de ces élèves qui l'ont ouverte depuis l'app Android ;
      # android_teachers, ADR-0085 §4.6 : ceux de ces enseignants qui l'ont ouverte depuis « Lnclass Teacher ».
      AppOpeners = Data.define(:students, :teachers, :android_students, :android_teachers)
      Coverage = Data.define(:active, :with_classroom, :with_teacher, :with_student)
      LevelShare = Data.define(:slug, :name, :students_count, :percent)
      DrenaRow = Data.define(:public_id, :name, :schools_count, :classrooms_count, :teachers_count, :students_count,
                             :active_students_count)
      # contact : toujours masqué (Entities::Identity::Contact.mask) ; le numéro complet ne quitte pas cette query.
      SignupRow = Data.define(:public_id, :display_name, :role, :school_name, :contact, :created_at)
      # Élèves placés d'un couple (niveau, DRENA), et combien sont actifs dans la période.
      Placed = Data.define(:level_id, :drena_id, :students, :active)

      RECENT = 10
      # ADR-0062, amendement du 2026-09-29 : les chiffres de l'année scolaire sont gardés 5 minutes ; 7 et 30 jours restent
      # lus en direct. Changer une définition ou la forme des chiffres, c'est changer CACHE_VERSION (2 : les lignes
      # d'établissements sous filtre, amendement du 2026-10-04 ; 3 : les ouvertures depuis l'app installée, ADR-0082 ;
      # 4 : l'app Android, ADR-0084 ; 5 : la part Android des enseignants, ADR-0085).
      CACHED_PERIODS = %w[year].freeze
      CACHE_TTL = 5.minutes
      CACHE_VERSION = 5

      # Une seule lecture : les établissements actifs, et combien ont une classe, un enseignant, un élève (élève placé :
      # ADR-0062). SQL constant : seule l'année scolaire est liée.
      COVERAGE = [
        "COUNT(*)",
        "COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM classrooms WHERE classrooms.school_id = schools.id " \
        "AND classrooms.status = 'active' AND classrooms.school_year = :year))",
        "COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM teacher_schools JOIN users ON users.id = teacher_schools.teacher_id " \
        "WHERE teacher_schools.school_id = schools.id AND users.anonymized_at IS NULL))",
        "COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM classroom_students " \
        "JOIN classrooms ON classrooms.id = classroom_students.classroom_id JOIN users ON users.id = classroom_students.student_id " \
        "WHERE classrooms.school_id = schools.id AND classroom_students.primary AND classroom_students.left_at IS NULL " \
        "AND classrooms.status = 'active' AND classrooms.school_year = :year AND users.anonymized_at IS NULL))"
      ].freeze

      # cache : Rails.cache (Solid Cache en production) ; un test passe un NullStore pour lire en direct.
      def initialize(cache: Rails.cache)
        @cache = cache
      end

      # period : Entities::School::ReportingPeriod ; une DRENA inconnue donne la vue nationale.
      def call(period:, drena_public_id: nil, today: Date.current)
        @year = Entities::Classroom::SchoolYear.current(today)
        @since = period.since.in_time_zone
        drena_id, drena = find_drena(drena_public_id)
        @drena_id = drena_id
        values = if CACHED_PERIODS.include?(period.key)
          @cache.fetch(cache_key(period, drena), expires_in: CACHE_TTL) { figures(drena) }
        else
          figures(drena)
        end

        # Les derniers inscrits ne sont jamais gardés : ce sont des comptes (noms), et ils doivent apparaître tout de suite.
        Row.new(period:, school_year: @year, drena:, **values, recent_signups:)
      end

      private

      # Tout le reste de la page : des agrégats, sans aucune donnée personnelle. Sous un filtre, les établissements de la
      # DRENA sont lus ici, avec les chiffres : la page ne mêle jamais deux instants (UDR-0068 règle 8, ADR-0062,
      # amendement du 2026-10-04).
      def figures(drena)
        placed = placed_students
        placed_count = placed.sum(&:students)
        accounts = accounts_by_role(placed_count)
        { accounts:, **flows, schools: coverage, classrooms_count: classrooms.count, levels: levels(tally(placed, :level_id)),
          placed_students_count: placed_count, unplaced_students_count: (accounts.students - placed_count if drena.nil?),
          drenas: drena_rows(placed), school_rows: (DrenaSchoolsQuery.new.rows(drena_id: @drena_id, year: @year, since: @since) if drena) }
      end

      # Une entrée par année scolaire, début de période et DRENA résolue (une DRENA inconnue lit la vue nationale) ; aucune
      # valeur venue telle quelle de l'URL, aucune donnée d'acteur.
      def cache_key(period, drena)
        [ "team_dashboard", "v#{CACHE_VERSION}", period.key, @year, period.since.iso8601, drena&.public_id || "national" ].join("/")
      end

      def find_drena(public_id)
        return if public_id.blank?

        id, found_public_id, name = Orm::Drena.where(public_id: public_id.to_s).pick(:id, :public_id, :name)
        [ id, Filter.new(public_id: found_public_id, name:) ] if id
      end

      # Un élève est placé par sa classe principale, non quittée, active, de l'année scolaire (ADR-0040, ADR-0041).
      def placements(territorial: true)
        scope = Orm::ClassroomStudent.joins(:student, classroom: :school)
                                     .where(primary: true, left_at: nil, users: { anonymized_at: nil },
                                            classrooms: { status: "active", school_year: @year })
        territorial ? in_drena(scope) : scope
      end

      # Un enseignant est rattaché à la DRENA de son établissement principal (ADR-0030).
      def teacher_placements
        in_drena(Orm::TeacherSchool.joins(:teacher, :school).where(primary: true, users: { anonymized_at: nil }))
      end

      def in_drena(scope) = @drena_id ? scope.where(schools: { drena_id: @drena_id }) : scope

      def active_users = Orm::User.where(anonymized_at: nil)

      # Sous un filtre, seuls comptent les élèves placés et les enseignants rattachés à la DRENA.
      def territorial_users
        return active_users unless @drena_id

        Orm::User.where(id: placements.select(:student_id)).or(Orm::User.where(id: teacher_placements.select(:teacher_id)))
      end

      # placed_count : sous un filtre, les élèves du territoire sont ses élèves placés.
      def accounts_by_role(placed_count)
        return Accounts.new(students: placed_count, teachers: teacher_placements.count, team: nil) if @drena_id

        counts = active_users.group(:role).count
        Accounts.new(students: counts.fetch("student", 0), teachers: counts.fetch("teacher", 0), team: counts.fetch("team", 0))
      end

      def flows
        completed_count, average = sessions.where(status: "completed", completed_at: @since..)
                                           .pick(Arel.sql("COUNT(*)"), Arel.sql("ROUND(AVG(score_percent))"))
        { signups_count: territorial_users.where(created_at: @since..).count,
          active_students_count: sessions.where(started_at: @since..).distinct.count(:student_id),
          completed_sessions_count: completed_count, average_score: average&.to_i,
          assignments_count: in_drena(Orm::ClassroomAssignment.joins(classroom: :school).where(assigned_at: @since..)).count,
          app_openers: }
      end

      # ADR-0082 §4.4, ADR-0084 §4.6, ADR-0085 §4.6 : une seule lecture groupée par rôle, sur les comptes du territoire (non anonymisés),
      # comme les inscrits. Un compte ouvert par les deux canaux compte une fois ; la part Android en est un sous-ensemble.
      def app_openers
        users = Orm::User.arel_table
        android = users[:android_opened_at].gteq(@since)
        rows = territorial_users.where(anonymized_at: nil).where(users[:app_opened_at].gteq(@since).or(android)).group(:role)
                                .pluck(:role, Arel.star.count, Arel.star.count.filter(android))
        counts = Hash.new([ 0, 0 ]).merge(rows.to_h { |role, *values| [ role, values ] })
        students, android_students = counts["student"]
        teachers, android_teachers = counts["teacher"]
        AppOpeners.new(students:, teachers:, android_students:, android_teachers:)
      end

      def sessions
        scope = Orm::ExerciseSession.joins(:student).where(users: { anonymized_at: nil })
        @drena_id ? scope.where(student_id: placements.select(:student_id)) : scope
      end

      def classrooms = in_drena(Orm::Classroom.joins(:school).where(status: "active", school_year: @year))

      def coverage
        columns = COVERAGE.map { Arel.sql(Orm::School.sanitize_sql_array([ it, { year: @year } ])) }
        active, with_classroom, with_teacher, with_student = in_drena(Orm::School.where(status: "active")).pick(*columns)
        Coverage.new(active:, with_classroom:, with_teacher:, with_student:)
      end

      # Une seule lecture des élèves placés, groupée par (niveau, DRENA) : le total, la répartition par niveau et les lignes
      # par DRENA en découlent, sur la même définition. Actif : au moins une session commencée dans la période (ADR-0062).
      def placed_students
        started = Orm::ExerciseSession.where(started_at: @since..).select(:student_id).to_sql
        placements.group("classrooms.level_id", "schools.drena_id")
                  .pluck("classrooms.level_id", "schools.drena_id", Arel.sql("COUNT(*)"),
                         Arel.sql("COUNT(*) FILTER (WHERE classroom_students.student_id IN (#{started}))"))
                  .map { Placed.new(*it) }
      end

      # { niveau ou DRENA => nombre }
      def tally(placed, key, value = :students) = placed.group_by(&key).transform_values { |rows| rows.sum(&value) }

      # Tous les niveaux, par position, même vides : la répartition se lit sur l'échelle entière (TR-12).
      def levels(placed)
        total = placed.values.sum
        Orm::Level.order(:position).pluck(:id, :slug, :name).map do |id, slug, name|
          count = placed.fetch(id, 0)
          LevelShare.new(slug:, name:, students_count: count, percent: total.zero? ? 0 : (count * 100.0 / total).round)
        end
      end

      # Une lecture groupée par dimension, jamais une par DRENA ; tri par élèves décroissants, puis par nom.
      def drena_rows(placed)
        counts = {
          schools_count: in_drena(Orm::School.where(status: "active")).group(:drena_id).count,
          classrooms_count: classrooms.group("schools.drena_id").count,
          teachers_count: teacher_placements.group("schools.drena_id").count,
          students_count: tally(placed, :drena_id),
          active_students_count: tally(placed, :drena_id, :active)
        }
        drenas = @drena_id ? Orm::Drena.where(id: @drena_id) : Orm::Drena.all
        rows = drenas.order(:name).pluck(:id, :public_id, :name).map do |id, public_id, name|
          DrenaRow.new(public_id:, name:, **counts.transform_values { it.fetch(id, 0) })
        end
        rows.sort_by.with_index { |row, index| [ -row.students_count, index ] }
      end

      def recent_signups
        users = territorial_users.where(anonymized_at: nil).order(created_at: :desc, id: :desc).limit(RECENT)
                                 .pluck(:id, :public_id, :first_name, :last_name, :role, :contact, :created_at)
        ids = users.map(&:first)
        schools = placements(territorial: false).where(student_id: ids).pluck(:student_id, "schools.name").to_h
                                                .merge(Orm::TeacherSchool.joins(:school).where(teacher_id: ids, primary: true)
                                                                          .pluck(:teacher_id, "schools.name").to_h)
        users.map do |id, public_id, first_name, last_name, role, contact, created_at|
          SignupRow.new(public_id:, display_name: "#{first_name} #{last_name}", role: role.to_sym, school_name: schools[id],
                        contact: Entities::Identity::Contact.mask(contact), created_at:)
        end
      end
    end
  end
end
