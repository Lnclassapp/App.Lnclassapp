require "test_helper"

# Lot E of fonctions-espace-eleve (ADR-0072 §4.4, UDR-0062 §3.5): the follow-up of an assigned exercise. « Fait » is a
# completed session attached to the assignment (ADR-0048), standard or remediation (ADR-0079 §4.1); « rendu en retard » compares the local date of the
# FIRST one with due_on, the due day itself being on time. Read, never written.
module Queries
  module Classroom
    class AssignmentFollowUpQueryTest < ActiveSupport::TestCase
      DUE_ON = Date.new(2026, 10, 8)

      setup do
        @school = create_school(name: "Lycée Classique d'Abidjan")
        @classroom = create_classroom(school: @school, name: "3ème B")
        svt = create_material(name: "SVT", category: "science")
        @exercise = create_exercise(essential: create_essential(course: create_course(material: svt)), title: "La méiose")
        @assignment = travel_to(Time.zone.local(2026, 10, 5, 9)) do
          create_assignment(classroom: @classroom, assignable: @exercise, due_on: DUE_ON)
        end
      end

      def follow_up(assignment = @assignment, classroom_public_id: @classroom.public_id)
        AssignmentFollowUpQuery.new.call(classroom_public_id:, public_id: assignment.public_id)
      end

      def hand_in(student, at:, assignment: @assignment, **attributes)
        create_exercise_session(student:, exercise: Orm::Exercise.find(assignment.assignable_id), status: "completed",
                                classroom_assignment: assignment, completed_at: at, **attributes)
      end

      test "the header of the follow-up: exercise, material, due date and assignment date" do
        row = follow_up

        assert_equal [ @assignment.public_id, @exercise.public_id, "La méiose", "SVT", "science", DUE_ON, Date.new(2026, 10, 5) ],
                     row.to_h.values_at(:public_id, :exercise_public_id, :exercise_title, :material_name, :material_category,
                                        :due_on, :assigned_on)
      end

      test "handed in on the due day is on time; the next day is late; nobody yet is « pas encore fait »" do
        on_time = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
        late = create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao")
        create_student(classroom: @classroom, first_name: "Jean", last_name: "Kouassi")
        hand_in(on_time, at: Time.zone.local(2026, 10, 8, 23, 30))
        hand_in(late, at: Time.zone.local(2026, 10, 9, 0, 10))

        row = follow_up

        assert_equal AssignmentFollowUpQuery::Counts.new(done: 2, late: 1, pending: 1), row.counts
        assert_equal [ AssignmentFollowUpQuery::LateStudent.new(display_name: "Koffi Yao", done_on: Date.new(2026, 10, 9)) ],
                     row.late_students
      end

      test "the first handed-in session decides: redone after a late one stays late, redone after an on-time one stays on time" do
        late = create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao")
        on_time = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
        hand_in(late, at: Time.zone.local(2026, 10, 9, 10))
        hand_in(late, at: Time.zone.local(2026, 10, 10, 10))
        hand_in(on_time, at: Time.zone.local(2026, 10, 7, 10))
        hand_in(on_time, at: Time.zone.local(2026, 10, 12, 10))

        row = follow_up

        assert_equal AssignmentFollowUpQuery::Counts.new(done: 2, late: 1, pending: 0), row.counts
        assert_equal [ [ "Koffi Yao", Date.new(2026, 10, 9) ] ], row.late_students.map { [ it.display_name, it.done_on ] }
      end

      test "a started session or a completed one outside the assignment does not count: still « pas encore fait »" do
        student = create_student(classroom: @classroom)
        create_exercise_session(student:, exercise: @exercise, classroom_assignment: @assignment)
        create_exercise_session(student:, exercise: @exercise, status: "completed", completed_at: Time.zone.local(2026, 10, 9, 10))

        assert_equal AssignmentFollowUpQuery::Counts.new(done: 0, late: 0, pending: 1), follow_up.counts
        assert_empty follow_up.late_students
      end

      # ADR-0079 §4.1 : une session de remédiation sur l'exercice assigné, c'est faire cet exercice. Une lacune ouverte par
      # un autre exercice de la fiche fait de la session de l'exercice assigné une remédiation (ADR-0043) : elle compte.
      test "a remediation session is doing the exercise: alone on the assignment, it is done, late after the due date" do
        late = create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao")
        on_time = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
        create_student(classroom: @classroom, first_name: "Jean", last_name: "Kouassi")
        hand_in(late, at: Time.zone.local(2026, 10, 9, 10), gap: create_gap(student: late, essential: @exercise.essential))
        hand_in(on_time, at: Time.zone.local(2026, 10, 8, 10), gap: create_gap(student: on_time, essential: @exercise.essential))

        row = follow_up

        assert_equal AssignmentFollowUpQuery::Counts.new(done: 2, late: 1, pending: 1), row.counts
        assert_equal [ AssignmentFollowUpQuery::LateStudent.new(display_name: "Koffi Yao", done_on: Date.new(2026, 10, 9)) ],
                     row.late_students
        assert_equal [ AssignmentFollowUpQuery::PendingStudent.new(display_name: "Jean Kouassi") ], row.pending_students
      end

      test "the first done session decides, whatever its kind: a remediation on time, then a standard one late, is on time" do
        student = create_student(classroom: @classroom)
        hand_in(student, at: Time.zone.local(2026, 10, 7, 10), gap: create_gap(student:, essential: @exercise.essential))
        hand_in(student, at: Time.zone.local(2026, 10, 10, 10))

        assert_equal AssignmentFollowUpQuery::Counts.new(done: 1, late: 0, pending: 0), follow_up.counts
        assert_empty follow_up.late_students
      end

      test "a student who left or whose account was anonymized is counted nowhere" do
        gone = create_student(classroom: @classroom, last_name: "Parti")
        hand_in(gone, at: Time.zone.local(2026, 10, 9, 10))
        Orm::ClassroomStudent.where(student: gone).update_all(left_at: Time.current)
        anonymized = create_student(classroom: @classroom, last_name: "Anonyme")
        hand_in(anonymized, at: Time.zone.local(2026, 10, 9, 10))
        anonymized.update_columns(anonymized_at: Time.current)
        create_student(classroom: create_classroom(school: @school))

        assert_equal AssignmentFollowUpQuery::Counts.new(done: 0, late: 0, pending: 0), follow_up.counts
        assert_empty follow_up.late_students
      end

      test "late students are named by last name, then first name, with the date of their first handed-in session" do
        [ %w[Zoé Bamba], %w[Awa Bamba], %w[Koffi Achi] ].each_with_index do |(first_name, last_name), index|
          hand_in(create_student(classroom: @classroom, first_name:, last_name:), at: Time.zone.local(2026, 10, 9 + index, 10))
        end

        assert_equal [ [ "Koffi Achi", Date.new(2026, 10, 11) ], [ "Awa Bamba", Date.new(2026, 10, 10) ], [ "Zoé Bamba", Date.new(2026, 10, 9) ] ],
                     follow_up.late_students.map { [ it.display_name, it.done_on ] }
      end

      test "the students not done yet are named by last name, then first name; one with only a started session among them" do
        [ %w[Zoé Bamba], %w[Awa Bamba], %w[Koffi Achi] ].each { |first_name, last_name| create_student(classroom: @classroom, first_name:, last_name:) }
        started = create_student(classroom: @classroom, first_name: "Jean", last_name: "Kouassi")
        create_exercise_session(student: started, exercise: @exercise, classroom_assignment: @assignment)
        hand_in(create_student(classroom: @classroom, first_name: "Fait", last_name: "Déjà"), at: Time.zone.local(2026, 10, 7, 10))

        row = follow_up

        assert_equal [ AssignmentFollowUpQuery::PendingStudent.new(display_name: "Koffi Achi"), AssignmentFollowUpQuery::PendingStudent.new(display_name: "Awa Bamba"),
                       AssignmentFollowUpQuery::PendingStudent.new(display_name: "Zoé Bamba"), AssignmentFollowUpQuery::PendingStudent.new(display_name: "Jean Kouassi") ],
                     row.pending_students
        assert_equal row.counts.pending, row.pending_students.size
      end

      test "a student who left, an anonymized one or one of another classroom is not « pas encore fait »; all done, nobody waits" do
        Orm::ClassroomStudent.where(student: create_student(classroom: @classroom, last_name: "Parti")).update_all(left_at: Time.current)
        create_student(classroom: @classroom, last_name: "Anonyme").update_columns(anonymized_at: Time.current)
        create_student(classroom: create_classroom(school: @school), last_name: "Ailleurs")
        hand_in(create_student(classroom: @classroom, last_name: "Fait"), at: Time.zone.local(2026, 10, 7, 10))
        other = create_assignment(classroom: @classroom, assignable: create_exercise(essential: @exercise.essential))

        assert_empty follow_up.pending_students
        assert_equal [ "Fait" ], follow_up(other).pending_students.map { it.display_name.split.last }
      end

      test "without a due date, nothing is late: done and pending only" do
        assignment = create_assignment(classroom: @classroom, assignable: create_exercise(essential: @exercise.essential))
        hand_in(create_student(classroom: @classroom), assignment:, at: 1.day.from_now)
        create_student(classroom: @classroom)

        row = follow_up(assignment)

        assert_nil row.due_on
        assert_equal AssignmentFollowUpQuery::Counts.new(done: 1, late: 0, pending: 1), row.counts
        assert_empty row.late_students
      end

      test "an archived assignment, one of another classroom or an unknown one has no follow-up" do
        archived = create_assignment(classroom: @classroom, assignable: create_exercise(essential: @exercise.essential), status: "archived")

        assert_nil follow_up(archived)
        assert_nil follow_up(classroom_public_id: create_classroom(school: @school).public_id)
        assert_nil AssignmentFollowUpQuery.new.call(classroom_public_id: @classroom.public_id, public_id: "inconnue")
      end

      test "counts: several assignments of a classroom in a fixed number of queries, zero for one nobody did" do
        other = create_assignment(classroom: @classroom, assignable: create_exercise(essential: @exercise.essential))
        3.times { hand_in(create_student(classroom: @classroom), at: Time.zone.local(2026, 10, 9, 10)) }

        counts = AssignmentFollowUpQuery.counts(classroom_id: @classroom.id, assignment_ids: [ @assignment.id, other.id ])

        assert_equal({ @assignment.id => AssignmentFollowUpQuery::Counts.new(done: 3, late: 3, pending: 0),
                       other.id => AssignmentFollowUpQuery::Counts.new(done: 0, late: 0, pending: 3) }, counts)
        assert_equal({}, AssignmentFollowUpQuery.counts(classroom_id: @classroom.id, assignment_ids: []))
      end

      test "the follow-up reads in a fixed number of queries, whatever the number of students" do
        hand_in(create_student(classroom: @classroom), at: Time.zone.local(2026, 10, 9, 10))
        few = count_queries { follow_up }
        5.times { hand_in(create_student(classroom: @classroom), at: Time.zone.local(2026, 10, 9 + it % 2, 10)) }
        3.times { create_student(classroom: @classroom) }

        assert_equal few, count_queries { follow_up }
        assert_equal 6, follow_up.counts.late
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
