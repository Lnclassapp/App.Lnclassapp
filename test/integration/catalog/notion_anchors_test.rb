require "test_helper"

# ADR-0113 §4, UDR-0139 §3.7: every link and every 301 aims at « notion-<slug> », so each published notion of the lesson has
# its anchor in the page, once, whether or not it has an exercise.
class Catalog::NotionAnchorsTest < ActionDispatch::IntegrationTest
  setup do
    @course = create_course(name: "Propriétés de Thalès")
    @with = create_essential(course: @course, name: "Énoncé")
    create_exercise(essential: @with, questions: 1)
    @without = create_essential(course: @course, name: "Réciproque")
    @draft = create_essential(course: @course, name: "Brouillon", status: "draft")
    @student = create_student_for(@course)
  end

  test "a published notion with no exercise has its anchor, visible, once; so has one with an exercise" do
    sign_in_as @student

    get course_path(@course.slug)

    [ @with, @without ].each { |notion| assert_select "##{"notion-#{notion.slug}"}", 1 }
    assert_select "#notion-#{@without.slug}", text: /Réciproque/
    assert_select "#notion-#{@without.slug}[hidden]", 0
  end

  test "the anchor is the sheet of the notion, once, whatever its number of exercises" do
    create_exercise(essential: @with, questions: 1, title: "Second exercice")
    sign_in_as @student

    get course_path(@course.slug)

    # UDR-0148 §3 : une feuille par notion, son repère est l'ancre de la notion.
    assert_select "#notion-#{@with.slug}", 1
    assert_select ".ps-sheet#notion-#{@with.slug} .ps-exercise", 2
  end

  test "the anchor of a notion with no exercise is there even when the lesson has no exercise at all" do
    Orm::Exercise.where(essential_id: @with.id).update_all(status: "draft")
    sign_in_as @student

    get course_path(@course.slug)

    assert_select "#notion-#{@with.slug}", 1
    assert_select "#notion-#{@without.slug}", 1
  end

  test "a draft notion has no anchor for the student, and has one for the team" do
    sign_in_as @student
    get course_path(@course.slug)
    assert_select "#notion-#{@draft.slug}", 0
    sign_out

    sign_in_as create_team_member
    get course_path(@course.slug)
    assert_select "#notion-#{@draft.slug}", 1
  end

  test "every notion link of the student catalog aims at an id present in the lesson page" do
    sign_in_as @student

    get courses_path
    anchors = css_select("a[href^='/courses/'][href*='#notion-']").map { it["href"].split("#").last }
    get course_path(@course.slug)

    assert_includes anchors, "notion-#{@without.slug}"
    anchors.each { assert_select "##{it}", 1 }
  end
end
