require "test_helper"

module Queries
  module Classroom
    class ClassroomHeaderQueryTest < ActiveSupport::TestCase
      test "l'en-tête d'une classe porte ses libellés, son code affiché et les faits des policies" do
        school = create_school(name: "Lycée Classique")
        classroom = create_classroom(school:, level: create_level(name: "Tle"), series: create_series(name: "D"), name: "Tle D 1",
                                     join_code: "abc23", max_students: 60)
        present = create_student(classroom:)
        left = create_student(classroom:)
        Orm::ClassroomStudent.where(student: left).update_all(left_at: Time.current)
        teacher = create_teacher(school:, classrooms: [ classroom ])

        row = ClassroomHeaderQuery.new.call(public_id: classroom.public_id)

        assert_equal [ classroom.public_id, "Tle D 1", "Tle", "D", "Lycée Classique", classroom.school_year, "active", "ABC23", 60 ],
                     row.to_h.values_at(:public_id, :name, :level_name, :series_name, :school_name, :school_year, :status,
                                        :join_code_display, :max_students)
        assert_equal [ 1, [ present.id ], [ teacher.id ] ], [ row.active_students_count, row.student_ids, row.teacher_ids ]
      end

      test "une classe sans série ni code, ou inconnue" do
        classroom = create_classroom(join_code: nil)

        row = ClassroomHeaderQuery.new.call(public_id: classroom.public_id)

        assert_equal [ nil, nil, 0, [], [] ], row.to_h.values_at(:series_name, :join_code_display, :active_students_count, :student_ids, :teacher_ids)
        assert_nil ClassroomHeaderQuery.new.call(public_id: "inconnue")
      end
    end
  end
end
