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
        assert_equal expected, query.call(exercise_id: exercise.id)
        assert_equal expected, query.call(session_public_id: create_exercise_session(exercise:).public_id)
        assert_nil query.call(exercise_public_id: "inconnu")
        assert_nil query.call(exercise_id: 0)
        assert_nil query.call(session_public_id: "inconnu")
      end

      # Un exercice de toute la leçon n'a pas de fiche : son cours se lit par exercises.course_id.
      test "un exercice de toute la leçon, depuis son public_id, son id ou une de ses sessions" do
        course = create_course(level: create_level, series: create_series)
        lesson = create_lesson_wide_exercise(course:)
        expected = { level_id: course.level_id, series_id: course.series_id }
        query = CourseLevelQuery.new

        assert_nil lesson.essential_id
        assert_equal expected, query.call(exercise_public_id: lesson.public_id)
        assert_equal expected, query.call(exercise_id: lesson.id)
        assert_equal expected, query.call(session_public_id: create_exercise_session(exercise: lesson).public_id)
      end
    end
  end
end
