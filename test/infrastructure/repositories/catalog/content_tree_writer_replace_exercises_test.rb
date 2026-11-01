require "test_helper"

module Repositories
  module Catalog
    # Chargement automatique hors production : seuls les exercices, problèmes et sujets d'une leçon (publiée ou non) sont remplacés.
    class ContentTreeWriterReplaceExercisesTest < ActiveSupport::TestCase
      Port = Ports::Catalog::ContentTreeWriterPort

      setup do
        @writer = ContentTreeWriter.new
        @author = create_team_member(team_role: "content", second_factor: false)
        @level = create_level
        @material = create_material
        @at = Time.zone.parse("2026-09-25 10:00")
        @course = create_course(level: @level, material: @material, name: "Thalès", author: @author, status: "published",
                                figures: [ figure("fig", "ancienne"), figure("autre", "gardée") ], sheet_theme: "burgundy", subtitle: "Sous-titre")
        @notion = create_essential(course: @course, name: "Calculer une longueur", position: 1, sheet: { "remember" => "Texte d'avant" })
        @old_exercise = create_exercise(essential: @notion)
        @problem = create_lesson_wide_exercise(course: @course)
        @subject = create_subject(course: @course, title: "Ancien sujet")
        @subject_exercise = create_exercise(subject: @subject, course: @course)
      end

      def figure(key, description) = { "key" => key, "kind" => "geometry", "description" => description, "params" => {}, "controls" => [] }

      def answers = [ Port::AnswerNode.new(position: 1, content: "Vrai", correct: true), Port::AnswerNode.new(position: 2, content: "Faux", correct: false) ]

      def exercise(title, figure_key: nil)
        questions = [ 1, 2 ].map { |rank| Port::QuestionNode.new(position: rank, content: "#{title} Q#{rank}", explanation: nil, question_type: "true_false", answers:) }
        Port::ExerciseNode.new(public_id: SecureRandom.base58(14), essential_id: nil, title:, statement: "Sujet", exercise_type: "fixation",
                               position: nil, questions:, figure_key:)
      end

      def notion_node(name, exercises) = Port::NotionNode.new(slug: "ignore", course_id: nil, name:, position: 1, sheet: { "remember" => "Nouveau texte" }, exercises:)

      def tree(notions: nil, subjects: nil, figures: nil)
        notions ||= [ notion_node("  Calculer   une longueur ", [ exercise("Nouveau 1", figure_key: "fig"), exercise("Nouveau 2") ]) ]
        subjects ||= [ Port::SubjectNode.new(course_id: nil, position: nil, title: "Sujet A", notions: "Thalès", exercises: [ exercise("A1", figure_key: "neuve"), exercise("A2") ]) ]
        Port::CourseNode.new(slug: nil, name: "Autre nom", subtitle: "Autre", content: nil, level_id: @level.id, series_id: nil, material_id: @material.id,
                             essentials: [], exercises: [ exercise("P1"), exercise("P2") ], existing_id: @course.id, sheet_theme: "teal", notions:, subjects:,
                             figures: figures || [ figure("fig", "nouvelle"), figure("neuve", "ajoutée"), figure("inutile", "non citée") ])
      end

      test "replaces the exercises, problems and subjects of a published lesson, in draft, and leaves the course and its sheets alone" do
        student = create_student
        session = create_exercise_session(student:, exercise: @old_exercise, status: "completed")
        create_attempt(session:, question: @old_exercise.questions.first)
        create_badge(student:, exercise: @old_exercise, session:)
        create_assignment(assignable: @subject_exercise)
        read = create_essential_read(student:, essential: @notion)
        own_gap = create_gap(student:, essential: @notion, source_session: session)
        create_exercise_session(student:, exercise: @problem, gap: own_gap)
        other_notion = create_essential(course: @course, name: "Autre notion", position: 2)
        unrelated_gap = create_gap(student:, essential: other_notion, source_session: create_exercise_session(student:, exercise: create_exercise))

        counts = @writer.replace_exercises(course_id: @course.id, tree: tree)

        assert_equal({ courses: 1, essentials: 0, exercises: 6, questions: 12, answers: 24, subjects: 1 }, counts)
        course = Orm::Course.find(@course.id)
        assert_equal [ "Thalès", "Sous-titre", "burgundy", "published" ], [ course.name, course.subtitle, course.sheet_theme, course.status ]
        assert_equal [ "Texte d'avant", "published" ], [ @notion.reload.sheet["remember"], @notion.status ]
        assert Orm::EssentialRead.exists?(read.id)
        assert Orm::KnowledgeGap.exists?(unrelated_gap.id)
        assert_not Orm::KnowledgeGap.exists?(own_gap.id)
        assert_equal [ 0, 0, 0 ], [ Orm::QuestionAttempt, Orm::ExerciseBadge, Orm::ClassroomAssignment ].map(&:count)
        assert_equal [ unrelated_gap.source_session_id ], Orm::ExerciseSession.pluck(:id)
        assert_equal [ "Sujet A" ], course.subjects.pluck(:title)
        assert_not Orm::Exercise.exists?(@old_exercise.id)
        written = Orm::Exercise.where(course_id: @course.id)
        assert_equal [ "draft" ] * 6, written.order(:position).pluck(:status)
        assert_equal [ "Nouveau 1", "Nouveau 2", "P1", "P2", "A1", "A2" ], written.order(:position).pluck(:title)
        assert_equal [ @notion.id, @notion.id, nil, nil, nil, nil ], written.order(:position).pluck(:essential_id)
        assert_equal [ nil, nil, nil, nil, course.subjects.first.id, course.subjects.first.id ], written.order(:position).pluck(:subject_id)
        assert_equal [ @author.id ], written.distinct.pluck(:author_id)
      end

      test "merges the figures the new exercises cite: replaced by key, added, and the others stay" do
        @writer.replace_exercises(course_id: @course.id, tree: tree)

        figures = Orm::Course.find(@course.id).figures
        assert_equal [ "fig", "autre", "neuve" ], figures.map { it["key"] }
        assert_equal [ "nouvelle", "gardée", "ajoutée" ], figures.map { it["description"] }
      end

      test "a draft lesson is replaced the same way" do
        @course.update_columns(status: "draft", published_at: nil)

        @writer.replace_exercises(course_id: @course.id, tree: tree(subjects: []))

        assert_equal "draft", @course.reload.status
        assert_equal [ 4, 0 ], [ Orm::Exercise.where(course_id: @course.id).count, @course.subjects.count ]
      end

      test "a notion of the tree missing from the lesson raises and deletes nothing" do
        missing = [ notion_node("Une autre notion", [ exercise("X") ]) ]

        assert_no_difference [ "Orm::Exercise.count", "Orm::Question.count", "Orm::Subject.count" ] do
          assert_raises(KeyError) { @writer.replace_exercises(course_id: @course.id, tree: tree(notions: missing)) }
        end
        assert Orm::Exercise.exists?(@old_exercise.id)
      end
    end
  end
end
