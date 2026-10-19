require "test_helper"

# ED-04, ED-21 to ED-24 (ADR-0092 §4.3, UDR-0092 §3.2, §3.4): on the page of a school, the team reads each direction's
# position and changes it from the ⋮ menu of its line, in a modal; the line is replaced without reloading the page. One
# active head per school. A content member gets 403; a direction of another school is not found; a direction never
# changes a position, its own included.
class Teams::SchoolStaffPositionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké", school_type: "public")
    @field = create_team_member(team_role: "field")
    @kone = create_school_admin(school: @school, first_name: "Awa", last_name: "Koné", position: "secretary")
    @yao = create_school_admin(school: @school, first_name: "Kofi", last_name: "Yao", position: "head")
  end

  def te(key, **) = I18n.t("teams.school_staff_positions.edit.#{key}", **)
  def label(key) = I18n.t("shared.staff_positions.#{key}")
  def position_of(user) = Orm::SchoolStaff.find_by!(user_id: user.id).position
  def change(user, position, school: @school, **)
    patch school_staff_member_position_path(school.public_id, user.public_id), params: { staff_position: { position: } }, **
  end

  test "ED-04: the team reads each position on the school page, and « Changer la fonction » first in each menu" do
    deputy = create_school_admin(school: @school, first_name: "Aya", last_name: "Diallo", position: "deputy")
    sign_in_as @field

    get school_path(@school.public_id)

    assert_select "li#school_staff_#{@kone.public_id}", text: /#{label("secretary")}/
    assert_select "li#school_staff_#{@yao.public_id}", text: /#{Regexp.escape(label("head"))}/
    assert_select "li#school_staff_#{deputy.public_id}", text: /#{Regexp.escape(label("deputy_public"))}/
    assert_select "li#school_staff_#{@kone.public_id} [role=menu] a[role=menuitem]:first-child" \
                  "[href='#{edit_school_staff_member_position_path(@school.public_id, @kone.public_id)}'][data-turbo-frame=modal]",
                  text: I18n.t("shared.school_staff.change_position")
  end

  test "ED-03: in a private school, the deputy reads « Directeur des études »" do
    school = create_school(school_type: "private")
    deputy = create_school_admin(school:, position: "deputy")
    sign_in_as @field

    get school_path(school.public_id)

    assert_select "li#school_staff_#{deputy.public_id}", text: /#{label("deputy_private")}/
  end

  test "the modal opens in the frame, the current position checked; without frame, a full page with the way back" do
    sign_in_as @field

    get edit_school_staff_member_position_path(@school.public_id, @kone.public_id), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal dialog#staff-position-modal h2", te("title", name: "Awa Koné")
    assert_select "form#staff-position-form[action='#{school_staff_member_position_path(@school.public_id, @kone.public_id)}']" do
      assert_select "input[name=_method][value=patch]"
      assert_select "input[type=radio][name='staff_position[position]']", 4
      assert_select "input[type=radio][value=secretary][checked]"
    end
    assert_select "#back-to-school", 0

    get edit_school_staff_member_position_path(@school.public_id, @kone.public_id)
    assert_select "#back-to-school[href='#{school_path(@school.public_id)}']"
  end

  test "ED-23: secretary becomes educator; the line is replaced with its new position, the toast, the journal" do
    sign_in_as @field

    change @kone, "educator", as: :turbo_stream

    assert_response :success
    assert_equal "educator", position_of(@kone)
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(I18n.t("teams.school_staff_positions.update.done", name: "Awa Koné"))}/
    assert_select "turbo-stream[action=replace][target=school_staff_#{@kone.public_id}] template li", text: /#{label("educator")}/
    event = Orm::AuditEvent.find_by!(action: "school_staff.position_set")
    assert_equal [ @field.id, @kone.id, { "school_id" => @school.id, "from" => "secretary", "to" => "educator" } ],
                 [ event.actor_id, event.subject_id, event.metadata ]
  end

  test "without Turbo, the change goes back to the school page with the notice" do
    sign_in_as @field

    change @kone, "educator"

    assert_redirected_to school_path(@school.public_id)
    assert_equal "educator", position_of(@kone)
  end

  test "ED-24: another head while the head is active: 422 in the modal, nothing changed" do
    sign_in_as @field

    change @kone, "head", headers: { "Turbo-Frame" => "modal" }

    assert_response :unprocessable_entity
    assert_select "#staff_position_position_error", "Cet établissement a déjà un chef d'établissement actif."
    assert_equal "secretary", position_of(@kone)
    assert_not Orm::AuditEvent.exists?(action: "school_staff.position_set")
  end

  test "a blank position is said under the group in 422" do
    sign_in_as @field

    change @kone, "", headers: { "Turbo-Frame" => "modal" }

    assert_response :unprocessable_entity
    assert_select "#staff_position_position_error", "Choisissez une fonction."
  end

  test "a content member gets 403, menus without « Changer la fonction », for an unknown school too" do
    sign_in_as create_team_member(team_role: "content")

    get school_path(@school.public_id)
    assert_select "a[href='#{edit_school_staff_member_position_path(@school.public_id, @kone.public_id)}']", 0
    get edit_school_staff_member_position_path("inconnu", @kone.public_id)
    assert_response :forbidden
    change @kone, "educator", as: :turbo_stream
    assert_response :forbidden
    assert_equal "secretary", position_of(@kone)
  end

  test "a direction of another school, or archived, is not found" do
    other = create_school_admin(school: create_school, position: "secretary")
    gone = create_school_admin(school: @school, position: "educator", archived_at: 1.day.ago)
    sign_in_as @field

    change other, "educator", as: :turbo_stream
    assert_response :not_found
    get edit_school_staff_member_position_path(@school.public_id, gone.public_id)
    assert_response :not_found
    assert_equal "secretary", position_of(other)
  end

  test "ED-21, ED-22: a direction never changes a position, its own nor another's (403, the team space is closed to it)" do
    [ [ @kone, @kone, "head" ], [ @yao, @kone, "educator" ] ].each do |author, target, position|
      sign_in_as author
      change target, position, as: :turbo_stream

      assert_response :forbidden
      sign_out
    end
    assert_equal "secretary", position_of(@kone)
  end
end
