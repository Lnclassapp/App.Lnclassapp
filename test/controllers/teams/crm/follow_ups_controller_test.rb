require "test_helper"

# CA-13, CA-14 (ADR-XXXX contexte crm, UDR-XXXX pipeline et relances, bloc « Suivi »): create, list, complete and reassign
# follow-ups; admin and field only (403 for content), reassign for an admin or the owner of the school.
class Teams::Crm::FollowUpsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Classique")
    @field = create_team_member(team_role: "field")
    @admin = create_team_member(team_role: "admin")
    @content = create_team_member(team_role: "content")
    @tomorrow = Date.current + 1
  end

  def follow_up(assignee: @field, school: @school, due_on: @tomorrow, reason: "Rappeler la direction")
    Orm::CrmFollowUp.create!(school:, assignee:, due_on:, reason:, created_by: @field)
  end

  # What Turbo sends with a form: the stream first, the page as fallback.
  def turbo = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }

  test "CA-01: content gets 403 on every follow-up address" do
    record = follow_up
    sign_in_as @content
    school = @school.public_id

    get teams_school_open_follow_ups_path(school)
    assert_response :forbidden
    get new_teams_school_follow_up_path(school)
    assert_response :forbidden
    post teams_school_follow_ups_path(school), params: { follow_up: { reason: "x", due_on: @tomorrow.iso8601 } }
    assert_response :forbidden
    get teams_follow_ups_path
    assert_response :forbidden
    patch teams_follow_up_completion_path(record.public_id)
    assert_response :forbidden
    get edit_teams_follow_up_assignee_path(record.public_id)
    assert_response :forbidden
    patch teams_follow_up_assignee_path(record.public_id), params: { follow_up: { assignee_public_id: @admin.public_id } }
    assert_response :forbidden
    assert_equal "open", record.reload.status
    assert_equal @field.id, record.assignee_id
  end

  test "the school frame lists its open follow-ups, and says when there is none" do
    sign_in_as @field
    get teams_school_open_follow_ups_path(@school.public_id), headers: { "Turbo-Frame" => "school_crm_follow_ups" }
    assert_select "turbo-frame#school_crm_follow_ups" do
      assert_select "li", count: 0
      assert_select "a[href=?]", new_teams_school_follow_up_path(@school.public_id)
    end

    follow_up
    follow_up(school: create_school, reason: "Autre école")
    get teams_school_open_follow_ups_path(@school.public_id), headers: { "Turbo-Frame" => "school_crm_follow_ups" }

    assert_select "turbo-frame#school_crm_follow_ups li", count: 1, text: /Rappeler la direction/
    assert_select "turbo-frame#school_crm_follow_ups form[action=?]", teams_follow_up_completion_path(Orm::CrmFollowUp.find_by(school: @school).public_id)
  end

  test "an unknown school is 404" do
    sign_in_as @field

    get teams_school_open_follow_ups_path("unknown-public")
    assert_response :not_found
    get new_teams_school_follow_up_path("unknown-public")
    assert_response :not_found
  end

  test "new opens the modal, due in 3 days, the owner of the school as recipient" do
    Orm::CrmAccount.create!(school: @school, owner: @admin, stage_changed_at: Time.current)
    sign_in_as @field

    get new_teams_school_follow_up_path(@school.public_id), headers: { "Turbo-Frame" => "modal" }

    assert_select "turbo-frame#modal dialog[open]"
    assert_select "input[name='follow_up[due_on]'][value=?]", (Date.current + 3).iso8601
    assert_select "select[name='follow_up[assignee_public_id]'] option[selected][value=?]", @admin.public_id
  end

  test "new defaults the recipient to me when the school has no owner" do
    sign_in_as @field

    get new_teams_school_follow_up_path(@school.public_id)

    assert_select "select[name='follow_up[assignee_public_id]'] option[selected][value=?]", @field.public_id
  end

  test "CA-13: create schedules the follow-up and answers a Turbo Stream on the school block" do
    sign_in_as @field

    assert_difference -> { Orm::CrmFollowUp.count }, 1 do
      post teams_school_follow_ups_path(@school.public_id), headers: turbo,
           params: { follow_up: { due_on: @tomorrow.iso8601, assignee_public_id: @field.public_id, reason: "  Rappeler la direction " } }
    end

    assert_response :success
    created = Orm::CrmFollowUp.last
    assert_equal [ @school.id, @field.id, @tomorrow, "Rappeler la direction", @field.id ],
                 [ created.school_id, created.assignee_id, created.due_on, created.reason, created.created_by_id ]
    assert_select "turbo-stream[action=replace][target=school_crm_follow_ups]"
    assert_select "turbo-stream[action=append][target=toasts]"
  end

  test "create without JavaScript goes back to the school page" do
    sign_in_as @field

    post teams_school_follow_ups_path(@school.public_id),
         params: { follow_up: { due_on: @tomorrow.iso8601, assignee_public_id: @field.public_id, reason: "Rappeler" } }

    assert_redirected_to school_path(@school.public_id)
  end

  test "create refuses a blank reason, a missing date and a stranger as recipient, in 422 with the input kept" do
    sign_in_as @field

    assert_no_difference -> { Orm::CrmFollowUp.count } do
      post teams_school_follow_ups_path(@school.public_id), headers: turbo,
           params: { follow_up: { due_on: "", assignee_public_id: "unknown-public", reason: " " } }
    end

    assert_response :unprocessable_entity
    assert_select "dialog[open]"
    assert_select "[id$=_error]", minimum: 3
  end

  test "create refuses an overlong reason with its message" do
    sign_in_as @field

    post teams_school_follow_ups_path(@school.public_id), headers: turbo,
         params: { follow_up: { due_on: @tomorrow.iso8601, assignee_public_id: @field.public_id, reason: "x" * 201 } }

    assert_response :unprocessable_entity
    assert_select "[id=?]", "follow_up_reason_error", text: /trop long/
  end

  test "CA-13: Mes relances lists mine, the overdue first, and not the others'" do
    follow_up(reason: "Plus tard", due_on: Date.current + 5)
    follow_up(reason: "En retard", due_on: Date.current - 2)
    follow_up(assignee: @admin, reason: "Celle de l'admin")
    sign_in_as @field

    get teams_follow_ups_path

    assert_select "h1", text: I18n.t("teams.crm.follow_ups.index.title")
    assert_select "[role=tab]", count: 1
    assert_equal [ "En retard", "Plus tard" ], css_select("tr td[data-field=reason]").map { it.text.strip }
    assert_select "a[href=?]", "#{school_path(@school.public_id)}#school_crm"
    assert_no_match(/Celle de l'admin/, response.body)
  end

  test "Mes relances says when nothing is open" do
    sign_in_as @field

    get teams_follow_ups_path

    assert_select "p", text: I18n.t("teams.crm.follow_ups.index.empty_mine")
  end

  test "CA-14: only an admin sees « Sans destinataire », with the unavailable recipients flagged" do
    gone = create_team_member(team_role: "field", anonymized_at: Time.current)
    follow_up(assignee: gone, reason: "Orpheline")
    sign_in_as @field
    get teams_follow_ups_path
    assert_select "[role=tab]", count: 1
    assert_no_match(/Orpheline/, response.body)

    sign_in_as @admin
    get teams_follow_ups_path(tab: "orphans")

    assert_select "[role=tab]", count: 2
    assert_select "#follow-ups-panel-orphans:not([hidden])", text: /Orpheline/
    assert_select "#follow-ups-panel-orphans", text: /#{I18n.t("teams.crm.follow_ups.follow_up.unavailable")}/
  end

  test "CA-13: « Faite » completes the follow-up; doing it twice changes nothing more" do
    record = follow_up
    sign_in_as @field

    patch teams_follow_up_completion_path(record.public_id), headers: turbo

    assert_response :success
    record.reload
    assert_equal [ "done", @field.id ], [ record.status, record.done_by_id ]
    assert_select "turbo-stream[action=remove][target=follow_up_row_#{record.public_id}]"
    assert_select "turbo-stream[action=remove][target=follow_up_card_#{record.public_id}]"
    assert_select "turbo-stream[action=replace][target=school_crm_follow_ups]"
    first_done_at = record.done_at

    sign_in_as @admin
    patch teams_follow_up_completion_path(record.public_id), headers: turbo

    assert_response :success
    assert_equal [ @field.id, first_done_at ], [ record.reload.done_by_id, record.done_at ]
  end

  test "completing without JavaScript goes back to the page" do
    record = follow_up
    sign_in_as @field

    patch teams_follow_up_completion_path(record.public_id)

    assert_redirected_to teams_follow_ups_path
    assert_equal "done", record.reload.status
  end

  test "completing an unknown follow-up is 404" do
    sign_in_as @field

    patch teams_follow_up_completion_path("unknown-public"), headers: turbo

    assert_response :not_found
  end

  test "CA-14: an admin reassigns the follow-up of an anonymized member" do
    gone = create_team_member(team_role: "field", anonymized_at: Time.current)
    record = follow_up(assignee: gone)
    sign_in_as @admin

    get edit_teams_follow_up_assignee_path(record.public_id), headers: { "Turbo-Frame" => "modal" }
    assert_select "select[name='follow_up[assignee_public_id]'] option[value=?]", @field.public_id
    assert_select "select[name='follow_up[assignee_public_id]'] option[value=?]", gone.public_id, count: 0

    patch teams_follow_up_assignee_path(record.public_id), headers: turbo, params: { follow_up: { assignee_public_id: @field.public_id } }

    assert_response :success
    assert_equal @field.id, record.reload.assignee_id
    assert_select "turbo-stream[action=remove][target=follow_up_row_#{record.public_id}]"
    assert_select "turbo-stream[action=replace][target=school_crm_follow_ups]"
    assert_select "turbo-stream[action=append][target=toasts]"
  end

  test "the reassignment form preselects a recipient who is still available" do
    record = follow_up(assignee: @field)
    sign_in_as @admin

    get edit_teams_follow_up_assignee_path(record.public_id)

    assert_select "select option[selected][value=?]", @field.public_id
  end

  test "CA-14: a field member who is not the owner can neither open nor submit the reassignment" do
    record = follow_up(assignee: @admin)
    Orm::CrmAccount.create!(school: @school, owner: @admin, stage_changed_at: Time.current)
    sign_in_as @field

    get edit_teams_follow_up_assignee_path(record.public_id)
    assert_response :forbidden
    patch teams_follow_up_assignee_path(record.public_id), headers: turbo, params: { follow_up: { assignee_public_id: @field.public_id } }

    assert_response :forbidden
    assert_equal @admin.id, record.reload.assignee_id
  end

  test "the field member who owns the school reassigns, and a stranger as recipient is refused in 422" do
    record = follow_up(assignee: @admin)
    Orm::CrmAccount.create!(school: @school, owner: @field, stage_changed_at: Time.current)
    sign_in_as @field

    patch teams_follow_up_assignee_path(record.public_id), headers: turbo, params: { follow_up: { assignee_public_id: "unknown-public" } }
    assert_response :unprocessable_entity
    assert_equal @admin.id, record.reload.assignee_id

    patch teams_follow_up_assignee_path(record.public_id), params: { follow_up: { assignee_public_id: @field.public_id } }
    assert_redirected_to teams_follow_ups_path
    assert_equal @field.id, record.reload.assignee_id
  end

  test "reassigning a done follow-up or an unknown one is 404" do
    record = follow_up
    record.update!(status: "done", done_at: Time.current, done_by: @field)
    sign_in_as @admin

    get edit_teams_follow_up_assignee_path(record.public_id)
    assert_response :not_found
    patch teams_follow_up_assignee_path("unknown-public"), headers: turbo, params: { follow_up: { assignee_public_id: @field.public_id } }
    assert_response :not_found
  end
end
