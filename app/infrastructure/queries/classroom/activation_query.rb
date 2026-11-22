# 🔌 INFRA · Queries::Classroom::ActivationQuery
# Rôle : le premier exercice de l'élève qui n'en a réussi aucun (copie à 10/20 arrondi) : la copie en cours, le devoir de l'élève amené par sa classe, sinon le programme
# ADR  : 0035, 0049 (aucun traceur : tout se lit dans les copies), 0062 · UDR : 0174 activation-premier-exercice §2 · chantier activation-eleve
module Queries
  module Classroom
    class ActivationQuery
      # Les champs de Queries::Catalog::NextExerciseQuery::Row (la carte « Prochain exercice » les lit), plus la matière et
      # assigned : vrai quand l'exercice est un devoir de la classe (« Donné par ta classe »). kind : :resume ou :start.
      Row = Data.define(:kind, :exercise_public_id, :title, :lesson_name, :material_name, :session_public_id, :resume_number, :assigned)

      # Les modes d'entrée de l'élève amené par sa classe : le lien ou le code donnés par l'enseignant ou l'établissement ;
      # « standard » est l'élève qui a choisi sa classe seul, dans la liste.
      BROUGHT_BY_CLASS = %w[link code].freeze
      RESUME_COLUMNS = [ :public_id, :answered_count, "exercises.public_id", "exercises.title", "courses.name", "materials.name" ].freeze

      # home : le StudentHomeQuery::Row de l'élève (sa classe, ses devoirs, ses matières dans l'ordre du programme).
      # → Row, ou nil (élève activé, ou rien à lui proposer).
      def call(student_id:, home:)
        return if activated?(student_id:)

        resume(student_id:) || assignment(student_id:, home:) || program(student_id:, home:)
      end

      # Le moment « aha » : une copie terminée atteint la moyenne, arrondie au point sur 20 comme partout (Grading).
      def activated?(student_id:)
        best = Orm::ExerciseSession.where(student_id:, status: "completed").maximum(:score_percent)
        !best.nil? && Entities::Assessment::Grading.reaches?(best, Entities::Assessment::Grading::PASS_THRESHOLD)
      end

      # Une copie rendue (terminée), quelle que soit la note : la fenêtre « Ton premier exercice » n'a plus lieu d'être.
      def submitted_copy?(student_id:)
        Orm::ExerciseSession.exists?(student_id:, status: "completed")
      end

      # La copie de la carte, que l'historique ne montre pas une seconde fois (une porte par action) ; nil si l'élève est
      # activé ou n'a pas de copie en cours.
      def resume_session_public_id(student_id:)
        resume(student_id:)&.session_public_id unless activated?(student_id:)
      end

      # La copie en cours la plus récente, d'un exercice publié de son niveau. → Row | nil
      def resume(student_id:)
        session_id, answered, public_id, title, lesson_name, material_name =
          Orm::ExerciseSession.joins(exercise: { course: :material })
                              .where(student_id:, status: "started", exercises: { status: "published", archived_at: nil },
                                     courses: { status: "published" })
                              .merge(own_level(student_id))
                              .order(started_at: :desc, id: :desc).pick(*RESUME_COLUMNS)
        return if session_id.nil?

        Row.new(kind: :resume, exercise_public_id: public_id, title:, lesson_name:, material_name:, session_public_id: session_id,
                resume_number: answered + 1, assigned: false)
      end

      private

      # L'élève amené par sa classe : le premier devoir non commencé, dans l'ordre de « À faire ».
      def assignment(student_id:, home:)
        return unless BROUGHT_BY_CLASS.include?(joined_via(student_id))

        exercise = home.assigned_exercises.find { it.completed_count.zero? && it.started_session_public_id.nil? }
        return if exercise.nil?

        Row.new(kind: :start, exercise_public_id: exercise.public_id, title: exercise.title, lesson_name: nil,
                material_name: exercise.material_name, session_public_id: nil, resume_number: nil, assigned: true)
      end

      # Le programme : la règle « Prochain exercice », matière par matière dans l'ordre de la grille ; la première qui en a un.
      def program(student_id:, home:)
        audience = Queries::Catalog::StudentAudienceQuery.new.call(student_id:)
        home.subjects.each do |subject|
          found = Queries::Catalog::NextExerciseQuery.new.call(student_id:, audience:, material: subject.slug)
          next if found.nil?

          return Row.new(**found.to_h, material_name: subject.name, assigned: false)
        end
        nil
      end

      def joined_via(student_id)
        Orm::ClassroomStudent.joins(:classroom).where(student_id:, primary: true, left_at: nil, classrooms: { status: "active" })
                             .pick(:joined_via)
      end

      def own_level(student_id)
        @own_level ||= Queries::Catalog::AudienceFilter.courses(Queries::Catalog::StudentAudienceQuery.new.call(student_id:))
      end
    end
  end
end
