require "test_helper"

module Queries
  module Catalog
    # CA-11, AS-37: an essential sheet, its course and its exercises. A student only gets the published exercises, each
    # with its progress and whether it is assigned to the student's classroom, then the sheet's pending knowledge gap.
    # The team gets every exercise, drafts and archives included. The old page never showed the badge.
    class EssentialDetailQueryTest < ActiveSupport::TestCase
      setup do
        @course = create_course(name: "Génétique et évolution", level: create_level(name: "Tle"), series: create_series(name: "D"),
                                material: create_material(name: "SVT", category: "science"))
        @essential = create_essential(course: @course, name: "La méiose", subtitle: "Deux divisions",
                                      content: "<p>Le <strong>brassage</strong> génétique.</p>")
        @classroom = create_classroom
        @student = create_student(classroom: @classroom)
      end

      def detail(student_id: nil, include_unpublished: false, course_slug: @course.slug, slug: @essential.slug)
        EssentialDetailQuery.new.call(course_slug:, slug:, student_id:, include_unpublished:)
      end

      def titles(row) = row.exercises.map(&:title)

      test "the sheet, its rich content and its course, with their statuses" do
        row = detail

        assert_equal [ @essential.slug, "La méiose", "Deux divisions", "published" ],
                     row.essential.to_h.values_at(:slug, :name, :subtitle, :status)
        assert_kind_of ActionText::Content, row.essential.content
        assert_includes row.essential.content.to_html, "<strong>brassage</strong>"
        assert_equal [ @course.slug, "Génétique et évolution", "published", "Tle", "D", "SVT", "science" ],
                     row.course.to_h.values_at(:slug, :name, :status, :level_name, :series_name, :material_name, :material_category)
      end

      test "a sheet without content or series still reads" do
        essential = create_essential(course: create_course(series: nil), content: nil, status: "draft")

        row = detail(course_slug: essential.course.slug, slug: essential.slug)

        assert_nil row.essential.content
        assert_nil row.course.series_name
        assert_equal "draft", row.essential.status
      end

      test "unknown sheet, or a sheet read under another course: nil" do
        assert_nil detail(slug: "inconnue")
        assert_nil detail(course_slug: create_course.slug)
      end

      test "AS-37: without include_unpublished, only the published exercises, in their order" do
        create_exercise(essential: @essential, title: "Deuxième", position: 2)
        create_exercise(essential: @essential, title: "Premier", position: 1)
        create_exercise(essential: @essential, title: "Brouillon", status: "draft", position: 3)
        create_exercise(essential: @essential, title: "Archivé", status: "archived", position: 4)
        create_exercise(title: "Autre fiche")

        assert_equal %w[Premier Deuxième], titles(detail(student_id: @student.id))
        assert_equal %w[Premier Deuxième], titles(detail)
      end

      test "the team reads every exercise, with its status" do
        create_exercise(essential: @essential, title: "Publié", position: 1)
        create_exercise(essential: @essential, title: "Brouillon", status: "draft", position: 2)
        create_exercise(essential: @essential, title: "Archivé", status: "archived", position: 3)

        row = detail(include_unpublished: true)

        assert_equal %w[Publié Brouillon Archivé], titles(row)
        assert_equal %w[published draft archived], row.exercises.map(&:status)
      end

      test "each exercise carries its identity, type, description and question count" do
        exercise = create_exercise(essential: @essential, title: "Méiose", description: "Deux divisions.", exercise_type: "evaluation",
                                   questions: 3)
        create_exercise(essential: @essential, title: "Vide", questions: 0)

        first, empty = detail.exercises

        assert_equal [ exercise.public_id, "Méiose", "Deux divisions.", "evaluation", 3 ],
                     first.to_h.values_at(:public_id, :title, :description, :exercise_type, :questions_count)
        assert_equal 0, empty.questions_count
      end

      test "without a student, no progress, no assignment, no gap" do
        exercise = create_exercise(essential: @essential)
        create_assignment(classroom: @classroom, assignable: exercise)

        row = detail

        assert_equal [ false, nil, nil, nil ],
                     row.exercises.first.to_h.values_at(:assigned_to_my_classroom, :badge_level, :best_score_percent,
                                                        :started_session_public_id)
        assert_nil row.pending_gap
      end

      test "the student's badge, best completed score and session in progress, exercise by exercise" do
        done = create_exercise(essential: @essential, title: "Fait", position: 1)
        doing = create_exercise(essential: @essential, title: "En cours", position: 2)
        create_exercise(essential: @essential, title: "Neuf", position: 3)
        best = create_exercise_session(student: @student, exercise: done, status: "completed", score_percent: 85)
        create_exercise_session(student: @student, exercise: done, status: "completed", score_percent: 40)
        create_exercise_session(student: @student, exercise: done, status: "abandoned")
        create_badge(student: @student, exercise: done, level: "gold", session: best)
        started = create_exercise_session(student: @student, exercise: doing)
        other = create_student(classroom: @classroom)
        create_exercise_session(student: other, exercise: doing, status: "completed", score_percent: 100)
        create_badge(student: other, exercise: doing, level: "diamond")

        facts = detail(student_id: @student.id).exercises.map do |exercise|
          exercise.to_h.values_at(:badge_level, :best_score_percent, :started_session_public_id)
        end

        assert_equal [ [ :gold, 85, nil ], [ nil, nil, started.public_id ], [ nil, nil, nil ] ], facts
      end

      # ADR-0072 §4.1, UDR-0015 (amendée le 2026-10-02) : « par sa fiche ou par son cours » disparaît.
      test "assigned to my classroom: directly and by an active assignment only, never through another exercise" do
        direct = create_exercise(essential: @essential, title: "Direct", position: 1)
        archived = create_exercise(essential: @essential, title: "Archivée", position: 2)
        elsewhere = create_exercise(essential: @essential, title: "Autre classe", position: 3)
        create_exercise(essential: @essential, title: "Libre", position: 4)
        create_assignment(classroom: @classroom, assignable: direct)
        create_assignment(classroom: @classroom, assignable: archived, status: "archived")
        create_assignment(classroom: create_classroom, assignable: elsewhere)
        # Un exercice d'une autre fiche du même cours, assigné à la classe, n'étiquette pas ceux-ci.
        create_assignment(classroom: @classroom, assignable: create_exercise(essential: create_essential(course: @course)))

        assigned = ->(row) { row.exercises.to_h { [ it.title, it.assigned_to_my_classroom ] } }

        assert_equal({ "Direct" => true, "Archivée" => false, "Autre classe" => false, "Libre" => false },
                     assigned.call(detail(student_id: @student.id)))
      end

      test "only the student's active primary classroom counts" do
        exercise = create_exercise(essential: @essential)
        secondary = create_classroom
        Orm::ClassroomStudent.create!(classroom: secondary, student: @student, primary: false, joined_at: Time.current)
        create_assignment(classroom: secondary, assignable: exercise)
        left = create_student(classroom: @classroom)
        Orm::ClassroomStudent.where(student: left).update_all(left_at: Time.current)
        create_assignment(classroom: @classroom, assignable: exercise)

        refute detail(student_id: left.id).exercises.first.assigned_to_my_classroom
        assert detail(student_id: @student.id).exercises.first.assigned_to_my_classroom

        @classroom.update!(status: "archived", archived_at: Time.current)
        refute detail(student_id: @student.id).exercises.first.assigned_to_my_classroom
      end

      test "the student's pending gap on this sheet, and only that one" do
        assert_nil detail(student_id: @student.id).pending_gap

        create_gap(student: @student, essential: @essential, status: "self_corrected")
        create_gap(student: @student, essential: create_essential(course: @course))
        create_gap(essential: @essential)
        assert_nil detail(student_id: @student.id).pending_gap

        gap = create_gap(student: @student, essential: @essential)
        pending = detail(student_id: @student.id).pending_gap

        assert_equal gap.public_id, pending.public_id
        assert_equal gap.created_at.to_i, pending.opened_at.to_i
      end
    end
  end
end
