require "test_helper"

# GD-04, GD-07 (ADR-0071 §4.2, UDR-0056 §3.2): the direction changes its own school's sign-up link from « Établissement »;
# the new link replaces the block without a reload, the old one stops opening the sign-up, the teachers stay. The school
# is always the account's: no parameter names it. An inactive school, and every other role, are refused.
class SchoolAdmin::SchoolLinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké", school_code: "k7m4qz")
    @teacher = create_teacher(school: @school)
    @admin = create_school_admin(school: @school)
  end

  def t(key, **) = I18n.t("school_admin.school_links.update.#{key}", **)
  def refusal(code) = I18n.t("school_admin.shared.errors.#{code}")
  def new_code = @school.reload.school_code

  test "GD-04: the direction changes the link: the block is replaced with the new one, a toast gives the new code" do
    sign_in_as @admin

    patch school_admin_school_link_path, as: :turbo_stream

    assert_response :success
    assert Entities::School::SchoolCode.valid?(new_code)
    assert_not_equal "k7m4qz", new_code
    display = Entities::School::SchoolCode.display(new_code)
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(t('done', code: display))}/
    assert_select "turbo-stream[action=replace][target=school_link_block] template #school_link_block" do
      assert_select "a#school_link_value[href='#{school_code_signup_url(new_code)}']", text: school_code_signup_url(new_code)
      assert_select "#school_code_value", text: display
      assert_select "dialog#change-school-link form#change-school-link-form[action='#{school_admin_school_link_path}']"
    end
    assert_equal [ @school.id ], Orm::TeacherSchool.where(teacher: @teacher).pluck(:school_id)
    assert_not_nil @school.reload.school_code_rotated_at
    event = Orm::AuditEvent.find_by!(action: "school.changed", subject_id: @school.id)
    assert_equal @admin.id, event.actor_id
    assert_equal "code_regenerated", event.metadata["change"]
  end

  test "GD-04: the old link no longer opens the sign-up, the new one does" do
    sign_in_as @admin
    patch school_admin_school_link_path, as: :turbo_stream
    sign_out

    get school_code_signup_path("k7m4qz")
    assert_response :not_found
    assert_select "body", text: /#{Regexp.escape(I18n.t('identity.teacher_registrations.new.invalid_code.title'))}/

    get school_code_signup_path(new_code)
    assert_response :success
  end

  test "without JavaScript, the change comes back to « Établissement » with a notice" do
    sign_in_as @admin

    patch school_admin_school_link_path

    assert_redirected_to school_admin_school_path
    assert_response :see_other
    assert_equal t("done", code: Entities::School::SchoolCode.display(new_code)), flash[:notice]
  end

  test "the school is the account's: a forged school parameter changes nothing elsewhere" do
    other = create_school(name: "Lycée Classique d'Abidjan", school_code: "abc234")
    sign_in_as @admin

    patch school_admin_school_link_path, params: { school_public_id: other.public_id, public_id: other.public_id },
                                         as: :turbo_stream

    assert_response :success
    assert_equal "abc234", other.reload.school_code
    assert_not_equal "k7m4qz", new_code
  end

  test "the « Établissement » page offers « Changer le lien » behind a confirmation on an active school" do
    sign_in_as @admin

    get school_admin_school_path

    assert_select "#school_link_block button[aria-controls=change-school-link]",
                  text: I18n.t("school_admin.schools.link.change.trigger")
    assert_select "#school_link_block dialog#change-school-link" do
      assert_select "h2", text: I18n.t("school_admin.schools.link.change.title")
      assert_select "form#change-school-link-form[action='#{school_admin_school_link_path}'] input[name=_method][value=patch]"
      assert_select "p", text: I18n.t("school_admin.schools.link.change.warning")
      assert_select "button[form=change-school-link-form][type=submit]", text: I18n.t("school_admin.schools.link.change.confirm")
      assert_select "button[data-action='modal#close']", text: I18n.t("school_admin.schools.link.change.cancel")
    end
  end

  test "GD-07: an inactive school shows its link without « Changer le lien », and a forged change answers 403" do
    @school.update!(status: "inactive")
    sign_in_as @admin

    get school_admin_school_path

    assert_select "a#school_link_value[href='#{school_code_signup_url('k7m4qz')}']"
    assert_select "#school_link_block dialog", 0
    assert_select "#school_link_block button[aria-controls=change-school-link]", 0

    patch school_admin_school_link_path, as: :turbo_stream

    assert_response :forbidden
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(refusal(:forbidden))}/
    assert_select "turbo-stream[action=replace][target=school_link_block] template #school_link_block dialog", 0
    assert_equal "k7m4qz", new_code
    assert_not Orm::AuditEvent.exists?(action: "school.changed", subject_id: @school.id)
  end

  test "GD-07: without JavaScript, the forged change on an inactive school answers the 403 page" do
    @school.update!(status: "inactive")
    sign_in_as @admin

    patch school_admin_school_link_path

    assert_response :forbidden
    assert_equal "k7m4qz", new_code
  end

  test "no free code after five draws: the block stays, a toast says to try again (422); without JavaScript, a notice" do
    taken = create_school(school_code: "abc234").school_code
    sign_in_as @admin
    generate = Entities::School::SchoolCode.method(:generate)
    Entities::School::SchoolCode.define_singleton_method(:generate) { |**| taken }

    patch school_admin_school_link_path, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(t('conflict'))}/
    assert_select "turbo-stream[action=replace][target=school_link_block] template #school_code_value", text: "K7M-4QZ"
    assert_equal "k7m4qz", new_code

    patch school_admin_school_link_path

    assert_redirected_to school_admin_school_path
    assert_equal t("conflict"), flash[:alert]
  ensure
    Entities::School::SchoolCode.define_singleton_method(:generate, generate)
  end

  test "a student, a teacher, a team member and a detached direction receive 403; a visitor signs in" do
    patch school_admin_school_link_path
    assert_redirected_to new_session_path

    [ create_student, @teacher, create_team_member, create_user(role: "school_admin") ].each do |user|
      sign_in_as user
      patch school_admin_school_link_path, as: :turbo_stream
      assert_response :forbidden, user.role
      sign_out
    end
    assert_equal "k7m4qz", new_code
  end
end
