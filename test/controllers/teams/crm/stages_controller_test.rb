require "test_helper"

# CA-06, CA-07, CA-08 (ADR-XXXX contexte crm, UDR-XXXX bloc « Suivi »): stage, owner and usage sub-blocks of the school page;
# admin and field only, writes answered in Turbo Stream on the stage frame, errors in 422 inside the modal.
class Teams::Crm::StagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Classique")
    @field = create_team_member(team_role: "field", first_name: "Awa", last_name: "Koné")
    @content = create_team_member(team_role: "content")
    @id = @school.public_id
  end

  def turbo = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }
  def account = Orm::CrmAccount.find_by(school: @school)
  def audit(action) = Orm::AuditEvent.where(action:, subject_type: "School", subject_id: @school.id)

  test "CA-01: content gets 403 on the stage, owner and usage addresses" do
    sign_in_as @content

    get teams_school_stage_path(@id)
    assert_response :forbidden
    patch teams_school_stage_path(@id), params: { stage: { stage: "demo_done" } }
    assert_response :forbidden
    get edit_teams_school_owner_path(@id)
    assert_response :forbidden
    patch teams_school_owner_path(@id), params: { owner: { owner_public_id: @content.public_id } }
    assert_response :forbidden
    get teams_school_usage_path(@id)
    assert_response :forbidden
    assert_nil account
  end

  test "the stage frame shows Prospect and no owner for a school never followed" do
    sign_in_as @field
    get teams_school_stage_path(@id), headers: { "Turbo-Frame" => "school_crm_stage" }

    assert_select "turbo-frame#school_crm_stage" do
      assert_select "span", text: I18n.t("teams.crm.common.stages.prospect")
      assert_select "dialog", count: 2
      assert_select "input[type=radio][name=?]", "stage[stage]", count: 4
      assert_select "input[type=radio][value=active], input[type=radio][value=registered]", count: 0
    end
    assert_includes response.body, I18n.t("teams.crm.stages.stage.no_owner")
  end

  test "the displayed stage is computed from usage and says so" do
    create_teacher(school: @school)
    sign_in_as @field
    get teams_school_stage_path(@id), headers: { "Turbo-Frame" => "school_crm_stage" }

    assert_select "span", text: I18n.t("teams.crm.common.stages.registered")
    assert_includes response.body, CGI.escapeHTML(I18n.t("teams.crm.stages.stage.computed_tip"))
  end

  test "an owner who is no longer assignable shows as unavailable" do
    gone = create_team_member(team_role: "field", anonymized_at: Time.current)
    Orm::CrmAccount.create!(school: @school, owner: gone, stage_changed_at: Time.current)
    sign_in_as @field
    get teams_school_stage_path(@id), headers: { "Turbo-Frame" => "school_crm_stage" }

    assert_includes response.body, I18n.t("teams.crm.stages.stage.owner_unavailable")
  end

  test "an unknown school is 404 on every address" do
    sign_in_as @field
    get teams_school_stage_path("nope")
    assert_response :not_found
    get teams_school_usage_path("nope")
    assert_response :not_found
    patch teams_school_owner_path("nope"), params: { owner: { owner_public_id: @field.public_id } }
    assert_response :not_found
  end

  test "CA-07: a field member sets the stage and the owner; the audit log has both actions" do
    sign_in_as @field

    patch teams_school_stage_path(@id), params: { stage: { stage: "demo_done" } }, headers: turbo
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=replace][target=school_crm_stage]"
    assert_equal "demo_done", account.stage

    patch teams_school_owner_path(@id), params: { owner: { owner_public_id: @field.public_id } }, headers: turbo
    assert_response :success
    assert_select "turbo-stream[action=replace][target=school_crm_stage]"
    assert_includes response.body, "Awa Koné"
    assert_equal @field.id, account.owner_id
    assert_equal "demo_done", account.stage
    assert_equal 1, audit("crm.stage_changed").count
    assert_equal 1, audit("crm.owner_changed").count
    assert_equal({ "from" => "prospect", "to" => "demo_done", "lost_reason" => nil }, audit("crm.stage_changed").first.metadata)
  end

  test "the html fallback redirects to the school page" do
    sign_in_as @field
    patch teams_school_stage_path(@id), params: { stage: { stage: "subscribed" } }
    assert_redirected_to school_path(@id)
    patch teams_school_owner_path(@id), params: { owner: { owner_public_id: "" } }
    assert_redirected_to school_path(@id)
    get edit_teams_school_owner_path(@id)
    assert_redirected_to school_path(@id)
  end

  test "CA-06: lost without a reason is 422, the modal shows the error and nothing changes" do
    sign_in_as @field
    patch teams_school_stage_path(@id), params: { stage: { stage: "lost", lost_reason: "" } }, headers: turbo

    assert_response :unprocessable_entity
    assert_select "turbo-frame#school_crm_stage dialog[open]"
    assert_select "[id$=_error]", text: /obligatoire pour une école perdue/
    assert_nil account
    assert_equal 0, audit("crm.stage_changed").count
  end

  test "lost with a reason is saved and the reason shown" do
    sign_in_as @field
    patch teams_school_stage_path(@id), params: { stage: { stage: "lost", lost_reason: "price" } }, headers: turbo

    assert_response :success
    assert_equal "price", account.lost_reason
    assert_includes response.body, I18n.t("teams.crm.common.lost_reasons.price")
  end

  test "an active or unknown stage cannot be typed" do
    sign_in_as @field
    %w[active registered nope].each do |stage|
      patch teams_school_stage_path(@id), params: { stage: { stage: } }, headers: turbo
      assert_response :unprocessable_entity
    end
    assert_nil account
  end

  test "CA-08: a content member as owner is 422 and the owner does not change" do
    Orm::CrmAccount.create!(school: @school, owner: @field, stage_changed_at: Time.current)
    sign_in_as @field
    patch teams_school_owner_path(@id), params: { owner: { owner_public_id: @content.public_id } }, headers: turbo

    assert_response :unprocessable_entity
    assert_select "turbo-frame#school_crm_stage dialog[open]"
    assert_equal @field.id, account.owner_id
    assert_equal 0, audit("crm.owner_changed").count
  end

  test "naming nobody clears the owner" do
    Orm::CrmAccount.create!(school: @school, owner: @field, stage_changed_at: Time.current)
    sign_in_as @field
    patch teams_school_owner_path(@id), params: { owner: { owner_public_id: "" } }, headers: turbo

    assert_response :success
    assert_nil account.owner_id
  end

  test "the usage frame shows the three figures, and never for an unused school" do
    sign_in_as @field
    get teams_school_usage_path(@id), headers: { "Turbo-Frame" => "school_crm_usage" }
    assert_select "turbo-frame#school_crm_usage" do
      assert_select "dd", count: 3
    end
    assert_includes response.body, I18n.t("teams.crm.usages.show.never")

    create_teacher(school: @school)
    get teams_school_usage_path(@id), headers: { "Turbo-Frame" => "school_crm_usage" }
    assert_select "dd", text: "1"
  end
end
