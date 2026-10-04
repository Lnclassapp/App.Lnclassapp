require "test_helper"

# Lot R of fonctions-espace-eleve (ADR-0036, memo Q19): no automatic anonymization; the school a student left keeps reading
# the results he obtained there: the assignments he handed in to its classrooms, and his average score.
module Queries
  module School
    class DepartedStudentsQueryTest < ActiveSupport::TestCase
      TODAY = Date.new(2026, 10, 2)

      setup do
        @school = create_school(name: "Lycée Moderne de Bouaké")
        @other = create_school(name: "Collège Voltaire")
        @troisieme = create_level(name: "3ème")
        @teacher = create_teacher(school: @school)
        @exercise = create_exercise
        @last_year = create_classroom(school: @school, name: "3ème 4", level: @troisieme, status: "archived", school_year: "2025-2026")
        @this_year = create_classroom(school: @school, name: "2nde C 1", school_year: "2026-2027")
      end

      def overview(search: "", limit: DepartedStudentsQuery::LIMIT)
        DepartedStudentsQuery.new(limit:).call(school_id: @school.id, search:, today: TODAY)
      end

      def member(student, classroom, joined_at: 1.year.ago, left_at: nil)
        Orm::ClassroomStudent.create!(classroom:, student:, primary: left_at.nil?, joined_at:, left_at:)
      end

      def hand_in(student, classroom, score, **)
        exercise = create_exercise
        assignment = create_assignment(classroom:, assignable: exercise, by: @teacher)
        create_exercise_session(student:, exercise:, status: "completed", score_percent: score,
                                classroom_assignment_id: assignment.id, **)
      end

      test "a student of last year's classroom, not in a classroom of the year: his last classroom and his results here" do
        awa = create_student(first_name: "Awa", last_name: "Koné")
        member(awa, @last_year)
        hand_in(awa, @last_year, 80)
        hand_in(awa, @last_year, 60)

        assert_equal DepartedStudentsQuery::Overview.new(
          school_name: "Lycée Moderne de Bouaké", truncated: false,
          students: [ DepartedStudentsQuery::Row.new(display_name: "Awa Koné", classroom_name: "3ème 4", level_name: "3ème",
                                                     school_year: "2025-2026", submitted_count: 2, average_percent: 70) ]
        ), overview
      end

      test "a student who left for another school keeps his results here, never those obtained elsewhere" do
        yao = create_student(first_name: "Yao", last_name: "Brou")
        member(yao, @this_year, joined_at: 2.months.ago, left_at: 1.month.ago)
        elsewhere = create_classroom(school: @other, school_year: "2026-2027")
        member(yao, elsewhere, joined_at: 1.month.ago)
        hand_in(yao, @this_year, 90)
        hand_in(yao, elsewhere, 10)
        create_exercise_session(student: yao, exercise: @exercise, status: "completed", score_percent: 0)
        remediated = create_exercise
        create_exercise_session(student: yao, exercise: remediated, status: "completed", score_percent: 0, gap: create_gap(student: yao),
                                classroom_assignment_id: create_assignment(classroom: @this_year, assignable: remediated, by: @teacher).id)

        row = overview.students.sole
        assert_equal [ "Yao Brou", "2nde C 1", 1, 90 ], [ row.display_name, row.classroom_name, row.submitted_count, row.average_percent ]
      end

      test "neither a present student, nor one who never came, nor an anonymized account; without results, « — »" do
        present = create_student(last_name: "Present")
        member(present, @last_year, left_at: 1.month.ago)
        member(present, @this_year)
        create_student(classroom: create_classroom(school: @other), last_name: "Ailleurs")
        create_student(last_name: "Anonyme", anonymized_at: 1.day.ago).tap { member(it, @last_year) }
        quiet = create_student(first_name: "Fanta", last_name: "Diabaté").tap { member(it, @last_year) }

        row = overview.students.sole
        assert_equal [ quiet.first_name, 0, nil ], [ row.display_name.split.first, row.submitted_count, row.average_percent ]
      end

      test "the most recent school year first, then by name; a name is searched without case nor accents; the list is capped" do
        old = create_classroom(school: @school, status: "archived", school_year: "2024-2025")
        [ [ "Zoé", "Yao", @last_year ], [ "Aya", "Bamba", old ], [ "Éric", "Diabaté", @last_year ] ].each do |first_name, last_name, klass|
          member(create_student(first_name:, last_name:), klass)
        end

        assert_equal [ "Éric Diabaté", "Zoé Yao", "Aya Bamba" ], overview.students.map(&:display_name)
        assert_equal [ "Éric Diabaté" ], overview(search: "eric").students.map(&:display_name)
        capped = overview(limit: 2)
        assert_equal [ 2, true ], [ capped.students.size, capped.truncated ]
      end

      test "a fixed number of queries, whatever the volume" do
        3.times { |index| create_student.tap { member(it, @last_year); hand_in(it, @last_year, 50 + index) } }

        assert_queries_count(3) { overview }
      end

      # Characterization (chantier ecrans-direction-lents): what the page shows must not move while its query is rewritten.

      test "the last classroom is the latest joined in the school, the higher membership on a tie, whatever came after elsewhere" do
        old = create_classroom(school: @school, name: "4ème 2", status: "archived", school_year: "2024-2025")
        awa = create_student(first_name: "Awa", last_name: "Koné")
        member(awa, old, joined_at: 2.years.ago, left_at: 1.year.ago)
        member(awa, @last_year, joined_at: 1.year.ago)
        member(awa, create_classroom(school: @other, name: "Ailleurs"), joined_at: 1.month.ago, left_at: 1.day.ago)
        tie = create_classroom(school: @school, name: "3ème 5", level: @troisieme, status: "archived", school_year: "2025-2026")
        yao = create_student(first_name: "Yao", last_name: "Kouamé")
        joined_at = 1.year.ago
        [ @last_year, tie ].each { member(yao, it, joined_at:, left_at: 1.month.ago) }

        assert_equal [ [ "Awa Koné", "3ème 4", "3ème", "2025-2026" ], [ "Yao Kouamé", "3ème 5", "3ème", "2025-2026" ] ],
                     overview.students.map { it.to_h.values_at(:display_name, :classroom_name, :level_name, :school_year) }
      end

      test "present only through a membership not left, in an active classroom of the year, primary or not" do
        secondary = create_student(last_name: "Secondaire").tap { member(it, @last_year, left_at: 1.month.ago) }
        Orm::ClassroomStudent.create!(classroom: @this_year, student: secondary, primary: false, joined_at: 1.month.ago)
        archived_this_year = create_classroom(school: @school, name: "1ère D 2", status: "archived", school_year: "2026-2027")
        create_student(last_name: "Archivée").tap { member(it, archived_this_year) }
        active_last_year = create_classroom(school: @school, name: "Tle A 1", school_year: "2025-2026")
        create_student(last_name: "Ancienne").tap { member(it, active_last_year) }

        assert_equal [ [ "Archivée", "1ère D 2" ], [ "Ancienne", "Tle A 1" ] ],
                     overview.students.map { [ it.display_name.split.last, it.classroom_name ] }
      end

      test "within a school year, by last name, then first name, then account" do
        second = create_classroom(school: @school, name: "3ème 6", status: "archived", school_year: "2025-2026")
        [ [ "Awa", "Koné", @last_year ], [ "Adjoua", "Koné", @last_year ], [ "Awa", "Koné", second ], [ "Zoé", "Bamba", @last_year ] ]
          .each { |first_name, last_name, klass| member(create_student(first_name:, last_name:), klass) }

        assert_equal [ [ "Zoé Bamba", "3ème 4" ], [ "Adjoua Koné", "3ème 4" ], [ "Awa Koné", "3ème 4" ], [ "Awa Koné", "3ème 6" ] ],
                     overview.students.map { [ it.display_name, it.classroom_name ] }
      end

      test "a search reaches a student beyond the cap; a list exactly at the cap is not cut" do
        [ "Awa Koné", "Yao Brou", "Éric Diabaté" ].each do |name|
          first_name, last_name = name.split
          member(create_student(first_name:, last_name:), @last_year)
        end

        found = overview(search: "kone", limit: 1)
        assert_equal [ [ "Awa Koné" ], false ], [ found.students.map(&:display_name), found.truncated ]
        full = overview(limit: 3)
        assert_equal [ 3, false ], [ full.students.size, full.truncated ]
      end

      test "an assignment handed in twice counts once, both scores count; a started or abandoned session does not" do
        awa = create_student(first_name: "Awa", last_name: "Koné").tap { member(it, @last_year) }
        exercise = create_exercise
        assignment = create_assignment(classroom: @last_year, assignable: exercise, by: @teacher)
        [ 70, 75 ].each do |score|
          create_exercise_session(student: awa, exercise:, status: "completed", score_percent: score, classroom_assignment_id: assignment.id)
        end
        %w[started abandoned].each do |status|
          create_exercise_session(student: awa, exercise:, status:, classroom_assignment_id: assignment.id)
        end

        assert_equal [ 1, 73 ], overview.students.sole.to_h.values_at(:submitted_count, :average_percent)
      end
    end
  end
end
