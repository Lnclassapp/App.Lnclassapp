# Exercises, sessions, attempts, badges and knowledge gaps (ADR-0033, ADR-0043, ADR-0054).
module Factories
  module Assessment
    ActiveSupport::TestCase.include(self)

    # Each question is a single choice among 4 answers; the first one is the correct one.
    def create_exercise(essential: create_essential, title: "Exercice #{factory_sequence}", position: nil, status: "published",
                        questions: 2, author: essential.author, **attributes)
      position ||= essential.exercises.maximum(:position).to_i + 1
      Orm::Exercise.create!(essential:, title:, position:, author:, **factory_publication(status), **attributes).tap do |exercise|
        questions.times do |index|
          question = exercise.questions.create!(position: index + 1, content: "<p>Question #{index + 1}</p>",
                                                question_type: "single_choice")
          4.times { |rank| question.answers.create!(position: rank + 1, content: "Proposition #{rank + 1}", correct: rank.zero?) }
        end
      end
    end

    # A completed session carries its score; a gap makes it a remediation session (ADR-0043).
    # Not create_session: ActionDispatch::Integration::Runner#create_session would hide it in controller and system tests.
    def create_exercise_session(student: create_student, exercise: create_exercise, status: "started", score_percent: nil, gap: nil,
                                **attributes)
      count = exercise.questions.count
      completed = status == "completed"
      score_percent ||= 100 if completed
      Orm::ExerciseSession.create!(student:, exercise:, status:, question_count: count, started_at: Time.current,
                                   kind: gap ? "remediation" : "standard", knowledge_gap: gap,
                                   answered_count: completed ? count : 0, progress_percent: completed ? 100 : 0,
                                   correct_count: completed ? (count * score_percent / 100.0).round : 0,
                                   score_percent:, completed_at: (Time.current if completed), **attributes)
    end

    def create_attempt(session: create_exercise_session, question: session.exercise.questions.first, correct: true)
      answers = question.answers.to_a
      selected = correct ? answers.select(&:correct) : [ answers.reject(&:correct).first ]
      Orm::QuestionAttempt.create!(exercise_session: session, question:, correct:, selected_answer_ids: selected.map(&:id),
                                   answered_at: Time.current)
    end

    def create_badge(student: create_student, exercise: create_exercise, level: "gold",
                     session: create_exercise_session(student:, exercise:, status: "completed"))
      Orm::ExerciseBadge.create!(student:, exercise:, exercise_session: session, level:, awarded_at: Time.current)
    end

    def create_gap(student: create_student, essential: create_essential, status: "pending",
                   source_session: create_exercise_session(student:, exercise: create_exercise(essential:), status: "completed",
                                                  score_percent: 40), **attributes)
      Orm::KnowledgeGap.create!(student:, essential:, source_session:, status:,
                                resolved_at: (Time.current unless status == "pending"), **attributes)
    end
  end
end
