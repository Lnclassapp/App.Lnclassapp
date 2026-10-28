require "test_helper"

# Lot A of rapports-de-classe (CL-13, AS-24 ; ADR-0097 §4.1 to §4.5, §4.8): the file of a student present in his
# classroom. The assigned exercises of the classroom with the follow-up's rules (done, late, remediation included, the
# sessions of the assignment only), the badges of his best scores there (never exercise_badges), and what he did alone
# over 30 days. Read, never written; a fixed number of queries.
module Queries
  module Classroom
    class StudentFileQueryTest < ActiveSupport::TestCase
      TODAY = Date.new(2026, 10, 15)

      setup do
        travel_to Time.zone.local(2026, 10, 15, 10)
        @school = create_school(name: "Lycée Classique d'Abidjan")
        @classroom = create_classroom(school: @school, name: "3ème B")
        @svt = create_material(name: "SVT", category: "science")
        @essential = create_essential(course: create_course(material: @svt))
        @awa = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba", contact: "0712345604",
                              joined_at: Time.zone.local(2026, 9, 14, 8))
      end

      def file(student = @awa, classroom: @classroom) = StudentFileQuery.new.call(classroom_public_id: classroom.public_id,
                                                                                  student_public_id: student.public_id, today: TODAY)

      # An assignment's due date is 1 to 7 days after it (classroom_assignments_due_on_within_a_week): assigned the day before.
      def assign(title, due_on: nil, classroom: @classroom)
        create_assignment(classroom:, assignable: create_exercise(essential: @essential, title:), due_on:,
                          assigned_at: due_on ? (due_on - 1).in_time_zone.change(hour: 8) : Time.current)
      end

      def hand_in(assignment, score, at:, student: @awa, **attributes)
        create_exercise_session(student:, exercise: Orm::Exercise.find(assignment.assignable_id), status: "completed",
                                score_percent: score, classroom_assignment: assignment, started_at: at - 10.minutes,
                                completed_at: at, **attributes)
      end

      def alone(score, started_at:, student: @awa, **attributes)
        create_exercise_session(student:, exercise: create_exercise(essential: @essential, title: "Seul #{factory_sequence}"),
                                status: "completed", score_percent: score, started_at:, completed_at: started_at + 10.minutes,
                                **attributes)
      end

      def count_queries(&)
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
        count
      end

      test "the file carries the student, the counts, the badges, the assignments and what he did alone" do
        assert_equal %i[student counts badge_counts assignments self_practice self_practice_total class_grade class_badge],
                     StudentFileQuery::File.members
        assert_equal 30, StudentFileQuery::SELF_PRACTICE_DAYS
        assert_equal 20, StudentFileQuery::SELF_PRACTICE_LIMIT
      end

      # UDR enseignant §3.2, §3.6 (Lot I) : « Moyenne 14/20 · Or », la même règle que la liste de la classe (Grading.class_badge_for).
      test "the class grade and badge: the average of the best scores on 20, ranked by the one rule of the classroom" do
        assert_equal [ nil, nil ], file.to_h.values_at(:class_grade, :class_badge)

        hand_in(assign("Un", due_on: Date.new(2026, 10, 8)), 75, at: Time.zone.local(2026, 10, 7, 9))
        hand_in(assign("Deux", due_on: Date.new(2026, 10, 9)), 85, at: Time.zone.local(2026, 10, 8, 9))
        assign("Trois")

        assert_equal [ 16, :gold ], file.to_h.values_at(:class_grade, :class_badge)
      end

      test "the class badge is Diamond when every exercise done is a perfect score, Bronze at 55 %, none under Bronze" do
        one = assign("Un")
        hand_in(one, 100, at: Time.zone.local(2026, 10, 7, 9))
        assert_equal [ 20, :diamond ], file.to_h.values_at(:class_grade, :class_badge)

        bronze = create_student(classroom: @classroom, first_name: "Koffi")
        hand_in(one, 55, at: Time.zone.local(2026, 10, 7, 9), student: bronze)
        assert_equal [ 11, :bronze ], file(bronze).to_h.values_at(:class_grade, :class_badge)

        weak = create_student(classroom: @classroom, first_name: "Yao")
        hand_in(one, 30, at: Time.zone.local(2026, 10, 7, 9), student: weak)
        assert_equal [ 6, nil ], file(weak).to_h.values_at(:class_grade, :class_badge)
      end

      test "the header: name, masked number, arrival and its channel; the full number never leaves the query" do
        student = file.student

        assert_equal [ @awa.public_id, "Awa Bamba", "07 •• •• •• 04", nil, "standard", false ],
                     student.to_h.values_at(:public_id, :display_name, :contact, :photo_version, :joined_via, :newcomer)
        assert_equal Time.zone.local(2026, 9, 14, 8), student.joined_at
        assert_not_includes file.inspect, "0712345604"

        newcomer = create_student(classroom: @classroom, joined_via: "link", joined_at: 2.days.ago)
        assert_equal [ "link", true ], file(newcomer).student.to_h.values_at(:joined_via, :newcomer)
      end

      test "three assignments: done on time with progress, late, not done past its due date; in the order of the classroom page" do
        first = assign("Les fractions", due_on: Date.new(2026, 10, 8))
        second = assign("La méiose", due_on: Date.new(2026, 10, 9))
        third = assign("Les volcans", due_on: Date.new(2026, 10, 10))
        hand_in(first, 30, at: Time.zone.local(2026, 10, 7, 10))
        best = hand_in(first, 90, at: Time.zone.local(2026, 10, 8, 18))
        hand_in(second, 60, at: Time.zone.local(2026, 10, 12, 10))
        create_exercise_session(student: @awa, exercise: Orm::Exercise.find(third.assignable_id), classroom_assignment: third)

        result = file

        assert_equal StudentFileQuery::Counts.new(done: 2, late: 1, pending: 1, assigned: 3), result.counts
        assert_equal [ first, second, third ].map(&:public_id), result.assignments.map(&:public_id)
        done, late, overdue = result.assignments
        # done_on : the day of the first session done, as on the follow-up (ADR-0072 §4.4).
        assert_equal [ "Les fractions", "SVT", "science", Date.new(2026, 10, 8), :done, Date.new(2026, 10, 7), 90, :acquired,
                       :progress, 2, best.public_id ],
                     done.to_h.values_at(:exercise_title, :material_name, :material_category, :due_on, :status, :done_on, :best,
                                         :category, :trend, :sessions_count, :best_session_public_id)
        assert_equal [ :late, Date.new(2026, 10, 12), 60, :fragile, nil, 1 ],
                     late.to_h.values_at(:status, :done_on, :best, :category, :trend, :sessions_count)
        assert_equal [ :overdue, nil, nil, nil, nil, nil, nil ],
                     overdue.to_h.values_at(:status, :done_on, :best, :category, :trend, :sessions_count, :best_session_public_id)
      end

      test "handed in on its due date is done, not late; the day after is late" do
        on_time = assign("Le jour même", due_on: TODAY - 1)
        late = assign("Le lendemain", due_on: TODAY - 1)
        hand_in(on_time, 80, at: Time.zone.local(2026, 10, 14, 23, 50))
        hand_in(late, 80, at: Time.zone.local(2026, 10, 15, 0, 5))

        assert_equal({ "Le jour même" => :done, "Le lendemain" => :late }, file.assignments.to_h { [ it.exercise_title, it.status ] })
      end

      test "not done: pending before its due date or without one, overdue after; due today is not overdue" do
        future = assign("Demain", due_on: TODAY + 1)
        today = assign("Aujourd'hui", due_on: TODAY)
        undated = assign("Sans date")

        assert_equal [ :pending, :pending, :pending ], file.assignments.map(&:status)
        assert_equal [ today, future, undated ].map(&:public_id), file.assignments.map(&:public_id)
        assert_equal StudentFileQuery::Counts.new(done: 0, late: 0, pending: 3, assigned: 3), file.counts
      end

      test "only the sessions of the assignment count: done from another classroom, alone, or archived is not done here" do
        assignment = assign("X")
        other = create_assignment(classroom: create_classroom(school: @school), assignable: Orm::Exercise.find(assignment.assignable_id))
        create_exercise_session(student: @awa, exercise: Orm::Exercise.find(assignment.assignable_id), status: "completed",
                                score_percent: 100, classroom_assignment: other)
        create_exercise_session(student: @awa, exercise: Orm::Exercise.find(assignment.assignable_id), status: "completed",
                                score_percent: 100)
        archived = assign("Retiré")
        archived.update!(status: "archived", archived_at: Time.current, archived_by: archived.assigned_by)

        assert_equal [ [ "X", :pending, nil ] ], file.assignments.map { [ it.exercise_title, it.status, it.best ] }
        assert_equal StudentFileQuery::Counts.new(done: 0, late: 0, pending: 1, assigned: 1), file.counts
      end

      test "a remediation on the assigned exercise is doing it: 25 then 75 in remediation is acquired, in progress, 2 sessions" do
        assignment = assign("Les fractions")
        hand_in(assignment, 25, at: Time.zone.local(2026, 10, 7, 10))
        hand_in(assignment, 75, at: Time.zone.local(2026, 10, 8, 10), gap: create_gap(student: @awa, essential: @essential))

        row = file.assignments.sole

        assert_equal [ :done, 75, :acquired, :progress, 2 ], row.to_h.values_at(:status, :best, :category, :trend, :sessions_count)
      end

      test "the same answer as the follow-up page for the same student and assignment" do
        assignment = assign("Les fractions", due_on: Date.new(2026, 10, 8))
        hand_in(assignment, 40, at: Time.zone.local(2026, 10, 9, 10))
        hand_in(assignment, 65, at: Time.zone.local(2026, 10, 10, 10))
        follow_up = AssignmentFollowUpQuery.new.call(classroom_public_id: @classroom.public_id, public_id: assignment.public_id)
        detail = Assessment::ComprehensionDetailQuery.new.call(classroom_public_id: @classroom.public_id,
                                                               assignment_public_id: assignment.public_id, badge: nil)

        row = file.assignments.sole

        assert_equal [ @awa.public_id ], follow_up.late_students.map(&:public_id)
        assert_equal follow_up.late_students.sole.done_on, row.done_on
        assert_equal :late, row.status
        assert_equal [ [ @awa.public_id, 65 ] ], detail.students.map { [ it.public_id, it.best ] }
        assert_equal [ 65, :fragile, :progress ], row.to_h.values_at(:best, :category, :trend)
      end

      test "badges of the classroom: by tier of the best score on each assignment, never from exercise_badges" do
        [ [ 100 ], [ 60, 85 ], [ 72 ], [ 40 ] ].each_with_index do |scores, index|
          assignment = assign("Exercice #{index}")
          scores.each_with_index { |score, rank| hand_in(assignment, score, at: Time.zone.local(2026, 10, 1 + rank, 10 + index)) }
        end
        create_badge(student: @awa, exercise: create_exercise(essential: @essential), level: "diamond")

        assert_equal({ bronze: 0, silver: 1, gold: 1, diamond: 1 }, file.badge_counts)
      end

      test "without an assignment: zero everywhere, the four tiers at zero" do
        result = file

        assert_equal StudentFileQuery::Counts.new(done: 0, late: 0, pending: 0, assigned: 0), result.counts
        assert_empty result.assignments
        assert_equal({ bronze: 0, silver: 0, gold: 0, diamond: 0 }, result.badge_counts)
        assert_empty result.self_practice
        assert_equal 0, result.self_practice_total
      end

      test "alone over 30 days, today included: completed, standard, without assignment; the most recent first" do
        recent = alone(75, started_at: Time.zone.local(2026, 10, 12, 9))
        edge = alone(50, started_at: Time.zone.local(2026, 9, 16, 0, 5))
        alone(90, started_at: Time.zone.local(2026, 9, 15, 23, 50))
        create_exercise_session(student: @awa, exercise: create_exercise(essential: @essential), started_at: 1.day.ago)
        alone(80, started_at: 2.days.ago, gap: create_gap(student: @awa, essential: @essential, source_session: recent))
        hand_in(assign("Assigné"), 100, at: 1.day.ago)
        alone(60, started_at: 1.day.ago, student: create_student(classroom: @classroom))

        result = file

        assert_equal [ recent.public_id, edge.public_id ], result.self_practice.map(&:session_public_id)
        assert_equal 2, result.self_practice_total
        row = result.self_practice.first
        assert_equal [ "SVT", "science", 75, recent.completed_at ],
                     row.to_h.values_at(:material_name, :material_category, :score_percent, :completed_at)
        assert_match(/\ASeul /, row.exercise_title)
      end

      test "alone: twenty rows at most, and the total" do
        21.times { alone(70, started_at: Time.zone.local(2026, 10, 1, 8) + it.hours) }

        result = file

        assert_equal 20, result.self_practice.size
        assert_equal 21, result.self_practice_total
        assert_equal result.self_practice.map(&:completed_at).sort.reverse, result.self_practice.map(&:completed_at)
      end

      test "no file for a student who left, an anonymized one, one of another classroom, an unknown one, or an unknown classroom" do
        left = create_student(classroom: @classroom)
        Orm::ClassroomStudent.where(student: left).update_all(left_at: Time.current)
        anonymized = create_student(classroom: @classroom)
        anonymized.update_columns(anonymized_at: Time.current)
        elsewhere = create_student(classroom: create_classroom(school: @school))

        [ left, anonymized, elsewhere ].each { assert_nil file(it) }
        assert_nil StudentFileQuery.new.call(classroom_public_id: @classroom.public_id, student_public_id: "inconnu")
        assert_nil StudentFileQuery.new.call(classroom_public_id: "inconnue", student_public_id: @awa.public_id)
      end

      test "a fixed number of queries, whatever the number of assignments" do
        one = assign("Un", due_on: Date.new(2026, 10, 8))
        hand_in(one, 50, at: Time.zone.local(2026, 10, 9, 10))
        alone(70, started_at: 1.day.ago)
        few = count_queries { file }
        9.times do |index|
          assignment = assign("Encore #{index}", due_on: (Date.new(2026, 10, 8) if index.even?))
          hand_in(assignment, 40 + index * 5, at: Time.zone.local(2026, 10, 9, 11 + index)) if index < 6
        end
        alone(80, started_at: 2.days.ago)

        assert_equal few, count_queries { file }
        assert_equal 10, file.counts.assigned
      end

      test "une session terminée d'un exercice de toute la leçon paraît dans l'entraînement seul, sans notion" do
        wide = create_lesson_wide_exercise(course: @essential.course, title: "Bilan de la leçon")
        session = create_exercise_session(student: @awa, exercise: wide, status: "completed", score_percent: 80,
                                          started_at: Time.zone.local(2026, 10, 12, 9), completed_at: Time.zone.local(2026, 10, 12, 9, 10))

        row = file.self_practice.find { it.session_public_id == session.public_id }

        assert_equal [ "Bilan de la leçon", 80 ], [ row.exercise_title, row.score_percent ]
      end
    end
  end
end
