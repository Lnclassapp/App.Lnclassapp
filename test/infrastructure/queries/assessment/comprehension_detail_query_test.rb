require "test_helper"

# Lot B of rapports-exercices (ADR-0079 §4.3 to §4.7, UDR-0072 §3.5): the « Compréhension » section of the follow-up of
# an assigned exercise. Every student counts by his best score; the class reads its categories and the summary of the
# progress signs; a category reads the rate of each question on the best session (and on the first one when somebody
# started over), then its students, the ones who need the teacher first. Read, never written.
module Queries
  module Assessment
    class ComprehensionDetailQueryTest < ActiveSupport::TestCase
      Comprehension = Entities::Assessment::Comprehension

      setup do
        @school = create_school
        @classroom = create_classroom(school: @school)
        @exercise = create_exercise(questions: 3)
        @questions = @exercise.questions.order(:position).to_a
        @assignment = create_assignment(classroom: @classroom, assignable: @exercise)
        @clock = Time.zone.local(2026, 10, 5, 8)
      end

      def detail(category: nil, assignment: @assignment, classroom_public_id: @classroom.public_id)
        ComprehensionDetailQuery.new.call(classroom_public_id:, assignment_public_id: assignment.public_id, category:)
      end

      # answers : { question position => correct }, the attempts of the session; sessions are completed one hour apart.
      def hand_in(student, score_percent, answers: {}, assignment: @assignment, **attributes)
        @clock += 1.hour
        create_exercise_session(student:, exercise: @exercise, status: "completed", score_percent:, classroom_assignment: assignment,
                                completed_at: @clock, **attributes).tap do |session|
          answers.each { |position, correct| create_attempt(session:, question: @questions[position - 1], correct:) }
        end
      end

      def student(first_name = "Élève", last_name = "N#{factory_sequence}", scores: [], answers: [])
        create_student(classroom: @classroom, first_name:, last_name:).tap do |student|
          scores.each_with_index { |score, index| hand_in(student, score, answers: answers[index] || {}) }
        end
      end

      def rates(detail) = detail.questions.map(&:rate)

      test "the categories and the summary of the signs, without the students of a single session" do
        student(scores: [ 30, 90 ])
        student(scores: [ 72, 72 ])
        student(scores: [ 60, 65 ])
        student(scores: [ 90, 40 ])
        student(scores: [ 40 ])
        student(scores: [ 30 ])
        student

        result = detail

        assert_equal [ 6, 7, :acquired, true, :acquired ], result.to_h.values_at(:done, :present, :category, :readable, :selected)
        assert_equal({ struggling: 2, fragile: 1, acquired: 3 }, result.category_counts)
        assert_equal({ progress: 1, flat: 2, decline: 1 }, result.trend_counts)
      end

      test "done and present are those of the follow-up: remediation, another classroom, started, left and anonymized do not count" do
        present = student(scores: [ 80 ])
        hand_in(present, 100, gap: create_gap(student: present, essential: @exercise.essential))
        hand_in(present, 100, assignment: create_assignment(classroom: create_classroom(school: @school), assignable: @exercise))
        create_exercise_session(student: present, exercise: @exercise, classroom_assignment: @assignment)
        gone = student(scores: [ 20 ])
        Orm::ClassroomStudent.where(student: gone).update_all(left_at: Time.current)
        student(scores: [ 20 ]).update_columns(anonymized_at: Time.current)
        counts = Classroom::AssignmentFollowUpQuery.counts(classroom_id: @classroom.id, assignment_ids: [ @assignment.id ])
                                                   .fetch(@assignment.id)

        result = detail

        assert_equal [ counts.done, counts.done + counts.pending ], [ result.done, result.present ]
        assert_equal [ 1, 1 ], [ result.done, result.present ]
        assert_equal [ [ 80, nil ] ], result.students.map { [ it.best, it.trend ] }
      end

      test "nobody did it: nothing to read, « En difficulté » selected, no student" do
        student

        result = detail

        assert_equal [ 0, 1, nil, false, :struggling ], result.to_h.values_at(:done, :present, :category, :readable, :selected)
        assert_equal({ struggling: 0, fragile: 0, acquired: 0 }, result.category_counts)
        assert_equal({ progress: 0, flat: 0, decline: 0 }, result.trend_counts)
        assert_empty result.students
        assert_equal [ nil, nil, nil ], rates(result)
      end

      test "under 5 done, no reading, but the detail of the most numerous category is selected" do
        4.times { student(scores: [ 60 ]) }

        result = detail

        assert_equal [ 4, nil, false, :fragile ], result.to_h.values_at(:done, :category, :readable, :selected)
        assert_equal 4, result.students.size

        student(scores: [ 60 ])

        assert_equal [ :fragile, true ], detail.to_h.values_at(:category, :readable)
      end

      test "the category asked for is selected; an unknown one is ignored for the dominant one" do
        2.times { student(scores: [ 90 ]) }
        student("Awa", "Fragile", scores: [ 55 ])

        assert_equal :fragile, detail(category: :fragile).selected
        assert_equal [ "Awa Fragile" ], detail(category: :fragile).students.map(&:display_name)
        assert_equal :acquired, detail(category: :unknown).selected
        assert_equal :acquired, detail(category: "fragile").selected
        assert_equal :struggling, detail(category: :struggling).selected
        assert_empty detail(category: :struggling).students
      end

      test "the rate of a question on the best sessions never exceeds 100 %, « — » without attempt, numbered in the exercise order" do
        @questions.first.update!(position: 30)
        student(scores: [ 40, 90 ], answers: [ { 2 => true, 1 => true }, { 2 => true, 1 => true } ])
        student(scores: [ 100, 80 ], answers: [ { 2 => false }, { 2 => true } ])
        student(scores: [ 70 ], answers: [ { 2 => false } ])

        questions = detail(category: :acquired).questions

        assert_equal [ 1, 2, 3 ], questions.map(&:number)
        assert_equal [ "<p>Question 2</p>", "<p>Question 3</p>", "<p>Question 1</p>" ], questions.map(&:content)
        assert_equal [ 33, nil, 100 ], questions.map(&:rate)
      end

      test "progress per question: the first session reads 0 % where the best reads 100 %; under 50 % it is to revisit" do
        student(scores: [ 40, 60 ], answers: [ { 1 => true, 2 => false, 3 => false }, { 1 => true, 2 => true, 3 => false } ])
        student(scores: [ 30, 65 ], answers: [ { 1 => false, 2 => false, 3 => false }, { 1 => false, 2 => true, 3 => false } ])

        questions = detail(category: :fragile).questions

        assert_equal [ 50, 100, 0 ], questions.map(&:rate)
        assert_equal [ 50, 0, 0 ], questions.map(&:first_rate)
        assert_equal [ false, false, true ], questions.map(&:to_revisit)
      end

      test "a question at 49 % is to revisit" do
        35.times { |index| student(scores: [ 90 ], answers: [ { 1 => index < 17 } ]) }

        question = detail.questions.first

        assert_equal [ 49, true ], [ question.rate, question.to_revisit ]
      end

      test "without a student of two sessions in the category, no rate at the first session" do
        student(scores: [ 90 ], answers: [ { 1 => true } ])
        student(scores: [ 40, 50 ], answers: [ { 1 => false }, { 1 => true } ])

        assert_equal [ nil, nil, nil ], detail(category: :acquired).questions.map(&:first_rate)
        assert_equal [ 0, nil, nil ], detail(category: :fragile).questions.map(&:first_rate)
      end

      test "on a tie of the best score, the most recent session counts for the rates" do
        student(scores: [ 80, 80 ], answers: [ { 1 => false, 2 => true }, { 1 => true, 2 => false } ])

        questions = detail.questions

        assert_equal [ 100, 0, nil ], questions.map(&:rate)
        assert_equal [ 0, 100, nil ], questions.map(&:first_rate)
      end

      test "the students of a category: declining, stagnant, single session, stable, progressing, then by name" do
        student("Koffi", "Progres", scores: [ 50, 68 ])
        student("Awa", "Seule", scores: [ 55 ])
        student("Jean", "Baisse", scores: [ 65, 50 ])
        student("Zoé", "Achi", scores: [ 58 ])
        student("Ali", "Stagne", scores: [ 60, 62 ])
        student("Yao", "Achi", scores: [ 52 ])

        assert_equal [ [ "Jean Baisse", 65, :decline ], [ "Ali Stagne", 62, :stagnant ], [ "Yao Achi", 52, nil ],
                       [ "Zoé Achi", 58, nil ], [ "Awa Seule", 55, nil ], [ "Koffi Progres", 68, :progress ] ],
                     detail(category: :fragile).students.map { [ it.display_name, it.best, it.trend ] }

        student("Marc", "Progres", scores: [ 60, 90 ])
        student("Léa", "Stable", scores: [ 85, 80 ])

        assert_equal [ [ "Léa Stable", :stable ], [ "Marc Progres", :progress ] ],
                     detail(category: :acquired).students.map { [ it.display_name, it.trend ] }
      end

      test "an archived assignment, one of another classroom or an unknown one has no detail" do
        archived = create_assignment(classroom: @classroom, assignable: create_exercise(essential: @exercise.essential), status: "archived")

        assert_nil detail(assignment: archived)
        assert_nil detail(classroom_public_id: create_classroom(school: @school).public_id)
        assert_nil ComprehensionDetailQuery.new.call(classroom_public_id: @classroom.public_id, assignment_public_id: "inconnue",
                                                     category: nil)
      end

      test "the detail reads in a fixed number of queries, whatever the number of students" do
        student(scores: [ 40, 90 ], answers: [ { 1 => false }, { 1 => true } ])
        few = count_queries { detail }
        6.times { |index| student(scores: [ 50 + index, 95 ], answers: [ { 1 => true, 2 => false }, { 1 => true, 3 => true } ]) }
        2.times { student }

        assert_equal 6, few
        assert_equal few, count_queries { detail }
        assert_equal 7, detail.students.size
      end

      def count_queries(&)
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
        count
      end
    end
  end
end
