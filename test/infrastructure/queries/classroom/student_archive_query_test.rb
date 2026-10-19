require "test_helper"

# Lot R of fonctions-espace-eleve (ADR-0036, memo Q19): the data of a student who left stays an archive he reads from his
# account, even without an active classroom: every classroom he joined, every exercise he finished, whatever the level.
module Queries
  module Classroom
    class StudentArchiveQueryTest < ActiveSupport::TestCase
      setup do
        @school = create_school(name: "Lycée Moderne de Bouaké")
        @maths = create_material(name: "Mathématiques", category: "science")
        @student = create_student
      end

      def archive = StudentArchiveQuery.new.call(student_id: @student.id)

      def finished(title:, completed_at:, score_percent: 80, student: @student)
        course = create_course(material: @maths)
        exercise = create_exercise(essential: create_essential(course:), title:)
        create_exercise_session(student:, exercise:, status: "completed", score_percent:, completed_at:)
      end

      def joined(classroom, joined_at:, left_at: nil)
        Orm::ClassroomStudent.create!(joined_via: "standard", classroom:, student: @student, primary: true, joined_at:, left_at:)
      end

      test "the classrooms he left or that were archived, most recent first, with their school, school year and period" do
        archived_at = 2.years.ago.change(usec: 0)
        left = [ 1.year.ago.change(usec: 0), 1.month.ago.change(usec: 0) ]
        joined(create_classroom(school: @school, name: "4ème 2", level: create_level(name: "4ème"), status: "archived",
                                school_year: "2024-2025"), joined_at: archived_at)
        joined(create_classroom(school: create_school(name: "Collège Voltaire"), name: "3ème 4", level: create_level(name: "3ème"),
                                school_year: "2025-2026"), joined_at: left.first, left_at: left.last)
        create_student(classroom: create_classroom(school: @school))

        assert_equal [ StudentArchiveQuery::ClassroomRow.new(name: "3ème 4", level_name: "3ème", school_name: "Collège Voltaire",
                                                             school_year: "2025-2026", joined_at: left.first, left_at: left.last,
                                                             current: false),
                       StudentArchiveQuery::ClassroomRow.new(name: "4ème 2", level_name: "4ème", school_name: "Lycée Moderne de Bouaké",
                                                             school_year: "2024-2025", joined_at: archived_at, left_at: nil,
                                                             current: false) ], archive.classrooms
      end

      # UDR-0103 §3.1 : la classe actuelle, non quittée et active, est la seule marquée ; deux classes de la même année se
      # distinguent par leur période.
      test "UDR-0103: after a change of classroom, the one he left keeps its period, the active one is current" do
        # Un seul instant par date : deux appels à 40.days.ago peuvent tomber de part et d'autre d'une seconde.
        joined_at = 40.days.ago.change(usec: 0)
        moved_at = 3.days.ago.change(usec: 0)
        joined(create_classroom(school: @school, name: "2nde A"), joined_at:, left_at: moved_at)
        joined(create_classroom(school: create_school(name: "Collège Saint-Viateur"), name: "2nde C"), joined_at: moved_at)

        rows = archive.classrooms

        assert_equal [ [ "2nde C", moved_at, nil, true ], [ "2nde A", joined_at, moved_at, false ] ],
                     rows.map { [ it.name, it.joined_at, it.left_at, it.current ] }
        assert_equal 1, rows.map(&:school_year).uniq.size
      end

      test "every finished exercise, most recent first, out of any level; neither started ones nor another student's" do
        older = Time.zone.local(2025, 3, 2, 10)
        newer = Time.zone.local(2026, 1, 15, 9)
        finished(title: "Fractions", completed_at: older, score_percent: 45)
        finished(title: "Équations", completed_at: newer)
        create_exercise_session(student: @student, status: "started")
        finished(title: "Autre élève", completed_at: newer, student: create_student)

        assert_equal [ StudentArchiveQuery::ResultRow.new(exercise_title: "Équations", material_name: "Mathématiques",
                                                          material_slug: @maths.slug, material_category: "science",
                                                          score_percent: 80, completed_at: newer),
                       StudentArchiveQuery::ResultRow.new(exercise_title: "Fractions", material_name: "Mathématiques",
                                                          material_slug: @maths.slug, material_category: "science",
                                                          score_percent: 45, completed_at: older) ],
                     archive.results
      end

      test "the most recent results only, past the limit" do
        3.times { |day| finished(title: "Exercice #{day}", completed_at: Time.zone.local(2026, 1, day + 1)) }

        assert_equal [ "Exercice 2", "Exercice 1" ],
                     StudentArchiveQuery.new(results_limit: 2).call(student_id: @student.id).results.map(&:exercise_title)
      end

      # historique-eleve (UDR-0090 §3.1): the blue card tells the real total, the list stays capped.
      test "the completed count is the real total past the limit, finished exercises only, his own only" do
        3.times { |day| finished(title: "Exercice #{day}", completed_at: Time.zone.local(2026, 1, day + 1)) }
        create_exercise_session(student: @student, status: "started")
        finished(title: "Autre élève", completed_at: 1.day.ago, student: create_student)

        capped = StudentArchiveQuery.new(results_limit: 2).call(student_id: @student.id)

        assert_equal 2, capped.results.size
        assert_equal 3, capped.completed_count
      end

      test "a completed count of zero without any finished exercise" do
        create_exercise_session(student: @student, status: "started")

        assert_equal 0, archive.completed_count
      end

      test "an archive exists from one classroom or one finished exercise; three queries, whatever the volume" do
        assert_not StudentArchiveQuery.new.any?(student_id: @student.id)
        assert_equal StudentArchiveQuery::Archive.new(classrooms: [], results: [], completed_count: 0), archive

        create_exercise_session(student: @student, status: "started")
        assert_not StudentArchiveQuery.new.any?(student_id: @student.id)
        finished(title: "Fractions", completed_at: 1.day.ago)
        assert StudentArchiveQuery.new.any?(student_id: @student.id)

        joined(create_classroom(school: @school), joined_at: 1.year.ago, left_at: 1.day.ago)
        assert StudentArchiveQuery.new.any?(student_id: create_student(classroom: create_classroom).id)
        assert_queries_count(3) { archive }
      end
    end
  end
end
