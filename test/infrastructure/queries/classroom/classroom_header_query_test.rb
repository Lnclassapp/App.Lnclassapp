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

      # UDR-0054 §3.2 (FU-07) : l'équipe revient de la classe à la fiche de son établissement.
      test "l'en-tête porte l'identifiant public de l'établissement de la classe" do
        school = create_school(name: "Lycée moderne de Cocody")
        classroom = create_classroom(school:)
        create_school

        assert_equal school.public_id, ClassroomHeaderQuery.new.call(public_id: classroom.public_id).school_public_id
      end

      test "une classe sans série ni code, ou inconnue" do
        classroom = create_classroom(join_code: nil)

        row = ClassroomHeaderQuery.new.call(public_id: classroom.public_id)

        assert_equal [ nil, nil, 0, [], [] ], row.to_h.values_at(:series_name, :join_code_display, :active_students_count, :student_ids, :teacher_ids)
        assert_nil ClassroomHeaderQuery.new.call(public_id: "inconnue")
      end

      # ADR-0083 §4.1, UDR-0079 §3.6 : le jeton du lien et l'établissement, faits de ManageClassroomMembersPolicy.
      test "l'en-tête porte le jeton du lien de la classe et l'identifiant de son établissement" do
        school = create_school
        classroom = create_classroom(school:)

        row = ClassroomHeaderQuery.new.call(public_id: classroom.public_id)

        assert_match(/\A\h{12}\z/, row.link_token)
        assert_equal [ classroom.reload.link_token, school.id ], [ row.link_token, row.school_id ]
      end

      # IL-12 : le bloc du lien est rendu pour qui gère la classe (policy), et seulement sur une classe active.
      test "IL-12 : le lien est montré à l'enseignant de la classe, à la direction de son établissement et à l'équipe" do
        school = create_school
        classroom = create_classroom(school:)
        teacher = create_teacher(school:, classrooms: [ classroom ])
        row = ClassroomHeaderQuery.new.call(public_id: classroom.public_id)

        assert row.link_shown_to?(actor(teacher, :teacher))
        assert row.link_shown_to?(actor(create_school_admin(school:), :school_admin, school_id: school.id))
        assert row.link_shown_to?(actor(create_team_member(second_factor: false), :team))
      end

      test "IL-12 : le lien est caché à un autre enseignant, à une autre direction, à un élève et à l'anonyme" do
        school = create_school
        classroom = create_classroom(school:)
        row = ClassroomHeaderQuery.new.call(public_id: classroom.public_id)

        assert_not row.link_shown_to?(actor(create_teacher(school:), :teacher))
        assert_not row.link_shown_to?(actor(create_school_admin, :school_admin, school_id: create_school.id))
        assert_not row.link_shown_to?(actor(create_student(classroom:), :student))
        assert_not row.link_shown_to?(nil)
      end

      test "UDR-0079 §3.6 : le lien d'une classe archivée n'est montré à personne, pas même à l'équipe" do
        classroom = create_classroom(status: "archived")
        row = ClassroomHeaderQuery.new.call(public_id: classroom.public_id)

        assert_not row.link_shown_to?(actor(create_team_member(second_factor: false), :team))
      end

      private

      def actor(user, role, school_id: nil) = Entities::Identity::Actor.new(user_id: user.id, role:, school_id:)
    end
  end
end
