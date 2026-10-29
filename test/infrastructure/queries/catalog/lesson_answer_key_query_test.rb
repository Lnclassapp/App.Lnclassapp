require "test_helper"

module Queries
  module Catalog
    # UDR-XXXX §3.5, CA-15 : tous les exercices de la leçon, dans l'ordre de « Prépare interros », avec bonnes réponses et corrections.
    class LessonAnswerKeyQueryTest < ActiveSupport::TestCase
      setup do
        @course = create_course(status: "draft", figures: [ revision_figure ])
        @n1 = create_essential(course: @course, name: "Notion 1", position: 1, status: "draft")
        @n2 = create_essential(course: @course, name: "Notion 2", position: 2, status: "draft")
        @wide = create_lesson_wide_exercise(course: @course, title: "Large", status: "draft", position: 1)
        @ex2 = create_exercise(essential: @n2, title: "Ex 2", status: "draft", position: 2)
        @ex1 = create_exercise(essential: @n1, title: "Ex 1", status: "draft", position: 3, figure_key: "triangle-thales")
      end

      def call(slug = @course.slug) = LessonAnswerKeyQuery.new.call(course_slug: slug)

      test "the exercises come notions first, in the notion order, then the whole-lesson ones, whatever their status" do
        key = call

        assert_equal [ "Ex 1", "Ex 2", "Large" ], key.exercises.map(&:title)
        assert_equal [ "Notion 1", "Notion 2", nil ], key.exercises.map(&:essential_name)
        assert_equal "draft", key.status
        assert_equal 3, key.exercises.size
        assert_equal 6, key.questions_count
      end

      test "an archived exercise is left out, a draft one is kept" do
        @ex2.update!(status: "archived", archived_at: Time.current)

        assert_equal [ "Ex 1", "Large" ], call.exercises.map(&:title)
      end

      test "a question carries its points, its right answers and its correction" do
        question = @ex1.questions.order(:position).first
        question.update!(points: 2.5, explanation: "Parce que 4.")

        row = call.exercises.first.questions.first

        assert_equal "choice", row.kind_name
        assert_equal 2.5, row.points
        assert_equal "Parce que 4.", row.explanation
        assert_equal [ [ "Proposition 1", true ], [ "Proposition 2", false ], [ "Proposition 3", false ], [ "Proposition 4", false ] ],
                     row.answers.map { [ it.content, it.correct ] }
      end

      test "a numeric question gives its expected value and unit, a written one its model answer" do
        numeric = create_kind_question(exercise: @ex2, question_type: "numeric", answers: [ "12,5" ], numeric_tolerance: 0.1)
        numeric.update!(unit: "cm")
        create_kind_question(exercise: @ex2, question_type: "written", answers: [], explanation: "Corrigé type rédigé.")

        rows = call.exercises.second.questions.last(2)

        assert_equal [ "numeric", "12,5", "cm" ], [ rows.first.kind_name, rows.first.answers.first.content, rows.first.unit ]
        assert_equal [ "written", "Corrigé type rédigé.", [] ], [ rows.last.kind_name, rows.last.explanation, rows.last.answers ]
      end

      test "an exercise that cites a figure of the lesson carries it, the others none" do
        exercises = call.exercises

        assert_equal "triangle-thales", exercises.first.figure.key
        assert_nil exercises.second.figure
      end

      test "an unknown lesson gives nil, a lesson without exercise an empty key" do
        assert_nil call("inconnue")
        empty = create_course(status: "draft")

        assert_equal [], call(empty.slug).exercises
      end
    end
  end
end
