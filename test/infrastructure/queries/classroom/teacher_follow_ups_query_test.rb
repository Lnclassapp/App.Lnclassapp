require "test_helper"

module Queries
  module Classroom
    # CA-3, CA-4 (UDR-0077 §3.1): « Activités » of the teacher home lists the exercises to follow — active assignments of
    # the teacher's active classrooms of the year, in their subject, due within 7 days or late by 14 days at most, that at
    # least one present student has not done yet.
    class TeacherFollowUpsQueryTest < ActiveSupport::TestCase
      setup do
        @today = Date.new(2026, 10, 5)
        @school = create_school
        @svt = create_material(name: "SVT")
        @tle = create_level(name: "Tle")
        @classroom = create_classroom(school: @school, level: @tle, name: "Tle D 2", school_year: "2026-2027")
        @teacher = create_teacher(school: @school, material: @svt, classrooms: [ @classroom ])
        @students = Array.new(3) { create_student(classroom: @classroom) }
      end

      def follow_ups(teacher = @teacher) = TeacherFollowUpsQuery.new.call(teacher_id: teacher.id, today: @today)

      def svt_exercise(title) = create_exercise(title:, essential: create_essential(course: create_course(material: @svt, level: @tle)))

      # The table holds due_on 1 to 7 days after the day of assignment: assigned the day before its due date.
      def assign(title, due_on:, classroom: @classroom, exercise: svt_exercise(title), **)
        assigned_at = (due_on || @today).prev_day.in_time_zone.change(hour: 12)
        create_assignment(classroom:, assignable: exercise, by: @teacher, due_on:, assigned_at:, **)
      end

      def hand_in(assignment, *students)
        exercise = Orm::Exercise.find(assignment.assignable_id)
        students.each do |student|
          create_exercise_session(student:, exercise:, status: "completed", classroom_assignment: assignment, completed_at: @today.to_time)
        end
      end

      test "CA-3: the late one first, then the one due soon, with the classroom, the due date and who has not done it" do
        soon = assign("Photosynthèse", due_on: @today + 3)
        hand_in(soon, @students.first)
        late = assign("Respiration", due_on: @today - 1)

        rows = follow_ups

        assert_equal [ "Respiration", "Photosynthèse" ], rows.map(&:exercise_title)
        assert_equal({ public_id: late.public_id, exercise_title: "Respiration", classroom_public_id: @classroom.public_id,
                       classroom_name: "Tle D 2", due_on: @today - 1, pending: 3, present: 3 }, rows.first.to_h)
        assert_equal [ 2, 3 ], rows.last.to_h.values_at(:pending, :present)
      end

      test "CA-3: out of the list — due in 10 days, late by 15 days, done by everyone, without a due date, archived, another subject" do
        assign("Dans dix jours", due_on: @today + 10)
        assign("Il y a quinze jours", due_on: @today - 15)
        hand_in(assign("Fait par tous", due_on: @today + 1), *@students)
        assign("Sans échéance", due_on: nil)
        assign("Retiré", due_on: @today + 1, status: "archived")
        maths = create_exercise(title: "Maths", essential: create_essential(course: create_course(material: create_material, level: @tle)))
        assign("Maths", due_on: @today + 1, exercise: maths)

        assert_empty follow_ups
      end

      test "CA-3: the edges are included — due in exactly 7 days, late by exactly 14 days" do
        assign("Dans sept jours", due_on: @today + 7)
        assign("Il y a quatorze jours", due_on: @today - 14)

        assert_equal [ "Il y a quatorze jours", "Dans sept jours" ], follow_ups.map(&:exercise_title)
      end

      test "only present students count: a student who left, or an anonymized one, has nothing left to do" do
        left, anonymized, present = @students
        Orm::ClassroomStudent.where(student: left).update_all(left_at: Time.current)
        anonymized.update_columns(anonymized_at: Time.current)
        assignment = assign("Photosynthèse", due_on: @today + 1)

        assert_equal [ 1, 1 ], follow_ups.sole.to_h.values_at(:pending, :present)
        hand_in(assignment, present)
        assert_empty follow_ups
      end

      test "a classroom without a present student has nothing to follow" do
        empty = create_classroom(school: @school, level: @tle, name: "Tle D 3", school_year: "2026-2027")
        Orm::TeacherClassroom.create!(teacher: @teacher, classroom: empty)
        assign("Photosynthèse", due_on: @today + 1, classroom: empty)

        assert_empty follow_ups
      end

      test "only the teacher's active classrooms of the year: not a colleague's, not an archived one, not last year's" do
        other = create_classroom(school: @school, level: @tle, school_year: "2026-2027")
        create_student(classroom: other)
        archived = create_classroom(school: @school, level: @tle, status: "archived", school_year: "2026-2027")
        last_year = create_classroom(school: @school, level: @tle, school_year: "2025-2026")
        [ archived, last_year ].each do |classroom|
          Orm::TeacherClassroom.create!(teacher: @teacher, classroom:)
          create_student(classroom:)
        end
        [ other, archived, last_year ].each { |classroom| assign("Ailleurs", due_on: @today + 1, classroom:) }

        assert_empty follow_ups
      end

      test "same due date: ordered by classroom name, then by assignment" do
        second = create_classroom(school: @school, level: @tle, name: "Tle D 1", school_year: "2026-2027")
        Orm::TeacherClassroom.create!(teacher: @teacher, classroom: second)
        create_student(classroom: second)
        assign("B", due_on: @today + 2)
        assign("A", due_on: @today + 2, classroom: second)
        assign("C", due_on: @today + 2)

        assert_equal [ [ "Tle D 1", "A" ], [ "Tle D 2", "B" ], [ "Tle D 2", "C" ] ], follow_ups.map { [ it.classroom_name, it.exercise_title ] }
      end

      test "CA-4: a fixed number of queries, whatever the number of classrooms" do
        assign("Une", due_on: @today + 1)
        one = count_queries { follow_ups }
        3.times do |index|
          classroom = create_classroom(school: @school, level: @tle, school_year: "2026-2027")
          Orm::TeacherClassroom.create!(teacher: @teacher, classroom:)
          create_student(classroom:)
          assign("Autre #{index}", due_on: @today + 1, classroom:)
        end

        assert_equal 4, follow_ups.size
        assert_equal one, count_queries { follow_ups }
      end

      test "a teacher without a classroom has nothing to follow" do
        assert_empty follow_ups(create_teacher(school: @school, material: @svt))
      end

      private

      def count_queries(&)
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
        count
      end
    end
  end
end
