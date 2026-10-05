# 🔌 INFRA · Queries::Assessment::SessionResultQuery
# Rôle : résultat d'une session terminée (score, note, maîtrise, badge, progrès) et sa correction ; sans reveal, seuls les choix
# ADR  : 0028, 0033, 0043, 0054, 0079 · UDR : 0007, 0023, 0073 · sécurité n° 29
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
      # correct : verdict de la tentative (nil sans tentative).
      ReviewQuestion = Data.define(:id, :number, :content, :explanation, :correct, :answers)
      # Sans reveal, correct vaut nil : la colonne n'est pas lue, et seules les propositions cochées le sont.
      ReviewAnswer = Data.define(:id, :content, :selected, :correct)

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

      # Fait teaches_student de ReadSessionPolicy : l'élève est encore inscrit dans une classe active de l'enseignant.
      def teaches_student?(student_id:, teacher_id:)
        Orm::ClassroomStudent.joins(:classroom)
                             .where(student_id:, left_at: nil, classrooms: { status: "active" })
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
        questions = Orm::Question.where(exercise_id:).order(:position, :id).pluck(:id, :content, :explanation)
        attempts = Orm::QuestionAttempt.where(exercise_session_id: session_id).pluck(:question_id, :correct, :selected_answer_ids)
                                       .to_h { |question_id, correct, selected| [ question_id, [ correct, selected ] ] }
        answers = reveal ? all_answers(questions.map(&:first), attempts) : selected_answers(attempts)
        questions.each_with_index.map do |(id, content, explanation), index|
          ReviewQuestion.new(id:, number: index + 1, content:, explanation:, correct: attempts.fetch(id, [ nil ]).first,
                             answers: answers.fetch(id, []))
        end
      end

      # Filtrées par la base : une proposition juste que l'élève n'a pas cochée n'est jamais lue (UDR-0022, UDR-0023).
      def selected_answers(attempts)
        ids = attempts.values.flat_map(&:last)
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
                       ReviewAnswer.new(id:, content:, correct:, selected: attempts.fetch(question_id, [ nil, [] ]).last.include?(id))
                     end
                   end
      end
    end
  end
end
