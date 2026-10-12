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

      test "the classrooms he left or that were archived, most recent first, with their school and school year" do
        joined(create_classroom(school: @school, name: "4ème 2", level: create_level(name: "4ème"), status: "archived",
                                school_year: "2024-2025"), joined_at: 2.years.ago)
        joined(create_classroom(school: create_school(name: "Collège Voltaire"), name: "3ème 4", level: create_level(name: "3ème"),
                                school_year: "2025-2026"), joined_at: 1.year.ago, left_at: 1.month.ago)
        create_student(classroom: create_classroom(school: @school))

        assert_equal [ StudentArchiveQuery::ClassroomRow.new(name: "3ème 4", level_name: "3ème", school_name: "Collège Voltaire",
                                                             school_year: "2025-2026"),
                       StudentArchiveQuery::ClassroomRow.new(name: "4ème 2", level_name: "4ème", school_name: "Lycée Moderne de Bouaké",
                                                             school_year: "2024-2025") ], archive.classrooms
      end

      test "every finished exercise, most recent first, out of any level; neither started ones nor another student's" do
        older = Time.zone.local(2025, 3, 2, 10)
        newer = Time.zone.local(2026, 1, 15, 9)
        finished(title: "Fractions", completed_at: older, score_percent: 45)
        finished(title: "Équations", completed_at: newer)
        create_exercise_session(student: @student, status: "started")
        finished(title: "Autre élève", completed_at: newer, student: create_student)

        assert_equal [ StudentArchiveQuery::ResultRow.new(exercise_title: "Équations", material_name: "Mathématiques",
                                                          material_category: "science", score_percent: 80, completed_at: newer),
                       StudentArchiveQuery::ResultRow.new(exercise_title: "Fractions", material_name: "Mathématiques",
                                                          material_category: "science", score_percent: 45, completed_at: older) ],
                     archive.results
      end

      test "the most recent results only, past the limit" do
        3.times { |day| finished(title: "Exercice #{day}", completed_at: Time.zone.local(2026, 1, day + 1)) }

        assert_equal [ "Exercice 2", "Exercice 1" ],
                     StudentArchiveQuery.new(results_limit: 2).call(student_id: @student.id).results.map(&:exercise_title)
      end

      test "an archive exists from one classroom or one finished exercise; two queries, whatever the volume" do
        assert_not StudentArchiveQuery.new.any?(student_id: @student.id)
        assert_equal StudentArchiveQuery::Archive.new(classrooms: [], results: []), archive

        create_exercise_session(student: @student, status: "started")
        assert_not StudentArchiveQuery.new.any?(student_id: @student.id)
        finished(title: "Fractions", completed_at: 1.day.ago)
        assert StudentArchiveQuery.new.any?(student_id: @student.id)

        joined(create_classroom(school: @school), joined_at: 1.year.ago, left_at: 1.day.ago)
        assert StudentArchiveQuery.new.any?(student_id: create_student(classroom: create_classroom).id)
        assert_queries_count(2) { archive }
      end
    end
  end
end
