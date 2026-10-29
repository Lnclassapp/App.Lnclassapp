# 🔌 INFRA · Queries::Assessment::SessionResultQuery
# Rôle : résultat d'une session terminée (score, note, appréciation, points, maîtrise, badge, progrès, effet sur la fiche) et sa correction ; sans reveal, seuls les choix
# ADR  : 0028, 0033, 0043, 0054, 0079, 0091, 0094, 0101, 0112, 0113, 0115 · UDR : 0007, 0023, 0073, 0087, 0120, 0138 §3.4, 0140 · sécurité n° 29
module Queries
  module Assessment
    class SessionResultQuery
      # badge_level : palier du score de cette session (Grading), nil sous le seuil ; earned_now : le badge de l'élève
      # sur l'exercice vient de cette session. progress : Progress, nil à la première session, remédiation comprise (UDR-0073).
      # gap_outcome : GapOutcome de cette session sur sa fiche (:opened, :lifted, :still_pending) ou nil (UDR-0120).
      # essential : nil pour un exercice de toute la leçon ; course_slug : le cours, toujours là (le retour à la leçon).
      Row = Data.define(:session_public_id, :student_id, :student_name, :exercise, :essential, :course_slug, :score_percent, :grade_on_20,
                        :correct_count, :question_count, :mastery, :badge_level, :earned_now, :progress, :review, :gap_outcome,
                        :appreciation, :points)
      # Les points du résultat (ADR-0115) : earned et graded, des seules questions corrigées automatiquement ; manual, des
      # réponses rédigées et du cahier, à comparer au corrigé ; weighted : au moins une question n'est pas à 1 point.
      Points = Data.define(:earned, :graded, :manual, :weighted)
      # trend : Comprehension.trend_for ; les trois notes sur 20, du premier, du meilleur et du dernier score (cette session).
      Progress = Data.define(:trend, :first_grade, :best_grade, :current_grade)
      # statement_blocks : le sujet en blocs de l'exercice (ADR-0115), nil sans blocs.
      ExerciseRow = Data.define(:public_id, :title, :statement_blocks)
      GapFacts = Data.define(:id, :status, :source_session_id, :resolved_by_session_id)
      EssentialRow = Data.define(:slug, :name, :course_slug)
      # correct : verdict de la tentative (nil sans tentative) ; unanswered : la question est restée vide à la copie (UDR-0138 §3.4,
      # « Sans réponse », jamais « Faux »). « Ton choix » par type (ADR-0091 §4.4) : answers (propositions
      # d'un choix, étapes d'un ordre dans l'ordre de l'élève), response_text (trous, nombre), pairs (relier). solution et
      # numeric_tolerance ne sont remplis qu'avec reveal, pour les quatre nouveaux types.
      # ADR-0115 : points, unit (réponse chiffrée), criteria (grille d'une réponse rédigée, avec reveal seulement). Pour une
      # réponse rédigée ou du cahier, explanation est le corrigé type : sans reveal, la query ne le rend pas.
      ReviewQuestion = Data.define(:id, :number, :content, :explanation, :correct, :answers, :question_type, :response_text,
                                   :pairs, :solution, :numeric_tolerance, :unanswered, :points, :unit, :criteria) do
        def initialize(question_type: "single_choice", response_text: nil, pairs: [], solution: [], numeric_tolerance: nil,
                       unanswered: false, points: BigDecimal("1"), unit: nil, criteria: [], **) = super
        def kind_name = Entities::Assessment::Question.kind_name_for(question_type)
        def auto_graded? = Entities::Assessment::Question.kind_for(question_type)&.then { it::AUTO_GRADED } || false
      end
      # Sans reveal, correct vaut nil : la colonne n'est pas lue, et seules les propositions cochées le sont.
      ReviewAnswer = Data.define(:id, :content, :selected, :correct)
      # Types dont les éléments sont lus même sans reveal : la réponse de l'élève est faite de ces éléments.
      ELEMENT_KINDS = %w[ordering matching].freeze
      # Types dont la réponse est une proposition cochée ou choisie, et types sans élément ni proposition.
      CHOICE_KINDS = %w[choice select].freeze
      WRITTEN_KINDS = %w[written notebook].freeze
      Pair = Data.define(:left, :right)

      SESSION_COLUMNS = %w[exercise_sessions.id exercise_sessions.public_id exercise_sessions.student_id users.first_name
                           users.last_name exercise_sessions.score_percent exercise_sessions.correct_count
                           exercise_sessions.question_count exercises.id exercises.public_id exercises.title exercises.statement_blocks essentials.slug
                           essentials.name courses.slug exercise_sessions.completed_at exercise_sessions.kind
                           exercise_sessions.knowledge_gap_id].freeze

      # reveal : décidé en amont par RevealCorrectionPolicy. → Row | nil
      def call(public_id:, reveal:)
        id, public_id, student_id, first_name, last_name, score_percent, correct_count, question_count, exercise_id,
          exercise_public_id, title, statement_blocks, essential_slug, essential_name, course_slug, completed_at, kind, knowledge_gap_id =
          Orm::ExerciseSession.joins(:student, exercise: :course)
                              .joins("LEFT OUTER JOIN essentials ON essentials.id = exercises.essential_id")
                              .where(public_id:).pick(*SESSION_COLUMNS)
        return if id.nil?

        review = review(id, exercise_id, reveal)
        Row.new(session_public_id: public_id, student_id:, student_name: "#{first_name} #{last_name}",
                exercise: ExerciseRow.new(public_id: exercise_public_id, title:, statement_blocks:),
                essential: (EssentialRow.new(slug: essential_slug, name: essential_name, course_slug:) if essential_slug), course_slug:,
                correct_count:, question_count:, **grading(score_percent),
                earned_now: Orm::ExerciseBadge.exists?(exercise_session_id: id),
                progress: progress(id, student_id, exercise_id, completed_at), review:,
                gap_outcome: gap_outcome(id, kind, knowledge_gap_id),
                appreciation: appreciation(score_percent, review, essential_name), points: points(review))
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

      # ADR-0115 : « à revoir » = question corrigée automatiquement, fausse ou sans réponse. Elle se lit sur la note affichée.
      def appreciation(score_percent, review, essential_name)
        outcomes = review.map { [ it.number, it.auto_graded?, it.correct == true ] }
        Entities::Assessment::Appreciation.for(score_percent:, outcomes:, essential_name:)
      end

      def points(review)
        graded, manual = review.partition(&:auto_graded?)
        Points.new(earned: graded.select { it.correct == true }.sum(&:points), graded: graded.sum(&:points), manual: manual.sum(&:points),
                   weighted: review.any? { it.points != 1 })
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

      # Une requête : la lacune que la session a ouverte, sinon levée, sinon ciblée (ADR-0101 §6). Le résultat suit
      # resolved_by_session_id, pas knowledge_gap_id : deux onglets peuvent lever une autre lacune que celle ciblée.
      def gap_outcome(session_id, kind, knowledge_gap_id)
        gaps = Orm::KnowledgeGap.where(source_session_id: session_id).or(Orm::KnowledgeGap.where(resolved_by_session_id: session_id))
                                .or(Orm::KnowledgeGap.where(id: knowledge_gap_id))
                                .pluck(:id, :status, :source_session_id, :resolved_by_session_id).map { GapFacts.new(*it) }
        gap = gaps.find { it.source_session_id == session_id } || gaps.find { it.resolved_by_session_id == session_id } || gaps.first
        Entities::Assessment::GapOutcome.call(session_id:, session_kind: kind, knowledge_gap_id:, gap:)
      end

      def review(session_id, exercise_id, reveal)
        questions = Orm::Question.where(exercise_id:).order(:position, :id)
                                 .pluck(:id, :content, :explanation, :question_type, :points, :unit, :criteria,
                                        *(reveal ? [ :numeric_tolerance ] : []))
        attempts = Orm::QuestionAttempt.where(exercise_session_id: session_id)
                                       .pluck(:question_id, :correct, :selected_answer_ids, :response_text, :unanswered)
                                       .to_h { |question_id, correct, selected, text, unanswered| [ question_id, [ correct, selected, text, unanswered ] ] }
        kinds = questions.to_h { |id, _, _, question_type| [ id, kind_name(question_type) ] }
        choice_ids = kinds.select { |_, kind| CHOICE_KINDS.include?(kind) }.keys
        answers = reveal ? all_answers(choice_ids, attempts) : selected_answers(attempts.slice(*choice_ids))
        elements = elements(kinds.reject { |_, kind| CHOICE_KINDS.include?(kind) || WRITTEN_KINDS.include?(kind) || !(reveal || ELEMENT_KINDS.include?(kind)) }.keys)
        questions.each_with_index.map do |(id, content, explanation, question_type, points, unit, criteria, tolerance), index|
          correct, selected, response_text, unanswered = attempts.fetch(id, [ nil, [], nil, false ])
          # Le corrigé type d'une réponse rédigée ou du cahier ne se rend qu'avec reveal ; la grille aussi.
          written = WRITTEN_KINDS.include?(kind_name(question_type))
          ReviewQuestion.new(id:, number: index + 1, content:, explanation: (explanation if reveal || !written), correct:, question_type:,
                             response_text:, unanswered:, points:, unit:, criteria: (reveal ? criteria : []),
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
        when "choice", "select", "written", "notebook" then {}
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
