require "test_helper"

module Queries
  module Identity
    class ShellUserQueryTest < ActiveSupport::TestCase
      setup { @query = ShellUserQuery.new }

      # carte-profil-eleve : le sigle part à part, pour la carte de profil de la barre latérale ; le détail garde le nom.
      test "a student shows their classroom and school" do
        school = create_school(name: "Lycée classique d'Abidjan", sigle: "LCA")
        student = create_student(first_name: "Awa", last_name: "Koné", classroom: create_classroom(school:, name: "Tle D 1"))

        about = ShellUserQuery::About.new(gender: "female", classroom: "Tle D 1", school: "Lycée classique d'Abidjan", sigle: "LCA")
        assert_equal ShellUserQuery::Row.new(name: "Awa Koné", role: :student, detail: "Tle D 1 · Lycée classique d'Abidjan",
                                             public_id: student.public_id, photo_version: nil, about:),
                     @query.call(user_id: student.id)
      end

      # UDR-0128 : le message prêt de WhatsApp lit les mêmes éléments, séparés, sans requête de plus que l'en-tête.
      test "the parts of the detail come apart, with the gender, in the same queries as before" do
        teacher = create_teacher(school: create_school(name: "Lycée moderne de Cocody"), material: create_material(name: "Mathématiques"),
                                 gender: "male")
        admin = create_school_admin(school: create_school(name: "Collège Notre-Dame"))
        student = create_student(classroom: create_classroom(name: "Tle D 1"))

        assert_queries_count(3) { @query.call(user_id: teacher.id) }
        assert_queries_count(2) { @query.call(user_id: admin.id) }
        assert_queries_count(2) { @query.call(user_id: student.id) }
        assert_equal ShellUserQuery::About.new(gender: "male", material: "Mathématiques", school: "Lycée moderne de Cocody"),
                     @query.call(user_id: teacher.id).about
        assert_equal ShellUserQuery::About.new(gender: "female", school: "Collège Notre-Dame"), @query.call(user_id: admin.id).about
        assert_equal ShellUserQuery::About.new(gender: "female"), @query.call(user_id: create_team_member.id).about
      end

      test "a student without a classroom has no detail" do
        assert_nil @query.call(user_id: create_student.id).detail
      end

      test "a student whose only classroom is archived has no detail, and gets it back once the classroom is restored (ADR-0088)" do
        classroom = create_classroom(name: "Tle D 1")
        student = create_student(classroom:)
        repository = Repositories::Classroom::ClassroomRepository.new

        repository.archive(id: classroom.id, at: Time.current)
        assert_nil @query.call(user_id: student.id).detail

        repository.restore(id: classroom.id, at: Time.current)
        assert_match(/\ATle D 1 · /, @query.call(user_id: student.id).detail)
      end

      test "a student with a left archived classroom and an active primary one shows the active one" do
        archived = create_classroom(name: "Tle D 1")
        student = create_student(classroom: archived)
        Orm::ClassroomStudent.where(student:).update_all(primary: false)
        Orm::ClassroomStudent.create!(classroom: create_classroom(name: "Tle D 2"), student:, primary: true, joined_at: Time.current,
                                      joined_via: "standard")
        Repositories::Classroom::ClassroomRepository.new.archive(id: archived.id, at: Time.current)

        assert_match(/\ATle D 2 · /, @query.call(user_id: student.id).detail)
      end

      test "a teacher shows their subject and primary school" do
        teacher = create_teacher(school: create_school(name: "Lycée moderne de Cocody"), material: create_material(name: "Mathématiques"))

        assert_equal "Mathématiques · Lycée moderne de Cocody", @query.call(user_id: teacher.id).detail
      end

      # ME-08 (UDR-0098 §3.1) : la ligne de détail nomme l'établissement courant ; un établissement quitté, le principal.
      test "a teacher of two schools shows the current one, and the primary one for a school they left" do
        primary = create_school(name: "Lycée moderne d'Abobo")
        other = create_school(name: "Collège Saint-Michel")
        teacher = create_teacher(school: primary, material: create_material(name: "SVT"))
        add_teacher_school(teacher, other)

        assert_equal "SVT · Collège Saint-Michel", @query.call(user_id: teacher.id, current_school_id: other.id).detail
        assert_equal "SVT · Lycée moderne d'Abobo", @query.call(user_id: teacher.id, current_school_id: create_school.id).detail
      end

      # EPM-14 (UDR-0126 §3.5) : plusieurs matières, les noms courts ; celles de l'établissement courant seulement.
      test "a teacher of two subjects shows their short names, those of the current school only" do
        pc = create_material(name: "Physique-Chimie", shortname: "PC")
        svt = create_material(name: "SVT", shortname: "SVT")
        primary = create_school(name: "Lycée A")
        other = create_school(name: "Lycée B")
        teacher = create_teacher(school: primary, materials: [ pc, svt ])
        add_teacher_school(teacher, other, materials: [ svt ])

        assert_equal "PC, SVT · Lycée A", @query.call(user_id: teacher.id, current_school_id: primary.id).detail
        assert_equal "SVT · Lycée B", @query.call(user_id: teacher.id, current_school_id: other.id).detail
      end

      test "a teacher without any school has no detail" do
        assert_nil @query.call(user_id: create_teacher(school: nil).id).detail
      end

      test "a team member has no detail, an unknown account is nil" do
        row = @query.call(user_id: create_team_member(first_name: "Kam", last_name: "Kara").id)

        assert_equal [ "Kam Kara", :team, nil, nil ], row.to_h.values_at(:name, :role, :detail, :photo_version)
        assert_nil @query.call(user_id: 0)
      end

      test "an account with a photo gives its public id and the version of its photo (ADR-0060)" do
        student = attach_photo(create_student)

        row = @query.call(user_id: student.id)

        assert_equal student.public_id, row.public_id
        assert_equal PhotoVersions.for(user_ids: [ student.id ])[student.id], row.photo_version
        assert_not_nil row.photo_version
      end
    end
  end
end
