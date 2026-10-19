require "test_helper"

module Queries
  module Assessment
    # AS-17, ADR-0101 §4.4: the pending sheets of a classroom (summary) and, on one sheet, who is to review it and who
    # lifted it this school year (detail). Present students only (ADR-0079); published sheets of published courses; one
    # query per method whatever the number of students. Remediated and self-corrected are one group on screen.
    class ClassroomGapsQueryTest < ActiveSupport::TestCase
      setup do
        @level = create_level(name: "3ème")
        @maths = create_material(name: "Mathématiques")
        @course = create_course(level: @level, material: @maths, name: "Géométrie")
        @thales = create_essential(course: @course, name: "Théorème de Thalès")
        @source = create_exercise(essential: @thales, questions: 1)
        @classroom = create_classroom(level: @level, school_year: "2026-2027")
        @awa = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
        @bintou = create_student(classroom: @classroom, first_name: "Bintou", last_name: "Diallo")
        @yao = create_student(classroom: @classroom, first_name: "Yao", last_name: "Kouassi")
      end

      def gap(student, essential = @thales, status: "pending", **attributes)
        exercise = essential == @thales ? @source : create_exercise(essential:, questions: 1)
        source_session = create_exercise_session(student:, exercise:, status: "completed", score_percent: 30)
        create_gap(student:, essential:, status:, source_session:, **attributes)
      end

      def summary(course_slugs: [ @course.slug ], show_roster: true)
        ClassroomGapsQuery.new.summary(classroom_public_id: @classroom.public_id, course_slugs:, show_roster:)
      end

      def detail(essential = @thales, school_year: "2026-2027", show_roster: true)
        ClassroomGapsQuery.new.detail(classroom_public_id: @classroom.public_id, course_slug: essential.course.slug,
                                      essential_slug: essential.slug, school_year:, show_roster:)
      end

      def rows(summary) = summary.map { [ it.essential_name, it.pending_count ] }

      test "summary: one row per pending sheet, by number of students then name, with its slugs" do
        gap(@awa)
        gap(@bintou)
        gap(@yao, status: "remediated")
        pythagore = create_essential(course: @course, name: "Pythagore")
        angles = create_essential(course: @course, name: "Angles")
        [ @awa, @bintou ].each { gap(it, pythagore) }
        gap(@yao, angles)

        result = summary

        assert_equal [ [ "Pythagore", 2 ], [ "Théorème de Thalès", 2 ], [ "Angles", 1 ] ], rows(result)
        assert_equal [ @thales.slug, @course.slug ], result[1].to_h.values_at(:essential_slug, :course_slug)
      end

      test "summary: only the given courses, published sheets of published courses" do
        gap(@awa)
        physics = create_course(level: @level, name: "Optique")
        gap(@awa, create_essential(course: physics, name: "Lentilles"))
        gap(@awa, create_essential(course: @course, name: "Brouillon", status: "draft"))
        hidden = create_course(level: @level, name: "Caché")
        gap(@awa, create_essential(course: hidden, name: "Fiche d'un cours caché"))
        hidden.update!(status: "draft")

        assert_equal [ [ "Théorème de Thalès", 1 ] ], rows(summary)
        assert_equal [ "Lentilles", "Théorème de Thalès" ],
                     summary(course_slugs: [ @course.slug, physics.slug, hidden.slug ]).map(&:essential_name).sort
        assert_equal [], summary(course_slugs: [])
      end

      test "a student who left the classroom, or whose account is anonymized, is not counted nor named" do
        gap(@awa)
        gap(@bintou)
        gap(@yao, status: "remediated", resolved_at: Time.zone.local(2026, 10, 14, 9))
        Orm::ClassroomStudent.where(student: @bintou).update_all(left_at: Time.current)
        @yao.update_columns(anonymized_at: Time.current)
        gap(create_student(classroom: create_classroom(level: @level)))

        assert_equal [ [ "Théorème de Thalès", 1 ] ], rows(summary)
        assert_equal [ "Awa Bamba" ], detail.pending.map(&:display_name)
        assert_empty detail.lifted
      end

      test "detail: pending from the oldest, with its failures; lifted this school year from the latest, both statuses" do
        gap(@bintou, created_at: Time.zone.local(2026, 10, 13, 8))
        gap(@awa, created_at: Time.zone.local(2026, 10, 12, 8), failed_sessions_count: 3)
        gap(@yao, status: "self_corrected", resolved_at: Time.zone.local(2026, 10, 14, 9))
        late = create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao")
        gap(late, status: "remediated", resolved_at: Time.zone.local(2026, 10, 15, 9))
        gap(late, status: "remediated", resolved_at: Time.zone.local(2026, 6, 20, 9))
        gap(@awa, create_essential(course: @course))

        result = detail

        assert_equal [ [ "Awa Bamba", Date.new(2026, 10, 12), 3 ], [ "Bintou Diallo", Date.new(2026, 10, 13), 1 ] ],
                     result.pending.map { it.to_h.values_at(:display_name, :opened_on, :failed_sessions_count) }
        assert_equal [ [ "Koffi Yao", Date.new(2026, 10, 15) ], [ "Yao Kouassi", Date.new(2026, 10, 14) ] ],
                     result.lifted.map { it.to_h.values_at(:display_name, :resolved_on) }
      end

      test "detail: the school year bounds are those of the classroom, from September to August" do
        gap(@awa, status: "remediated", resolved_at: Time.zone.local(2026, 8, 31, 23))
        gap(@bintou, status: "remediated", resolved_at: Time.zone.local(2026, 9, 1, 0, 30))
        gap(@yao, status: "remediated", resolved_at: Time.zone.local(2027, 9, 1, 0, 30))

        assert_equal [ "Bintou Diallo" ], detail.lifted.map(&:display_name)
        assert_equal [ "Awa Bamba" ], detail(school_year: "2025-2026").lifted.map(&:display_name)
      end

      test "detail: an unknown sheet, or a sheet without gap, has two empty groups" do
        gap(@awa, create_essential(course: @course))

        assert_equal [ [], [] ], detail.to_h.values_at(:pending, :lifted)
      end

      test "without show_roster, nothing is read" do
        gap(@awa)

        assert_no_queries do
          assert_nil summary(show_roster: false)
          assert_nil detail(show_roster: false)
        end
      end

      test "one query per method, at 1 and at 30 students" do
        gap(@awa)
        gap(@yao, status: "remediated", resolved_at: Time.zone.local(2026, 10, 14, 9))
        assert_queries_count(1) { summary }
        assert_queries_count(1) { detail }

        27.times { gap(create_student(classroom: @classroom)) }
        assert_queries_count(1) { assert_equal 28, summary.first.pending_count }
        assert_queries_count(1) { assert_equal 28, detail.pending.size }
      end
    end
  end
end
