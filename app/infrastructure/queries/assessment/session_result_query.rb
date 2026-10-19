# 🔌 INFRA · Queries::Assessment::SessionResultQuery
# Rôle : résultat d'une session terminée (score, note, maîtrise, badge, progrès) et sa correction ; sans reveal, seuls les choix
# ADR  : 0028, 0033, 0043, 0054, 0079, 0091, 0094 · UDR : 0007, 0023, 0073, 0087 · sécurité n° 29
module Queries
  module Assessment
    class SessionResultQuery
      # badge_level : palier du score de cette session (Grading), nil sous le seuil ; earned_now : le badge de l'élève
      # sur l'exercice vient de cette session. progress : Progress, nil à la première session, remédiation comprise (UDR-0073).
      Row = Data.define(:session_public_id, :student_id, :student_name, :exercise, :essential, :score_percent, :grade_on_20,
                        :correct_count, :question_count, :mastery, :badge_level, :earned_now, :progress, :review)
      # trend : Comprehension.trend_for ; les trois notes sur 20, du premier, du meilleur et du dernier score (cette session).
      Progress = Data.define(:trend, :first_grade, :best_grade, :current_grade)
      ExerciseRow = Data.define(:public_id, :title)
      EssentialRow = Data.define(:slug, :name, :course_slug)
      # correct : verdict de la tentative (nil sans tentative). « Ton choix » par type (ADR-0091 §4.4) : answers (propositions
      # d'un choix, étapes d'un ordre dans l'ordre de l'élève), response_text (trous, nombre), pairs (relier). solution et
      # numeric_tolerance ne sont remplis qu'avec reveal, pour les quatre nouveaux types.
      ReviewQuestion = Data.define(:id, :number, :content, :explanation, :correct, :answers, :question_type, :response_text,
                                   :pairs, :solution, :numeric_tolerance) do
        def initialize(question_type: "single_choice", response_text: nil, pairs: [], solution: [], numeric_tolerance: nil, **) = super
        def kind_name = Entities::Assessment::Question.kind_name_for(question_type)
      end
      # Sans reveal, correct vaut nil : la colonne n'est pas lue, et seules les propositions cochées le sont.
      ReviewAnswer = Data.define(:id, :content, :selected, :correct)
      # Types dont les éléments sont lus même sans reveal : la réponse de l'élève est faite de ces éléments.
      ELEMENT_KINDS = %w[ordering matching].freeze
      Pair = Data.define(:left, :right)

      SESSION_COLUMNS = %w[exercise_sessions.id exercise_sessions.public_id exercise_sessions.student_id users.first_name
                           users.last_name exercise_sessions.score_percent exercise_sessions.correct_count
                           exercise_sessions.question_count exercises.id exercises.public_id exercises.title essentials.slug
                           essentials.name courses.slug exercise_sessions.completed_at].freeze

      # reveal : décidé en amont par RevealAnswersPolicy. → Row | nil
      def call(public_id:, reveal:)
        id, public_id, student_id, first_name, last_name, score_percent, correct_count, question_count, exercise_id,
          exercise_public_id, title, essential_slug, essential_name, course_slug, completed_at =
          Orm::ExerciseSession.joins(:student, exercise: { essential: :course }).where(public_id:).pick(*SESSION_COLUMNS)
        return if id.nil?

        Row.new(session_public_id: public_id, student_id:, student_name: "#{first_name} #{last_name}",
                exercise: ExerciseRow.new(public_id: exercise_public_id, title:),
                essential: EssentialRow.new(slug: essential_slug, name: essential_name, course_slug:),
                correct_count:, question_count:, **grading(score_percent),
                earned_now: Orm::ExerciseBadge.exists?(exercise_session_id: id),
                progress: progress(id, student_id, exercise_id, completed_at), review: review(id, exercise_id, reveal))
      end

      # Fait teaches_student de ReadSessionPolicy : l'élève est encore inscrit dans une classe active de l'enseignant, de
      # son établissement courant (ADR-0094 §10 : un élève d'un autre de ses établissements n'existe pas, même par l'adresse).
      def teaches_student?(student_id:, teacher_id:, school_id:)
        Orm::ClassroomStudent.joins(:classroom)
                             .where(student_id:, left_at: nil, classrooms: { status: "active", school_id: })
                             .where(classroom_id: Orm::TeacherClassroom.where(teacher_id:).select(:classroom_id))
                             .exists?
      end

      private

      def grading(score_percent)
        grading = Entities::Assessment::Grading
        { score_percent:, grade_on_20: grading.grade_on_20(score_percent), mastery: grading.mastery_for(score_percent),
          badge_level: grading.badge_for(score_percent) }
      end

      # Historique de l'élève sur l'exercice, toutes classes et assignations confondues : ses sessions terminées, standard
      # et remédiation, jusqu'à celle-ci incluse, dans l'ordre (completed_at, id). Une seule requête. Une remédiation fait
      # l'exercice : sous 50 %, la session suivante de la fiche en est une (ADR-0043), et c'est le progrès à montrer.
      def progress(session_id, student_id, exercise_id, completed_at)
        scores = Orm::ExerciseSession.where(student_id:, exercise_id:, status: "completed")
                                     .where("(exercise_sessions.completed_at, exercise_sessions.id) <= (?, ?)", completed_at, session_id)
                                     .order(:completed_at, :id).pluck(:score_percent)
        return if scores.size < 2

        grade = Entities::Assessment::Grading.method(:grade_on_20)
        Progress.new(trend: Entities::Assessment::Comprehension.trend_for(scores), first_grade: grade.(scores.first),
                     best_grade: grade.(scores.max), current_grade: grade.(scores.last))
      end

      def review(session_id, exercise_id, reveal)
        questions = Orm::Question.where(exercise_id:).order(:position, :id)
                                 .pluck(:id, :content, :explanation, :question_type, *(reveal ? [ :numeric_tolerance ] : []))
        attempts = Orm::QuestionAttempt.where(exercise_session_id: session_id).pluck(:question_id, :correct, :selected_answer_ids, :response_text)
                                       .to_h { |question_id, correct, selected, text| [ question_id, [ correct, selected, text ] ] }
        kinds = questions.to_h { |id, _, _, question_type| [ id, kind_name(question_type) ] }
        choice_ids = kinds.select { |_, kind| kind == "choice" }.keys
        answers = reveal ? all_answers(choice_ids, attempts) : selected_answers(attempts.slice(*choice_ids))
        elements = elements(kinds.reject { |_, kind| kind == "choice" || !(reveal || ELEMENT_KINDS.include?(kind)) }.keys)
        questions.each_with_index.map do |(id, content, explanation, question_type, tolerance), index|
          correct, selected, response_text = attempts.fetch(id, [ nil, [], nil ])
          ReviewQuestion.new(id:, number: index + 1, content:, explanation:, correct:, question_type:, response_text:,
                             answers: answers.fetch(id, []),
                             **kind_review(kind_name(question_type), elements.fetch(id, []), selected, reveal, tolerance))
        end
      end

      def kind_name(question_type) = Entities::Assessment::Question.kind_name_for(question_type)

      # Les éléments des nouveaux types, une requête : l'ordre et relier pour rendre la réponse de l'élève ; les trous et
      # le nombre seulement avec reveal, puisque l'élève a sa réponse dans response_text. { question_id => [[id, content, match]] }
      def elements(question_ids)
        return {} if question_ids.empty?

        Orm::Answer.where(question_id: question_ids).order(:question_id, :position, :id)
                   .pluck(:question_id, :id, :content, :match_content)
                   .group_by(&:first).transform_values { |rows| rows.map { it.drop(1) } }
      end

      # « Ton choix » de l'élève, et la solution pour qui a reveal (ADR-0091 §4.4).
      def kind_review(kind, rows, selected, reveal, tolerance)
        contents = rows.to_h { |id, content, _| [ id, content ] }
        case kind
        when "ordering"
          { answers: selected.map { ReviewAnswer.new(id: nil, content: contents[it], selected: true, correct: nil) },
            solution: reveal ? rows.map { it[1] } : [] }
        when "matching"
          rights = rows.to_h { |id, _, right| [ id, right ] }
          { pairs: selected.empty? ? [] : rows.zip(selected).map { |(_, left, _), id| Pair.new(left:, right: rights[id]) },
            solution: reveal ? rows.map { |_, left, right| "#{left} → #{right}" } : [] }
        when "choice" then {}
        else { solution: rows.map { it[1] }, numeric_tolerance: tolerance }
        end
      end

      # Filtrées par la base : une proposition juste que l'élève n'a pas cochée n'est jamais lue (UDR-0022, UDR-0023).
      def selected_answers(attempts)
        ids = attempts.values.flat_map { it[1] }
        Orm::Answer.where(question_id: attempts.keys, id: ids).order(:question_id, :position, :id)
                   .pluck(:question_id, :id, :content)
                   .group_by(&:first)
                   .transform_values { |rows| rows.map { |_, id, content| ReviewAnswer.new(id:, content:, selected: true, correct: nil) } }
      end

      # { question_id => [ReviewAnswer] }, une requête pour toutes les questions.
      def all_answers(question_ids, attempts)
        Orm::Answer.where(question_id: question_ids).order(:question_id, :position, :id)
                   .pluck(:question_id, :id, :content, :correct)
                   .group_by(&:first)
                   .transform_values do |rows|
                     rows.map do |question_id, id, content, correct|
                       ReviewAnswer.new(id:, content:, correct:, selected: attempts.fetch(question_id, [ nil, [] ])[1].include?(id))
                     end
                   end
      end
    end
  end
end
