# 🔌 INFRA · Queries::Classroom::StudentHomeQuery
# Rôle : accueil élève (CL-23, TR-04, AS-36) : classe, matières, exercices assignés triés par échéance, activité, lacunes ; sans classe, la dernière et un retrait récent
# ADR  : 0026, 0033, 0035, 0043, 0048, 0072, 0083 · UDR : 0010, 0062 (§3.2 ordre, §3.3 `late_material_slugs`), 0076 (§3.1, §3.2), 0079 (§3.5)
module Queries
  module Classroom
    class StudentHomeQuery
      # late_material_slugs : les matières où un exercice est en retard pour l'élève, pastille de « Mes matières » (UDR-0062
      # §3.3, UDR-0076 §3.1) ; subjects : les matières qui ont un cours publié de son niveau.
      Row = Data.define(:school_name, :level_name, :classroom_name, :join_code_display, :classmates_count,
                        :assigned_exercises, :recent_sessions, :pending_gaps, :late_material_slugs, :subjects)
      # badge_level : bronze, silver, gold, diamond ou nil ; started_session_public_id : la session à reprendre, ou nil ;
      # due_on : l'échéance de l'assignation (ADR-0072), nil sans jours de séance.
      ExerciseRow = Data.define(:public_id, :title, :material_name, :material_category, :badge_level,
                                :best_score_percent, :completed_count, :started_session_public_id, :due_on)
      SessionRow = Data.define(:public_id, :exercise_title, :score_percent, :completed_at)
      GapRow = Data.define(:essential_name, :essential_slug, :course_slug)
      SubjectRow = Data.define(:slug, :name)
      # L'élève sans classe active (UDR-0079 §3.5) : la DRENA et l'établissement de sa dernière classe principale, qui
      # préremplissent « Choisis ta classe » ; recent_removal_at : l'heure du retrait qui l'en a fait sortir, s'il est récent.
      LastClassroom = Data.define(:drena_public_id, :school_public_id, :recent_removal_at)

      RECENT_SESSIONS = 10
      # Un retrait est récent pendant 7 jours, la durée de la marque « Nouveau » (ADR-0083 §4.4) : un calcul de lecture,
      # sans colonne. Au-delà, l'accueil propose de choisir une classe sans revenir sur le départ.
      RECENT_REMOVAL = 7.days
      # La dernière adhésion principale : celle encore ouverte (classe archivée) d'abord, puis la plus récemment quittée.
      LAST_FIRST = Arel.sql("classroom_students.left_at DESC NULLS FIRST, classroom_students.joined_at DESC, classroom_students.id DESC")
      # L'ordre de la grille de la charte (§9) ; une matière hors de cette liste suit, par nom.
      SUBJECT_ORDER = %w[mathematiques maths physique-chimie pc svt francais histoire-geographie histoire-geo hg edhc
                         philosophie philo].freeze
      HEADER_COLUMNS = [ "classrooms.id", "schools.name", "levels.name", "classrooms.name", "classrooms.join_code" ].freeze
      EXERCISE_COLUMNS = [ "exercises.id", "exercises.public_id", "exercises.title", "materials.name", "materials.category",
                           "materials.slug", "courses.id", "essentials.position", "exercises.position" ].freeze

      # today : la date d'Abidjan (Time.zone), qui dit si une échéance est passée.
      # → Row | nil (aucune classe principale active : l'élève n'a pas d'accueil)
      def call(student_id:, today: Time.zone.today)
        classroom_id, school_name, level_name, classroom_name, join_code =
          Orm::ClassroomStudent.joins(classroom: %i[school level])
                               .where(student_id:, primary: true, left_at: nil, classrooms: { status: "active" })
                               .pick(*HEADER_COLUMNS)
        return if classroom_id.nil?

        exercises = assigned_with_slugs(classroom_id, student_id)
        Row.new(school_name:, level_name:, classroom_name:, join_code_display: Entities::Classroom::JoinCode.display(join_code),
                classmates_count: Orm::ClassroomStudent.where(classroom_id:, left_at: nil).count,
                assigned_exercises: exercises.map(&:last), recent_sessions: recent_sessions(student_id:),
                pending_gaps: pending_gaps(student_id), late_material_slugs: late_material_slugs(exercises, today),
                subjects: subjects(student_id))
      end

      # Les exercices assignés à la classe, dans l'ordre de « À faire » ; lue aussi par « Ma classe » (UDR-0076 §3.2).
      # → [ExerciseRow]
      def assigned_exercises(classroom_id:, student_id:) = assigned_with_slugs(classroom_id, student_id).map(&:last)

      # → LastClassroom ; tout à nil pour un élève qui n'a jamais eu de classe.
      def last_classroom(student_id:, now: Time.current)
        drena_public_id, school_public_id, removed_at =
          Orm::ClassroomStudent.joins(classroom: { school: :drena }).where(student_id:, primary: true).order(LAST_FIRST)
                               .pick("drenas.public_id", "schools.public_id", :removed_at)
        LastClassroom.new(drena_public_id:, school_public_id:,
                          recent_removal_at: (removed_at if removed_at && removed_at >= now - RECENT_REMOVAL))
      end

      # Lue seule par le frame différé de l'activité récente.
      def recent_sessions(student_id:)
        Orm::ExerciseSession.joins(exercise: { essential: :course }).where(student_id:, status: "completed")
                            .merge(own_level(student_id))
                            .order(completed_at: :desc, id: :desc).limit(RECENT_SESSIONS)
                            .pluck(:public_id, "exercises.title", :score_percent, :completed_at)
                            .map { |public_id, exercise_title, score_percent, completed_at| SessionRow.new(public_id:, exercise_title:, score_percent:, completed_at:) }
      end

      private

      # UDR-0013, amendement du 2026-10-01 : l'accueil ne liste que des contenus que l'élève peut ouvrir, de son niveau.
      # Une assignation, une session ou une lacune antérieure à la règle et hors niveau n'y apparaît plus.
      def own_level(student_id)
        @own_level ||= Queries::Catalog::AudienceFilter.courses(Queries::Catalog::StudentAudienceQuery.new.call(student_id:))
      end

      # ADR-0072 §4.1 : seul un exercice s'assigne ; il ne se lit plus par sa fiche ni par son cours. L'index actif unique
      # garantit une seule ligne par exercice. → [[slug de la matière, ExerciseRow]], dans l'ordre de « À faire ».
      def assigned_with_slugs(classroom_id, student_id)
        assignments = Orm::ClassroomAssignment.where(classroom_id:, status: "active", assignable_type: "Exercise")
                                              .pluck(:assignable_id, :assigned_at, :due_on).to_h { |id, *dates| [ id, dates ] }
        rows = published_exercises(assignments.keys).merge(own_level(student_id)).pluck(*EXERCISE_COLUMNS)
        exercise_rows(rows, assignments, student_id).sort_by(&:first).map { |_, slug, row| [ slug, row ] }
      end

      # UDR-0062 §3.2, dans cet ordre : les non terminés avant les terminés ; par échéance croissante, sans échéance après ;
      # le plus récemment assigné d'abord ; assignés au même instant, l'ordre du cours et de la fiche. Un exercice commencé
      # ne passe pas devant un exercice dû plus tôt (charte §8).
      def urgency(row, assigned_at, *program_order)
        [ row.completed_count.positive? ? 1 : 0, row.due_on ? 0 : 1, row.due_on&.jd.to_i, -assigned_at.to_f, *program_order ]
      end

      # ADR-0072 §4.4 : en retard pour l'élève = non terminé, et l'échéance est passée ; sans échéance, jamais.
      def late_material_slugs(exercises, today)
        exercises.filter_map { |slug, row| slug if row.completed_count.zero? && row.due_on && row.due_on < today }.uniq
      end

      # Un exercice publié dont la fiche et le cours le sont aussi (ADR-0035).
      def published_exercises(ids)
        Orm::Exercise.joins(essential: { course: :material })
                     .where(id: ids, status: "published", essentials: { status: "published" }, courses: { status: "published" })
      end

      def exercise_rows(rows, assignments, student_id)
        ids = rows.map(&:first)
        completed = Orm::ExerciseSession.where(student_id:, exercise_id: ids, status: "completed").group(:exercise_id)
                                        .pluck(:exercise_id, Arel.sql("MAX(score_percent)"), Arel.sql("COUNT(*)"))
                                        .to_h { |id, best, count| [ id, [ best, count ] ] }
        started = Orm::ExerciseSession.where(student_id:, exercise_id: ids, status: "started").pluck(:exercise_id, :public_id).to_h
        badges = Orm::ExerciseBadge.where(student_id:, exercise_id: ids).pluck(:exercise_id, :level).to_h
        rows.map do |id, public_id, title, material_name, material_category, material_slug, *program_order|
          best_score_percent, completed_count = completed.fetch(id, [ nil, 0 ])
          assigned_at, due_on = assignments.fetch(id)
          row = ExerciseRow.new(public_id:, title:, material_name:, material_category:, badge_level: badges[id], best_score_percent:,
                                completed_count:, started_session_public_id: started[id], due_on:)
          [ urgency(row, assigned_at, *program_order), material_slug, row ]
        end
      end

      # UDR-0076 §3.1 : une matière par cours publié du niveau de l'élève, une seule fois, dans l'ordre de la charte.
      def subjects(student_id)
        Orm::Material.joins(:courses).merge(own_level(student_id)).where(courses: { status: "published" }).distinct
                     .pluck(:slug, :name).map { |slug, name| SubjectRow.new(slug:, name:) }
                     .sort_by { [ SUBJECT_ORDER.index(it.slug) || SUBJECT_ORDER.size, it.name ] }
      end

      # Une lacune dont la fiche n'est plus publiée n'a plus de page à ouvrir : elle n'est pas proposée.
      def pending_gaps(student_id)
        Orm::KnowledgeGap.joins(essential: :course)
                         .where(student_id:, status: "pending", essentials: { status: "published" }, courses: { status: "published" })
                         .merge(own_level(student_id))
                         .order(created_at: :desc, id: :desc).pluck("essentials.name", "essentials.slug", "courses.slug")
                         .map { |essential_name, essential_slug, course_slug| GapRow.new(essential_name:, essential_slug:, course_slug:) }
      end
    end
  end
end
