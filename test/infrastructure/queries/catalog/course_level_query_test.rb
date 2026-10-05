require "test_helper"

module Queries
  module Catalog
    class CourseLevelQueryTest < ActiveSupport::TestCase
      test "le niveau et la série du cours, depuis son slug, son id ou un de ses exercices ; inconnu : nil" do
        course = create_course(level: create_level, series: create_series)
        exercise = create_exercise(essential: create_essential(course:))
        expected = { level_id: course.level_id, series_id: course.series_id }
        query = CourseLevelQuery.new

        assert_equal expected, query.call(course_slug: course.slug)
        assert_equal expected, query.call(course_id: course.id)
        assert_equal expected, query.call(exercise_public_id: exercise.public_id)
        assert_nil query.call(course_slug: "inconnu")
        assert_nil query.call(exercise_public_id: "inconnu")
      end
    end
  end
end
