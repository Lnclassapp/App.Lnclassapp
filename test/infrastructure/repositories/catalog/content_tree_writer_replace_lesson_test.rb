require "test_helper"

module Repositories
  module Catalog
    # ADR-0123 : sur Develop, une leçon v1 présente (publiée ou non) est remplacée entière par la leçon v3 du même titre.
    class ContentTreeWriterReplaceLessonTest < ActiveSupport::TestCase
      Port = Ports::Catalog::ContentTreeWriterPort

      setup do
        @writer = ContentTreeWriter.new
        @author = create_team_member(team_role: "content", second_factor: false)
        @level = create_level
        @material = create_material
        @course = create_course(level: @level, material: @material, name: "Les suites", author: @author, status: "published", subtitle: "v1",
                                content: "<p>Cours v1</p>")
        @notion = create_essential(course: @course, name: "Fiche v1", position: 1)
        @exercise = create_exercise(essential: @notion)
        @problem = create_lesson_wide_exercise(course: @course)
      end

      def answers = [ Port::AnswerNode.new(position: 1, content: "Vrai", correct: true), Port::AnswerNode.new(position: 2, content: "Faux", correct: false) ]

      def exercise(title)
        question = Port::QuestionNode.new(position: 1, content: "#{title} Q1", explanation: nil, question_type: "true_false", answers:)
        Port::ExerciseNode.new(public_id: SecureRandom.base58(14), essential_id: nil, title:, statement: "Énoncé", exercise_type: "fixation",
                               position: nil, questions: [ question ])
      end

      def tree
        notions = [ 1, 2 ].map do |rank|
          Port::NotionNode.new(slug: "les-suites-notion-#{rank}", course_id: nil, name: "Notion #{rank}", position: rank, sheet: { "remember" => "v3" },
                               exercises: [ exercise("N#{rank}") ])
        end
        Port::CourseNode.new(slug: nil, name: "Les  suites", subtitle: "v3", content: nil, level_id: @level.id, series_id: nil, material_id: @material.id,
                             essentials: [], exercises: [ exercise("P1") ], existing_id: @course.id, sheet_theme: "teal", notions:, subjects: [],
                             figures: [ { "key" => "f", "kind" => "geometry", "description" => "d", "params" => {}, "controls" => [] } ])
      end

      test "replaces a published v1 lesson whole: its text, sheets, exercises and the students' results go, the v3 tree comes in draft" do
        student = create_student
        session = create_exercise_session(student:, exercise: @exercise, status: "completed")
        create_attempt(session:, question: @exercise.questions.first)
        create_essential_read(student:, essential: @notion)
        create_gap(student:, essential: @notion, source_session: session)
        create_assignment(assignable: @problem)

        counts = @writer.replace_lesson(course_id: @course.id, tree:)

        assert_equal({ courses: 1, essentials: 2, exercises: 3, questions: 3, answers: 6, subjects: 0 }, counts)
        course = Orm::Course.find(@course.id)
        assert_equal [ "Les  suites", "v3", "teal", [ "f" ], @course.slug, "published" ],
                     [ course.name, course.subtitle, course.sheet_theme, course.figures.map { it["key"] }, course.slug, course.status ]
        assert_equal [ "Notion 1", "Notion 2" ], course.essentials.order(:position).pluck(:name)
        assert_equal [ "draft" ], course.essentials.distinct.pluck(:status)
        assert_equal [ "draft" ], Orm::Exercise.where(course_id: course.id).distinct.pluck(:status)
        assert_not Orm::Essential.exists?(@notion.id)
        assert_equal [ 0, 0, 0, 0, 0 ], [ Orm::ExerciseSession, Orm::QuestionAttempt, Orm::EssentialRead, Orm::KnowledgeGap, Orm::ClassroomAssignment ].map(&:count)
        assert_not Orm::RichTextRow.exists?(record_type: "Orm::Course", record_id: course.id, name: "content")
      end

      test "a draft lesson is replaced the same way" do
        @course.update_columns(status: "draft", published_at: nil)

        assert_equal 2, @writer.replace_lesson(course_id: @course.id, tree:).fetch(:essentials)
        assert_equal "draft", @course.reload.status
      end

      test "replace_draft still refuses a published lesson" do
        assert_raises(ContentTreeWriter::NotDraft) { @writer.replace_draft(course_id: @course.id, tree:) }
        assert Orm::Essential.exists?(@notion.id)
      end
    end
  end
end
