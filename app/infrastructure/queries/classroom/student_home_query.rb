# 🔌 INFRA · Queries::Classroom::StudentHomeQuery
# Rôle : accueil élève (CL-23, TR-04, AS-36) : classe, matières, exercices assignés triés par échéance, lacunes, l'état de la carte du prochain exercice ; l'historique, à part (cadre différé) ; sans classe, la dernière et un retrait récent
# ADR  : 0026, 0033, 0035, 0043, 0048, 0072, 0085, 0089, 0090 · UDR : 0010, 0062 (§3.2 ordre, §3.3 `late_material_slugs`), 0076 (§3.1, §3.2), 0081 (§3.5), 0084 (§3.8), XXXX accueil élève (§3.3 : les états de la carte)
module Queries
  module Classroom
    class StudentHomeQuery
      # late_material_slugs : les matières où un exercice est en retard pour l'élève, pastille de « Mes matières » (UDR-0062
      # §3.3, UDR-0076 §3.1) ; subjects : les matières qui ont un cours publié de son niveau. L'activité récente n'y est plus :
      # seul le cadre différé la lit, par recent_sessions (chantier accueil-eleve, PRD §7).
      # school_sigle : le sigle de l'établissement pour l'en-tête de la carte, nil s'il n'en a pas ; next_step : NextStep.
      Row = Data.define(:school_name, :school_sigle, :level_name, :classroom_name, :classmates_count,
                        :assigned_exercises, :pending_gaps, :late_material_slugs, :subjects, :next_step)
      # UDR accueil élève §3.3, la carte de l'accueil. state : :late, :due, :review, :all_done ou :unassigned (« sans classe » est
      # l'absence de Row) ; exercise : l'ExerciseRow à faire (:late, :due) ; other_late_count : les autres en retard ; review : la fiche
      # à revoir (:review) ; done_count et total_count : l'assigné fait, sur l'assigné ; assigner : qui l'a donné (:late, :due).
      NextStep = Data.define(:state, :exercise, :other_late_count, :review, :done_count, :total_count, :assigner)
      # La civilité vient du genre (communication.signature) ; un enseignant anonymisé ne signe plus (ADR-0036).
      Assigner = Data.define(:gender, :last_name)
      ReviewRow = Data.define(:essential_name, :essential_slug, :course_slug, :material_name, :material_slug, :score_percent)
      # badge_level : bronze, silver, gold, diamond ou nil ; started_session_public_id : la session à reprendre, ou nil ;
      # due_on : l'échéance de l'assignation (ADR-0072), nil sans jours de séance ; material_slug : la pastille illustrée.
      ExerciseRow = Data.define(:public_id, :title, :material_name, :material_category, :material_slug, :badge_level,
                                :best_score_percent, :completed_count, :started_session_public_id, :due_on)
      SessionRow = Data.define(:public_id, :exercise_public_id, :exercise_title, :material_name, :material_slug, :score_percent,
                               :completed_at)
      GapRow = Data.define(:essential_name, :essential_slug, :course_slug)
      SubjectRow = Data.define(:slug, :name)
      # L'élève sans classe active (UDR-0081 §3.5) : la DRENA et l'établissement de sa dernière classe principale, qui
      # préremplissent « Choisis ta classe » ; recent_removal_at : l'heure du retrait qui l'en a fait sortir, s'il est récent.
      LastClassroom = Data.define(:drena_public_id, :school_public_id, :recent_removal_at)

      RECENT_SESSIONS = 10
      # Un retrait est récent pendant 7 jours, la durée de la marque « Nouveau » (ADR-0085 §4.4) : un calcul de lecture,
      # sans colonne. Au-delà, l'accueil propose de choisir une classe sans revenir sur le départ.
      RECENT_REMOVAL = 7.days
      # La dernière adhésion principale : celle encore ouverte (classe archivée) d'abord, puis la plus récemment quittée.
      LAST_FIRST = Arel.sql("classroom_students.left_at DESC NULLS FIRST, classroom_students.joined_at DESC, classroom_students.id DESC")
      # L'ordre du programme (ADR-0090 §4.2) : le rang de la matière, puis son nom ; une matière sans rang suit, par nom.
      PROGRAM_ORDER = [ Arel.sql("materials.position ASC NULLS LAST"), "materials.name" ].freeze
      HEADER_COLUMNS = [ "classrooms.id", "schools.name", "schools.sigle", "levels.name", "classrooms.name" ].freeze
      EXERCISE_COLUMNS = [ "exercises.id", "exercises.public_id", "exercises.title", "materials.name", "materials.category",
                           "materials.slug", "courses.id", "essentials.position", "exercises.position" ].freeze

      # today : la date d'Abidjan (Time.zone), qui dit si une échéance est passée.
      # → Row | nil (aucune classe principale active : l'élève n'a pas d'accueil)
      def call(student_id:, today: Time.zone.today)
        classroom_id, school_name, school_sigle, level_name, classroom_name =
          Orm::ClassroomStudent.joins(classroom: %i[school level])
                               .where(student_id:, primary: true, left_at: nil, classrooms: { status: "active" })
                               .pick(*HEADER_COLUMNS)
        return if classroom_id.nil?

        exercises = assigned_with_slugs(classroom_id, student_id)
        Row.new(school_name:, school_sigle: school_sigle.presence, level_name:, classroom_name:,
                classmates_count: Orm::ClassroomStudent.where(classroom_id:, left_at: nil).count,
                assigned_exercises: exercises.map(&:last), pending_gaps: pending_gaps(student_id:),
                late_material_slugs: late_material_slugs(exercises, today), subjects: subjects(student_id),
                next_step: next_step(exercises.map(&:last), classroom_id, student_id, today))
      end

      # Les exercices assignés à la classe, dans l'ordre de « À faire » ; lue aussi par « Ma classe » (UDR-0076 §3.2).
      # → [ExerciseRow]
      def assigned_exercises(classroom_id:, student_id:) = assigned_with_slugs(classroom_id, student_id).map(&:last)

      # Une lacune dont la fiche n'est plus publiée n'a plus de page à ouvrir : elle n'est pas proposée.
      def pending_gaps(student_id:)
        Orm::KnowledgeGap.joins(essential: :course)
                         .where(student_id:, status: "pending", essentials: { status: "published" }, courses: { status: "published" })
                         .merge(own_level(student_id))
                         .order(created_at: :desc, id: :desc).pluck("essentials.name", "essentials.slug", "courses.slug")
                         .map { |essential_name, essential_slug, course_slug| GapRow.new(essential_name:, essential_slug:, course_slug:) }
      end

      # → LastClassroom ; tout à nil pour un élève qui n'a jamais eu de classe.
      def last_classroom(student_id:, now: Time.current)
        drena_public_id, school_public_id, removed_at =
          Orm::ClassroomStudent.joins(classroom: { school: :drena }).where(student_id:, primary: true).order(LAST_FIRST)
                               .pick("drenas.public_id", "schools.public_id", :removed_at)
        LastClassroom.new(drena_public_id:, school_public_id:,
                          recent_removal_at: (removed_at if removed_at && removed_at >= now - RECENT_REMOVAL))
      end

      # Lue seule par le frame différé de l'activité récente. → [SessionRow]
      def recent_sessions(student_id:)
        Orm::ExerciseSession.joins(exercise: { course: :material }).where(student_id:, status: "completed")
                            .merge(own_level(student_id))
                            .order(completed_at: :desc, id: :desc).limit(RECENT_SESSIONS)
                            .pluck(:public_id, "exercises.public_id", "exercises.title", "materials.name", "materials.slug", :score_percent,
                                   :completed_at)
                            .map { |values| SessionRow.new(*values) }
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

      # UDR accueil élève §3.3, premier état vrai : en retard, puis à faire, puis (rien d'ouvert) une fiche à revoir, puis les
      # exercices assignés sont tous faits, sinon rien n'est assigné. `exercises` suit l'ordre de « À faire » : les non terminés
      # d'abord, par échéance croissante, donc le premier en retard est le plus ancien et le premier ouvert le plus proche.
      def next_step(exercises, classroom_id, student_id, today)
        open = exercises.select { it.completed_count.zero? }
        late = open.select { it.due_on && it.due_on < today }
        counts = { done_count: exercises.size - open.size, total_count: exercises.size }
        step = ->(state, exercise: nil, review: nil, other_late_count: 0) do
          NextStep.new(state:, exercise:, other_late_count:, review:, assigner: (assigner(classroom_id, exercise) if exercise), **counts)
        end
        return step.(:late, exercise: late.first, other_late_count: late.size - 1) if late.any?
        return step.(:due, exercise: open.first) if open.any?

        review = oldest_review(student_id)
        return step.(:review, review:) if review

        step.(exercises.empty? ? :unassigned : :all_done)
      end

      # Qui a donné l'exercice à la classe, pour « Maths · M. Kouassi » ; nil si l'enseignant est anonymisé.
      def assigner(classroom_id, exercise)
        gender, last_name, anonymized_at =
          Orm::ClassroomAssignment.joins(:assigned_by)
                                  .where(classroom_id:, status: "active", assignable_type: "Exercise",
                                         assignable_id: Orm::Exercise.where(public_id: exercise.public_id).select(:id))
                                  .pick("users.gender", "users.last_name", "users.anonymized_at")
        Assigner.new(gender:, last_name:) if last_name && anonymized_at.nil?
      end

      # La fiche à revoir depuis le plus longtemps, avec la note de la session qui l'a ouverte (UDR-0119).
      def oldest_review(student_id)
        row = Orm::KnowledgeGap.joins(:source_session, essential: { course: :material })
                               .where(student_id:, status: "pending", essentials: { status: "published" }, courses: { status: "published" })
                               .merge(own_level(student_id))
                               .order(:created_at, :id)
                               .pick("essentials.name", "essentials.slug", "courses.slug", "materials.name", "materials.slug",
                                     "exercise_sessions.score_percent")
        ReviewRow.new(*row) if row
      end

      # ADR-0072 §4.4 : en retard pour l'élève = non terminé, et l'échéance est passée ; sans échéance, jamais.
      def late_material_slugs(exercises, today)
        exercises.filter_map { |slug, row| slug if row.completed_count.zero? && row.due_on && row.due_on < today }.uniq
      end

      # Un exercice publié dont la fiche et le cours le sont aussi (ADR-0035).
      def published_exercises(ids)
        Orm::Exercise.joins(course: :material).left_joins(:essential)
                     .where(id: ids, status: "published", courses: { status: "published" })
                     .where("essentials.id IS NULL OR essentials.status = 'published'")
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
          row = ExerciseRow.new(public_id:, title:, material_name:, material_category:, material_slug:, badge_level: badges[id],
                                best_score_percent:, completed_count:, started_session_public_id: started[id], due_on:)
          [ urgency(row, assigned_at, *program_order), material_slug, row ]
        end
      end

      # UDR-0076 §3.1 : une matière par cours publié du niveau de l'élève, une seule fois, dans l'ordre du programme
      # (materials.position, ADR-0090 §4.2). DISTINCT impose de lire les colonnes du tri.
      def subjects(student_id)
        Orm::Material.joins(:courses).merge(own_level(student_id)).where(courses: { status: "published" }).distinct
                     .order(*PROGRAM_ORDER).pluck(:slug, :name, :position)
                     .map { |slug, name, _position| SubjectRow.new(slug:, name:) }
      end
    end
  end
end
