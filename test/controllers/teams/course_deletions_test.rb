require "test_helper"

# CA-01, CA-06, CA-07 (chantier suppression-lecon), UDR-0172 : l'entrée « Supprimer » du menu ⋮,
# la confirmation lue dans le frame « modal », son état de refus, la suppression qui renvoie au catalogue et son refus en 422.
class Teams::CourseDeletionsTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member
    @course = create_course(name: "Les suites", status: "published")
    @exercise = create_exercise(essential: create_essential(course: @course))
  end

  def tc(key, **) = I18n.t("teams.courses.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/

  test "CA-01 : a student, a teacher or a school direction gets 403 on the confirmation and the deletion; nothing is deleted" do
    [ create_student, create_teacher, create_school_admin ].each do |outsider|
      sign_in_as outsider

      get deletion_teams_course_path(@course.slug)
      assert_response :forbidden
      delete teams_course_path(@course.slug), as: :turbo_stream
      assert_response :forbidden
    end
    assert Orm::Course.exists?(@course.id)
  end

  test "the ⋮ menu of the lesson page offers « Supprimer » last, in the danger tone, opening the confirmation in the modal frame" do
    sign_in_as @member

    get course_path(@course.slug)

    assert_select "#course-actions-menu a[role=menuitem][data-turbo-frame=modal][href='#{deletion_teams_course_path(@course.slug)}']",
                  text: I18n.t("catalog.courses.role_actions.delete")
    assert_select "#course-actions-menu a[role=menuitem]:last-of-type[href='#{deletion_teams_course_path(@course.slug)}']"
  end

  test "CA-06 : without activity, the confirmation names the lesson, says it is final, and posts the deletion to the whole page" do
    sign_in_as @member

    get deletion_teams_course_path(@course.slug), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal" do
      assert_select "dialog", text: including(tc("deletion.title", name: "Les suites"))
      assert_select "p", text: including(tc("deletion.body"))
      assert_select "form[action='#{teams_course_path(@course.slug)}'][data-turbo-frame=_top] input[name=_method][value=delete]"
      assert_select "button[type=submit]", text: including(tc("deletion.confirm"))
    end
  end

  test "CA-06 : the deletion leads to the catalogue with its message; the lesson is gone and the audit trail has it" do
    sign_in_as @member

    delete teams_course_path(@course.slug), as: :turbo_stream

    assert_redirected_to courses_path
    assert_equal tc("destroy.deleted", name: "Les suites"), flash[:notice]
    assert_not Orm::Course.exists?(@course.id)
    assert_not Orm::Exercise.exists?(@exercise.id)
    assert_equal [ [ "content.deleted", @member.id, @course.id ] ], Orm::AuditEvent.where(action: "content.deleted").pluck(:action, :actor_id, :subject_id)
  end

  test "CA-07 : with student activity, the confirmation refuses and offers to edit the lesson, without any delete button" do
    create_essential_read(essential: @exercise.essential)
    sign_in_as @member

    get deletion_teams_course_path(@course.slug), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "dialog", text: including(tc("deletion.refused_title"))
    assert_select "p", text: including(tc("deletion.refused_body", name: "Les suites"))
    assert_select "a[href='#{edit_teams_course_path(@course.slug)}'][data-turbo-frame=modal]", text: including(tc("deletion.edit"))
    assert_select "form[action='#{teams_course_path(@course.slug)}']", 0
  end

  test "CA-07 : a deletion sent anyway is refused in 422: toast, modal turned into the refusal; nothing is deleted" do
    create_exercise_session(exercise: @exercise)
    sign_in_as @member

    delete teams_course_path(@course.slug), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("destroy.refused", name: "Les suites"))
    assert_select "turbo-stream[action=update][target=modal]" do
      assert_select "a[href='#{edit_teams_course_path(@course.slug)}']", text: including(tc("deletion.edit"))
    end
    assert Orm::Course.exists?(@course.id)
    assert_equal 0, Orm::AuditEvent.where(action: "content.deleted").count
  end

  test "without Turbo, a refusal leads back to the lesson page; the confirmation is a full page with its way back" do
    create_exercise_session(exercise: @exercise)
    sign_in_as @member

    get deletion_teams_course_path(@course.slug)
    assert_select "a#back-to-course[href='#{course_path(@course.slug)}']"

    delete teams_course_path(@course.slug)
    assert_redirected_to course_path(@course.slug)
    assert_equal tc("destroy.refused", name: "Les suites"), flash[:alert]
  end

  test "a lesson refused, then deleted by another member before it is read again, is not found rather than an error" do
    refused = Shared::Result.failure(:conflict, errors: { base: [ :student_activity ] })
    slug = @course.slug
    sign_in_as @member
    Orm::Course.transaction { Repositories::Catalog::CourseRepository.new.delete(id: @course.id) }

    stub_any_instance(UseCases::Catalog::DeleteCourse, :call, ->(**) { refused }) do
      delete teams_course_path(slug), as: :turbo_stream
    end

    assert_response :not_found
  end

  test "an unknown lesson is not found, for the confirmation and for the deletion" do
    sign_in_as @member

    get deletion_teams_course_path("inconnue")
    assert_response :not_found
    delete teams_course_path("inconnue")
    assert_response :not_found
  end
end
