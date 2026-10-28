require "test_helper"

module Queries
  module Classroom
    # CL-11 : l'ancien écran levait NameError dès que le cours avait une fiche. ADR-0072 §4.1 : ni le cours ni ses fiches
    # ne s'assignent plus ; la query ne lit aucune assignation.
    class ClassroomCourseQueryTest < ActiveSupport::TestCase
      setup do
        level, series = create_level(name: "Tle"), create_series(name: "D")
        @classroom = create_classroom(name: "Tle D 1", level:, series:)
        @course = create_course(name: "Génétique et évolution", level:, series:,
                                material: create_material(name: "SVT", category: "science"), subtitle: "Du gène à l'espèce")
      end

      def query = ClassroomCourseQuery.new.call(classroom_public_id: @classroom.public_id, course_slug: @course.slug)

      test "la classe et l'en-tête du cours ; les sections de la leçon ont leurs propres queries" do
        row = query

        assert_equal [ @classroom.public_id, "Tle D 1" ], [ row.classroom_public_id, row.classroom_name ]
        assert_equal [ @course.slug, "Génétique et évolution", "Du gène à l'espèce", "Tle", "D", "SVT", "science" ],
                     row.course.to_h.values_at(:slug, :name, :subtitle, :level_name, :series_name, :material_name,
                                               :material_category)
        assert_equal %i[classroom_public_id classroom_name course], ClassroomCourseQuery::Row.members
      end

      test "un cours sans série" do
        course = create_course(level: @course.level, series: nil)

        row = ClassroomCourseQuery.new.call(classroom_public_id: @classroom.public_id, course_slug: course.slug)

        assert_nil row.course.series_name
      end

      test "une leçon d'un autre niveau ou d'une autre série que la classe : nil ; sans série, elle va à toutes les séries" do
        other_level = create_course(level: create_level(name: "6ème"), series: nil)
        other_series = create_course(level: @course.level, series: create_series(name: "C"))
        no_series = create_course(level: @course.level, series: nil)

        assert_nil ClassroomCourseQuery.new.call(classroom_public_id: @classroom.public_id, course_slug: other_level.slug)
        assert_nil ClassroomCourseQuery.new.call(classroom_public_id: @classroom.public_id, course_slug: other_series.slug)
        assert_equal no_series.slug, ClassroomCourseQuery.new.call(classroom_public_id: @classroom.public_id, course_slug: no_series.slug).course.slug
      end

      test "une classe inconnue, un cours inconnu ou non publié : nil" do
        draft = create_course(level: @course.level, series: @course.series, status: "draft")
        archived = create_course(level: @course.level, series: @course.series, status: "archived")

        assert_nil ClassroomCourseQuery.new.call(classroom_public_id: "inconnue", course_slug: @course.slug)
        [ "inconnu", draft.slug, archived.slug ].each do |course_slug|
          assert_nil ClassroomCourseQuery.new.call(classroom_public_id: @classroom.public_id, course_slug:), course_slug
        end
      end
    end
  end
end
