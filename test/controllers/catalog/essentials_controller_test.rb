require "test_helper"

# CA-12, ADR-0113 §4: a notion no longer has a page. Its old address answers 301 to the lesson, anchored on
# #notion-<slug>. The redirect reveals nothing: wherever the page answered 404 (unknown, draft, other level, other
# lesson), it still does.
class Catalog::EssentialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @course = create_course(name: "Génétique et évolution")
    @essential = create_essential(course: @course, name: "La méiose")
    @student = create_student_for(@course)
  end

  def old_path(essential = @essential, course: @course) = course_essential_path(course.slug, essential.slug)

  test "the student is redirected (301) to the lesson, on the anchor of the notion" do
    sign_in_as @student

    get old_path

    assert_redirected_to course_path(@course.slug, anchor: "notion-#{@essential.slug}")
    assert_response :moved_permanently
  end

  test "a teacher and the team are redirected the same way, the team even for a draft notion" do
    draft = create_essential(course: @course, name: "Brouillon", status: "draft")

    sign_in_as create_teacher
    get old_path
    assert_redirected_to course_path(@course.slug, anchor: "notion-#{@essential.slug}")
    assert_response :moved_permanently

    sign_in_as create_team_member
    get old_path(draft)
    assert_redirected_to course_path(@course.slug, anchor: "notion-#{draft.slug}")
    assert_response :moved_permanently
  end

  test "an anonymous visitor is sent to the sign-in, not to the lesson" do
    get old_path

    assert_response :redirect
    assert_no_match(/#notion-/, response.location)
  end

  test "a draft notion, an unknown notion, a notion of another lesson: 404, never a redirect" do
    draft = create_essential(course: @course, name: "Brouillon", status: "draft")
    other = create_course(name: "Autre leçon", level: @course.level, series: @course.series, material: @course.material)
    sign_in_as @student

    get old_path(draft)
    assert_response :not_found
    get course_essential_path(@course.slug, "inconnue")
    assert_response :not_found
    get old_path(@essential, course: other)
    assert_response :not_found
    get course_essential_path("lecon-inconnue", @essential.slug)
    assert_response :not_found
  end

  test "a notion of a draft lesson answers 404 to the student" do
    draft_course = create_course(name: "Leçon brouillon", status: "draft", level: @course.level, series: @course.series,
                                 material: @course.material)
    essential = create_essential(course: draft_course, name: "Cachée")
    sign_in_as @student

    get old_path(essential, course: draft_course)

    assert_response :not_found
  end

  test "a notion of another level answers 404 to the student" do
    other_level = create_course(name: "Autre niveau", level: create_level(name: "6ème"), material: @course.material)
    essential = create_essential(course: other_level, name: "Ailleurs")
    sign_in_as @student

    get old_path(essential, course: other_level)

    assert_response :not_found
  end
end
