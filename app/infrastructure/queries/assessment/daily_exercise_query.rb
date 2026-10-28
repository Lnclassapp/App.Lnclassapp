# 🔌 INFRA · Queries::Assessment::DailyExerciseQuery
# Rôle : exercice du jour d'un élève sans travail donné, calculé à la lecture (état, exercice, matière, matière de demain), en une requête
# ADR  : 0035, 0089 (§4.1), 0090 (§4.2 : rang des matières) · contrat gelé au Lot 0 du chantier accueil-eleve, implémenté au Lot C
module Queries
  module Assessment
    class DailyExerciseQuery
      # state : :proposed, :done_today ou :none (les autres champs sont alors nil) ; tomorrow_material_name : rempli
      # pour :done_today.
      Row = Data.define(:state, :exercise_public_id, :exercise_title, :material_name, :material_category,
                        :tomorrow_material_name)
      NONE = Row.new(state: :none, exercise_public_id: nil, exercise_title: nil, material_name: nil, material_category: nil,
                     tomorrow_material_name: nil)

      # first_done_at : le début de sa première session terminée, ou nil ; assigned : donné dans une de ses classes.
      Candidate = Data.define(:public_id, :title, :slug, :name, :category, :position, :first_done_at, :assigned, :done_today) do
        # ADR-0089 §4.1 étape 2 : candidat du jour qui commence à `day_start`.
        def open_on?(day_start) = !assigned && (first_done_at.nil? || first_done_at >= day_start)
      end

      # Ordre du catalogue (CourseCatalogQuery : niveau, puis nom du cours), puis de la fiche et de l'exercice.
      CATALOG_ORDER = %w[levels.position courses.name courses.id essentials.position exercises.position exercises.id].freeze

      # today : date d'Abidjan, passée par l'appelant ; jamais Date.today (fuseau du serveur).
      def call(student_id:, today: Time.zone.today)
        day_start = today.in_time_zone
        by_subject = candidates(student_id, today, day_start).group_by(&:slug)
        subjects = by_subject.keys.sort_by { |slug| subject_rank(by_subject[slug].first) }

        exercise = first_open(by_subject, subjects, today, day_start)
        return NONE if exercise.nil?
        return row(exercise, :proposed) unless exercise.done_today

        # §4.1 étape 6 : la même règle pour demain, où toute session terminée d'ici là (celle du jour comprise) est faite.
        tomorrow = first_open(by_subject, subjects, today + 1, day_start + 1.day)
        row(exercise, :done_today, tomorrow_material_name: tomorrow&.name)
      end

      private

      # §4.1 étapes 3 et 4 : la matière du tour, ou la suivante qui a un candidat ; son premier candidat.
      def first_open(by_subject, subjects, day, day_start)
        open = by_subject.transform_values { |list| list.find { it.open_on?(day_start) } }.compact
        slug = Entities::Assessment::DailyRotation.subject_for(day:, subjects:, with_candidates: open.keys)
        open[slug] if slug
      end

      def row(exercise, state, tomorrow_material_name: nil)
        Row.new(state:, exercise_public_id: exercise.public_id, exercise_title: exercise.title, material_name: exercise.name,
                material_category: exercise.category, tomorrow_material_name:)
      end

      # L'ordre de « Mes matières » (ADR-0090 §4.2) : materials.position, une matière sans rang après, puis le nom.
      def subject_rank(candidate) = [ candidate.position ? 0 : 1, candidate.position.to_i, candidate.name ]

      # Tous les exercices publiés (ADR-0035) du niveau de ses classes, avec ce qu'il faut pour aujourd'hui et demain : une
      # seule requête, quel que soit le nombre de matières. Les matières se lisent ici, même toutes faites : le tour n'en
      # dépend pas.
      def candidates(student_id, today, day_start)
        sessions = Orm::ExerciseSession.where(student_id:, status: "completed").where("exercise_sessions.exercise_id = exercises.id")
        first_done = sessions.select("MIN(exercise_sessions.started_at)")
        # Une remédiation (ADR-0043) n'est pas l'exercice du jour fait seul : elle ne déclenche pas « Bravo, à demain ! ».
        done_today = sessions.where(kind: "standard", classroom_assignment_id: nil, started_at: day_start...(day_start + 1.day))
        Orm::Exercise.joins(course: %i[material level]).left_joins(:essential)
                     .where(status: "published", courses: { status: "published" })
                     .where("essentials.id IS NULL OR essentials.status = 'published'")
                     .where(exists(audience(student_id, today))).order(*CATALOG_ORDER)
                     .pluck("exercises.public_id", "exercises.title", "materials.slug", "materials.name", "materials.category",
                            "materials.position", Arel.sql("(#{first_done.to_sql})"), exists(assigned(student_id)), exists(done_today))
                     .map { Candidate.new(*it) }
      end

      # Une sous-requête corrélée, ses valeurs déjà liées par to_sql.
      def exists(relation) = Arel.sql("EXISTS (#{relation.select(1).to_sql})")

      def own_classrooms(student_id)
        Orm::ClassroomStudent.joins(:classroom).where(student_id:, left_at: nil, classrooms: { status: "active" })
      end

      # La règle d'AudienceFilter (StudentAudienceQuery), corrélée au cours : une classe de l'année de son niveau, et la série
      # du cours vide ou celle de la classe.
      def audience(student_id, today)
        own_classrooms(student_id).where(classrooms: { school_year: Entities::Classroom::SchoolYear.current(today) })
                                  .where("classrooms.level_id = courses.level_id")
                                  .where("courses.series_id IS NULL OR courses.series_id = classrooms.series_id")
      end

      # §4.1 étape 2 : un exercice donné dans une de ses classes est le travail de l'enseignant, jamais l'exercice du jour.
      def assigned(student_id)
        Orm::ClassroomAssignment.where(assignable_type: "Exercise", status: "active", classroom_id: own_classrooms(student_id).select(:classroom_id))
                                .where("classroom_assignments.assignable_id = exercises.id")
      end
    end
  end
end
