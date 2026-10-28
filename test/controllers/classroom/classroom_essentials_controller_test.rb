require "test_helper"

# CA-12, ADR-0113 §4: the notion has no page in the classroom either. Its old address answers 301 to the lesson seen from
# the classroom, anchored on the notion. The redirect gives nothing away: the access rules of the old page still apply.
class Classroom::ClassroomEssentialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @level = create_level
    @material = create_material
    @classroom = create_classroom(name: "Tle D 1", school: create_school(name: "Lycée Classique"), level: @level)
    @teacher = create_teacher(classrooms: [ @classroom ], material: @material)
    @course = create_course(name: "Génétique et évolution", level: @level, material: @material)
    @essential = create_essential(course: @course, name: "La méiose", subtitle: "Deux divisions")
  end

  def page_path(classroom = @classroom, essential = @essential)
    classroom_essential_path(classroom.public_id, @course.slug, essential.slug)
  end

  test "the teacher is redirected (301) to the lesson in the classroom, on the anchor of the notion" do
    sign_in_as @teacher

    get page_path

    assert_redirected_to classroom_course_path(@classroom.public_id, @course.slug, anchor: "notion-#{@essential.slug}")
    assert_response :moved_permanently
  end

  test "the team is redirected the same way" do
    sign_in_as create_team_member

    get page_path

    assert_redirected_to classroom_course_path(@classroom.public_id, @course.slug, anchor: "notion-#{@essential.slug}")
    assert_response :moved_permanently
  end

  test "an archived classroom: 404 for its teacher, not a redirect" do
    archived = create_classroom(status: "archived")
    teacher = create_teacher(classrooms: [ archived ])
    sign_in_as teacher

    get page_path(archived)

    assert_response :not_found
  end

  test "another teacher or a student of the classroom receives 403, not a redirect" do
    [ create_teacher, create_student(classroom: @classroom) ].each do |user|
      sign_in_as user

      get page_path

      assert_response :forbidden
      assert_nil response.location
      sign_out
    end
  end

  test "an unknown classroom, an unknown, draft or foreign-lesson notion, a draft lesson: 404, never a redirect" do
    draft = create_essential(course: @course, status: "draft")
    other = create_course(name: "Autre", level: @level, material: @material)
    draft_course = create_course(name: "Brouillon", status: "draft", level: @level, material: @material)
    hidden = create_essential(course: draft_course, name: "Cachée")
    sign_in_as @teacher

    get classroom_essential_path("inconnue", @course.slug, @essential.slug)
    assert_response :not_found
    [ "inconnue", draft.slug ].each do |slug|
      get classroom_essential_path(@classroom.public_id, @course.slug, slug)
      assert_response :not_found
    end
    get classroom_essential_path(@classroom.public_id, other.slug, @essential.slug)
    assert_response :not_found
    get classroom_essential_path(@classroom.public_id, draft_course.slug, hidden.slug)
    assert_response :not_found
  end
end
