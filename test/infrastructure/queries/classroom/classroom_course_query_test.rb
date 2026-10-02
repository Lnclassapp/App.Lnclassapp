require "test_helper"

module Queries
  module Classroom
    # CL-11 : l'ancien écran levait NameError dès que le cours avait une fiche. ADR-0072 §4.1 : ni le cours ni ses fiches
    # ne s'assignent plus ; la query ne lit aucune assignation.
    class ClassroomCourseQueryTest < ActiveSupport::TestCase
      setup do
        @classroom = create_classroom(name: "Tle D 1")
        @course = create_course(name: "Génétique et évolution", level: create_level(name: "Tle"), series: create_series(name: "D"),
                                material: create_material(name: "SVT", category: "science"), subtitle: "Du gène à l'espèce")
        @meiose = create_essential(course: @course, name: "La méiose", subtitle: "Deux divisions")
        @mitose = create_essential(course: @course, name: "La mitose")
      end

      def query = ClassroomCourseQuery.new.call(classroom_public_id: @classroom.public_id, course_slug: @course.slug)

      test "la classe, le cours et ses fiches publiées dans l'ordre, sans assignation" do
        create_essential(course: @course, name: "Brouillon", status: "draft")
        create_essential(course: @course, name: "Archivée", status: "archived")

        row = query

        assert_equal [ @classroom.public_id, "Tle D 1" ], [ row.classroom_public_id, row.classroom_name ]
        assert_equal [ @course.slug, "Génétique et évolution", "Du gène à l'espèce", "Tle", "D", "SVT", "science" ],
                     row.course.to_h.values_at(:slug, :name, :subtitle, :level_name, :series_name, :material_name,
                                               :material_category)
        assert_equal [ [ @meiose.slug, "La méiose", "Deux divisions" ], [ @mitose.slug, "La mitose", nil ] ],
                     row.essentials.map { it.to_h.values_at(:slug, :name, :subtitle) }
      end

      test "chaque fiche compte ses exercices publiés" do
        2.times { create_exercise(essential: @meiose) }
        create_exercise(essential: @meiose, status: "draft")
        create_exercise(essential: @meiose, status: "archived")

        assert_equal [ 2, 0 ], query.essentials.map(&:exercises_count)
      end

      # ADR-0072 §4.1 : le cours et la fiche n'ont plus d'assignation à montrer ; un exercice assigné ne les rend pas « assignés ».
      test "aucune assignation n'est lue : un exercice assigné ne fait passer ni le cours ni sa fiche pour assignés" do
        create_assignment(classroom: @classroom, assignable: create_exercise(essential: @meiose))
        # Un exercice qui porterait le même identifiant qu'une fiche ne change rien non plus.
        create_assignment(classroom: @classroom, assignable: Orm::Exercise.new(id: @mitose.id))

        row = query

        assert_not_includes ClassroomCourseQuery::CourseRow.members, :assignment_public_id
        assert_not_includes ClassroomCourseQuery::EssentialRow.members, :assignment_public_id
        assert_equal [ 1, 0 ], row.essentials.map(&:exercises_count)
      end

      test "un cours sans série ni fiche publiée" do
        course = create_course(series: nil)

        row = ClassroomCourseQuery.new.call(classroom_public_id: @classroom.public_id, course_slug: course.slug)

        assert_nil row.course.series_name
        assert_empty row.essentials
      end

      test "une classe inconnue, un cours inconnu ou non publié : nil" do
        draft = create_course(status: "draft")
        archived = create_course(status: "archived")

        assert_nil ClassroomCourseQuery.new.call(classroom_public_id: "inconnue", course_slug: @course.slug)
        [ "inconnu", draft.slug, archived.slug ].each do |course_slug|
          assert_nil ClassroomCourseQuery.new.call(classroom_public_id: @classroom.public_id, course_slug:), course_slug
        end
      end
    end
  end
end
