require "test_helper"

module Queries
  module Classroom
    # CA-27 : l'ancien pied de carte dépendait de @teacher_classrooms, que rien ne renseignait. Ici, les classes actives
    # de l'enseignant sont lues d'une requête, chacune avec l'assignation active de ce cours seulement.
    class CourseAssignmentTargetsQueryTest < ActiveSupport::TestCase
      setup do
        @sixieme = create_level(name: "6ème", position: 1)
        @terminale = create_level(name: "Tle", position: 7)
        @school = create_school(name: "Lycée Classique")
        @tle = create_classroom(name: "Tle D 1", level: @terminale, series: create_series(name: "D"), school: @school)
        @sixieme_10 = create_classroom(name: "6ème 10", level: @sixieme, school: @school)
        @sixieme_2 = create_classroom(name: "6ème 2", level: @sixieme, school: @school)
        @teacher = create_teacher(classrooms: [ @tle, @sixieme_10, @sixieme_2 ])
        @course = create_course(name: "Génétique", level: @terminale, series: create_series(name: "C"),
                                material: create_material(name: "SVT", category: "science"), subtitle: "Du gène à l'espèce")
      end

      def query(slug: @course.slug, teacher_id: @teacher.id) = CourseAssignmentTargetsQuery.new.call(teacher_id:, course_slug: slug)

      test "le cours et les classes actives de l'enseignant, par niveau puis dans l'ordre naturel des noms" do
        row = query

        assert_equal [ @course.slug, "Génétique", "Du gène à l'espèce", "Tle", "C", "SVT", "science" ],
                     row.course.to_h.values_at(:slug, :name, :subtitle, :level_name, :series_name, :material_name,
                                               :material_category)
        assert_equal [ [ "6ème 2", "6ème", nil, "Lycée Classique", nil ], [ "6ème 10", "6ème", nil, "Lycée Classique", nil ],
                       [ "Tle D 1", "Tle", "D", "Lycée Classique", nil ] ],
                     row.classrooms.map { it.to_h.values_at(:name, :level_name, :series_name, :school_name, :assignment_public_id) }
        assert_equal [ @sixieme_2.public_id, @sixieme_10.public_id, @tle.public_id ], row.classrooms.map(&:public_id)
      end

      test "ni classe archivée, ni classe d'un autre enseignant" do
        archived = create_classroom(status: "archived", level: @sixieme)
        Orm::TeacherClassroom.create!(teacher: @teacher, classroom: archived)
        create_teacher(classrooms: [ create_classroom(level: @sixieme) ])

        assert_equal [ "6ème 2", "6ème 10", "Tle D 1" ], query.classrooms.map(&:name)
      end

      test "l'assignation active de ce cours, jamais une ligne archivée, ni celle d'une autre ressource" do
        active = create_assignment(classroom: @tle, assignable: @course, by: @teacher)
        create_assignment(classroom: @sixieme_2, assignable: @course, by: @teacher, status: "archived")
        create_assignment(classroom: @sixieme_10, assignable: create_course, by: @teacher)
        create_assignment(classroom: @sixieme_10, assignable: create_essential(course: @course), by: @teacher)

        assert_equal [ nil, nil, active.public_id ], query.classrooms.map(&:assignment_public_id)
      end

      test "un enseignant sans classe : le cours, et aucune classe" do
        row = query(teacher_id: create_teacher.id)

        assert_equal "Génétique", row.course.name
        assert_empty row.classrooms
      end

      test "un cours inconnu ou non publié : nil" do
        assert_nil query(slug: "inconnu")
        assert_nil query(slug: create_course(status: "draft").slug)
        assert_nil query(slug: create_course(status: "archived").slug)
      end
    end
  end
end
