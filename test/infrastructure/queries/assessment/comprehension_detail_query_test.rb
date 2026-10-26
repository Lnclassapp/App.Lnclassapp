require "test_helper"

# Lot B of rapports-exercices (ADR-0079 §4.3 to §4.7, UDR-0072 §3.5): the « Compréhension » section of the follow-up of
# an assigned exercise. Every student counts by his best score; the class reads its categories and the summary of the
# progress signs; a category reads, for each question, how many of its students got it right on their best session, then
# its students, best score first, with the day of their first hand-in, their grade on 20 and their badge. Read, never written.
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

      def detail(badge: nil, assignment: @assignment, classroom_public_id: @classroom.public_id)
        ComprehensionDetailQuery.new.call(classroom_public_id:, assignment_public_id: assignment.public_id, badge:)
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
      def counts(detail) = detail.questions.map { [ it.correct, it.answered ] }

      test "the five badge counts and the summary of the signs, without the students of a single session" do
        student(scores: [ 30, 90 ])
        student(scores: [ 72, 72 ])
        student(scores: [ 60, 65 ])
        student(scores: [ 90, 40 ])
        student(scores: [ 40 ])
        student(scores: [ 30 ])
        student

        result = detail

        assert_equal [ 6, 7, :acquired, true, nil ], result.to_h.values_at(:done, :present, :category, :readable, :selected)
        assert_equal({ none: 2, bronze: 1, silver: 1, gold: 2, diamond: 0 }, result.badge_counts)
        assert_equal 6, result.students.size
        assert_equal({ progress: 1, flat: 2, decline: 1 }, result.trend_counts)
      end

      # ADR-0079 §4.1 : une session de remédiation sur l'exercice assigné, c'est faire cet exercice ; elle compte.
      test "done and present are those of the follow-up: a remediation counts; another classroom, started, left and anonymized do not" do
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
        assert_equal [ [ 100, 20, :diamond ] ], result.students.map { [ it.best, it.grade, it.badge ] }
      end

      test "25 % in a standard session, then 75 % in remediation: « Argent », a progress, the questions read on the remediation" do
        learner = student("Awa", "Remediee", scores: [ 25 ], answers: [ { 1 => false, 2 => false, 3 => true } ])
        hand_in(learner, 75, answers: { 1 => true, 2 => true, 3 => false }, gap: create_gap(student: learner, essential: @exercise.essential))

        result = detail

        assert_equal [ 1, nil, { none: 0, bronze: 0, silver: 1, gold: 0, diamond: 0 } ], result.to_h.values_at(:done, :selected, :badge_counts)
        assert_equal({ progress: 1, flat: 0, decline: 0 }, result.trend_counts)
        assert_equal [ [ "Awa Remediee", 75, 15, :silver ] ], result.students.map { [ it.display_name, it.best, it.grade, it.badge ] }
        assert_equal [ [ 100, 1, 1 ], [ 100, 1, 1 ], [ 0, 0, 1 ] ], result.questions.map { [ it.rate, it.correct, it.answered ] }
      end

      test "nobody did it: nothing to read, every box at zero, no student" do
        student

        result = detail

        assert_equal [ 0, 1, nil, false, nil ], result.to_h.values_at(:done, :present, :category, :readable, :selected)
        assert_equal({ none: 0, bronze: 0, silver: 0, gold: 0, diamond: 0 }, result.badge_counts)
        assert_equal({ progress: 0, flat: 0, decline: 0 }, result.trend_counts)
        assert_empty result.students
        assert_equal [ nil, nil, nil ], rates(result)
        assert_equal [ [ 0, 0 ], [ 0, 0 ], [ 0, 0 ] ], counts(result)
      end

      test "under 5 done, no reading, but every student who did it is listed" do
        4.times { student(scores: [ 60 ]) }

        result = detail

        assert_equal [ 4, nil, false, nil ], result.to_h.values_at(:done, :category, :readable, :selected)
        assert_equal 4, result.students.size

        student(scores: [ 60 ])

        assert_equal [ :fragile, true ], detail.to_h.values_at(:category, :readable)
      end

      test "the badge asked for filters the students; an unknown one is ignored: everybody who did it" do
        2.times { student(scores: [ 90 ]) }
        student("Awa", "Bronze", scores: [ 55 ])
        student("Yao", "Diamant", scores: [ 100 ])
        student("Zoé", "Argent", scores: [ 72 ])
        student("Ali", "Pas-Encore", scores: [ 30 ])

        assert_equal :bronze, detail(badge: :bronze).selected
        assert_equal [ "Awa Bronze" ], detail(badge: :bronze).students.map(&:display_name)
        assert_equal [ "Yao Diamant" ], detail(badge: :diamond).students.map(&:display_name)
        assert_equal [ "Zoé Argent" ], detail(badge: :silver).students.map(&:display_name)
        assert_equal [ "Ali Pas-Encore" ], detail(badge: :none).students.map(&:display_name)
        assert_equal 2, detail(badge: :gold).students.size
        assert_equal [ nil, 6 ], [ detail(badge: :unknown).selected, detail(badge: :unknown).students.size ]
        assert_equal [ nil, 6 ], [ detail(badge: "bronze").selected, detail(badge: "bronze").students.size ]
        # The counts do not follow the filter: every box keeps its number.
        assert_equal detail.badge_counts, detail(badge: :bronze).badge_counts
      end

      test "the rank of a score is the palier of Grading: 47 is « Pas encore », 49 and 50 Bronze (ADR-0106, read on 20), 70 Argent, 80 Or, 100 Diamant, 98 only Or" do
        [ 47, 49, 50, 70, 80, 98, 100 ].each { student(scores: [ it ]) }

        assert_equal({ none: 1, bronze: 2, silver: 1, gold: 2, diamond: 1 }, detail.badge_counts)
      end

      test "the rate of a question on the best sessions never exceeds 100 %, « — » without attempt, numbered in the exercise order" do
        @questions.first.update!(position: 30)
        student(scores: [ 40, 90 ], answers: [ { 2 => true, 1 => true }, { 2 => true, 1 => true } ])
        student(scores: [ 100, 80 ], answers: [ { 2 => false }, { 2 => true } ])
        student(scores: [ 70 ], answers: [ { 2 => false } ])

        questions = detail.questions

        assert_equal [ 1, 2, 3 ], questions.map(&:number)
        assert_equal [ "<p>Question 2</p>", "<p>Question 3</p>", "<p>Question 1</p>" ], questions.map(&:content)
        assert_equal [ 33, nil, 100 ], questions.map(&:rate)
        assert_equal [ [ 1, 3 ], [ 0, 0 ], [ 1, 1 ] ], counts(detail)
      end

      test "per question: the students who got it right on their best session, over the ones who answered it, in a badge" do
        student(scores: [ 40, 60 ], answers: [ { 1 => true, 2 => false, 3 => false }, { 1 => true, 2 => true, 3 => false } ])
        student(scores: [ 30, 65 ], answers: [ { 1 => false, 2 => false, 3 => false }, { 1 => false, 2 => true, 3 => false } ])
        student(scores: [ 90 ], answers: [ { 1 => true } ])

        assert_equal [ [ 1, 2 ], [ 2, 2 ], [ 0, 2 ] ], counts(detail(badge: :bronze))
        assert_equal [ [ 1, 1 ], [ 0, 0 ], [ 0, 0 ] ], counts(detail(badge: :gold))
        assert_equal [ [ 2, 3 ], [ 2, 2 ], [ 0, 2 ] ], counts(detail)
      end

      test "the question to revisit is the least successful one of the whole class, whatever the badge asked; none without attempt" do
        assert_nil detail.weakest_question

        student(scores: [ 90 ], answers: [ { 1 => true, 2 => true, 3 => true } ])
        student(scores: [ 55 ], answers: [ { 1 => true, 2 => false, 3 => false } ])
        student(scores: [ 60 ], answers: [ { 1 => true, 2 => false, 3 => true } ])

        assert_equal 2, detail.weakest_question
        assert_equal 2, detail(badge: :gold).weakest_question
        assert_equal [ 100, 100, 100 ], detail(badge: :gold).questions.map(&:rate)
      end

      test "on a tie of the best score, the most recent session counts for the rates" do
        student(scores: [ 80, 80 ], answers: [ { 1 => false, 2 => true }, { 1 => true, 2 => false } ])

        assert_equal [ [ 1, 1 ], [ 0, 1 ], [ 0, 0 ] ], counts(detail)
      end

      test "the students, best score first, then by last name and first name, each with his grade on 20 and his badge" do
        student("Koffi", "Progres", scores: [ 50, 67 ])
        student("Awa", "Seule", scores: [ 55 ])
        student("Jean", "Baisse", scores: [ 65, 50 ])
        student("Zoé", "Achi", scores: [ 58 ])
        student("Yao", "Achi", scores: [ 58 ])
        student("Marc", "Haut", scores: [ 90, 100 ])
        student("Ali", "Pas-Encore", scores: [ 42 ])

        assert_equal [ [ "Marc Haut", 100, 20, :diamond ], [ "Koffi Progres", 67, 13, :bronze ], [ "Jean Baisse", 65, 13, :bronze ],
                       [ "Yao Achi", 58, 12, :bronze ], [ "Zoé Achi", 58, 12, :bronze ], [ "Awa Seule", 55, 11, :bronze ],
                       [ "Ali Pas-Encore", 42, 8, :none ] ],
                     detail.students.map { [ it.display_name, it.best, it.grade, it.badge ] }
        assert_equal [ "Koffi Progres", "Jean Baisse", "Yao Achi", "Zoé Achi", "Awa Seule" ],
                     detail(badge: :bronze).students.map(&:display_name)
      end

      test "the day of the first hand-in, local, is the one of the first done session, whatever the best one" do
        early = student("Awa", "Tôt")
        hand_in(early, 40)
        @clock = Time.zone.local(2026, 10, 9, 23, 30)
        hand_in(early, 90)
        late = student("Koffi", "Tard")
        @clock = Time.zone.local(2026, 10, 12, 8)
        hand_in(late, 60)

        assert_equal [ [ "Awa Tôt", Date.new(2026, 10, 5) ], [ "Koffi Tard", Date.new(2026, 10, 12) ] ],
                     detail.students.map { [ it.display_name, it.done_on ] }
      end

      # ADR-0097 §4.9 : le nom d'un élève d'une catégorie mène à sa fiche, par son public_id.
      test "a student of a category carries his public_id" do
        awa = student("Awa", "Bamba", scores: [ 55 ])

        assert_equal [ awa.public_id ], detail(badge: :bronze).students.map(&:public_id)
      end

      test "a student of two classrooms: his session on the assignment of the other classroom does not count in this one" do
        twice = student(scores: [ 60 ], answers: [ { 1 => false, 2 => false } ])
        other_classroom = create_classroom(school: @school)
        Orm::ClassroomStudent.create!(joined_via: "standard", classroom: other_classroom, student: twice, primary: false, joined_at: Time.current)
        other = create_assignment(classroom: other_classroom, assignable: @exercise)
        hand_in(twice, 100, answers: { 1 => true, 2 => true }, assignment: other)

        result = detail(badge: :bronze)

        assert_equal [ 1, 1, { none: 0, bronze: 1, silver: 0, gold: 0, diamond: 0 } ], [ result.done, result.present, result.badge_counts ]
        assert_equal({ progress: 0, flat: 0, decline: 0 }, result.trend_counts)
        assert_equal [ 60 ], result.students.map(&:best)
        assert_equal [ [ 0, 1 ], [ 0, 1 ], [ 0, 0 ] ], counts(result)
        assert_equal [ 100 ], detail(badge: :diamond, assignment: other, classroom_public_id: other_classroom.public_id).students.map(&:best)
      end

      test "an archived assignment, one of another classroom or an unknown one has no detail" do
        archived = create_assignment(classroom: @classroom, assignable: create_exercise(essential: @exercise.essential), status: "archived")

        assert_nil detail(assignment: archived)
        assert_nil detail(classroom_public_id: create_classroom(school: @school).public_id)
        assert_nil ComprehensionDetailQuery.new.call(classroom_public_id: @classroom.public_id, assignment_public_id: "inconnue",
                                                     badge: nil)
      end

      test "the detail reads in a fixed number of queries, whatever the number of students" do
        student(scores: [ 40, 90 ], answers: [ { 1 => false }, { 1 => true } ])
        few = count_queries { detail }
        6.times { |index| student(scores: [ 50 + index, 95 ], answers: [ { 1 => true, 2 => false }, { 1 => true, 3 => true } ]) }
        2.times { student }

        assert_equal 7, few
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
