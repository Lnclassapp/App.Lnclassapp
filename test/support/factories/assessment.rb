# Exercises, sessions, attempts, badges and knowledge gaps (ADR-0033, ADR-0043, ADR-0054).
module Factories
  module Assessment
    ActiveSupport::TestCase.include(self)

    # Each question is a single choice among 4 answers; the first one is the correct one.
    # The exercise belongs to a course: that of its essential, or the given one for a lesson-wide exercise (no essential).
    def create_exercise(essential: nil, course: nil, lesson_wide: false, title: "Exercice #{factory_sequence}", position: nil,
                        status: "published", questions: 2, author: nil, **attributes)
      essential = nil if lesson_wide
      essential ||= create_essential(course: course || create_course) unless lesson_wide
      course = essential&.course || course || create_course
      position ||= Orm::Exercise.where(course_id: course.id).maximum(:position).to_i + 1
      Orm::Exercise.create!(course:, essential:, title:, position:, author: author || course.author,
                            **factory_publication(status), **attributes).tap do |exercise|
        questions.times do |index|
          question = exercise.questions.create!(position: index + 1, content: "<p>Question #{index + 1}</p>",
                                                question_type: "single_choice")
          4.times { |rank| question.answers.create!(position: rank + 1, content: "Proposition #{rank + 1}", correct: rank.zero?) }
        end
      end
    end

    # An exercise on the whole lesson: no essential.
    def create_lesson_wide_exercise(course: create_course, **attributes) = create_exercise(course:, lesson_wide: true, **attributes)

    # ADR-0105 : une image de question vérifiée et stockée comme par l'envoi de l'équipe, rattachée ou non à une question.
    def create_question_image(question: nil, alt: nil, fixture: "photos/photo.jpg", created_at: nil)
      input = Dtos::Shared::ContentImageInput.new(file: StringIO.new(file_fixture(fixture).binread))
      raise ArgumentError, "#{fixture} n'est pas une image de contenu : #{input.errors.full_messages}" unless input.valid?

      stored = Repositories::Assessment::QuestionImageStore.new.store(data: input.data, content_type: input.content_type,
                                                                      width: input.width, height: input.height)
      Orm::QuestionImage.find_by!(public_id: stored.public_id).tap do |image|
        columns = { question_id: question&.id, alt:, created_at: }.compact
        image.update_columns(columns) if columns.any?
      end
    end

    # ADR-0091: a question of one of the four new types. answers: texts, or [left, right] for matching; all correct.
    def create_kind_question(exercise:, question_type:, answers:, content: "Question #{factory_sequence}", numeric_tolerance: nil,
                             explanation: nil, position: exercise.questions.maximum(:position).to_i + 1)
      exercise.questions.create!(position:, content:, question_type:, numeric_tolerance:, explanation:).tap do |question|
        answers.each_with_index do |answer, rank|
          text, match_content = Array(answer)
          question.answers.create!(position: rank + 1, content: text, match_content:, correct: true)
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

    # ADR-0090 §4.1 : a student opened an essential.
    def create_essential_read(student: create_student, essential: create_essential, at: Time.current, first_read_at: at)
      Orm::EssentialRead.create!(student:, essential:, first_read_at:, last_read_at: at)
    end

    def create_gap(student: create_student, essential: create_essential, status: "pending",
                   source_session: create_exercise_session(student:, exercise: create_exercise(essential:), status: "completed",
                                                  score_percent: 40), **attributes)
      Orm::KnowledgeGap.create!(student:, essential:, source_session:, status:,
                                resolved_at: (Time.current unless status == "pending"), **attributes)
    end
  end
end
