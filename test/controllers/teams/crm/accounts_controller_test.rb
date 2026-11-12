require "test_helper"

# CA-01, CA-02 (ADR-XXXX contexte crm, UDR-XXXX bloc « Suivi »): the « Suivi » block of a school page, served in a lazy frame,
# exists for admin and field members only; the shell holds six lazy frames, one per sub-block.
class Teams::Crm::AccountsControllerTest < ActionDispatch::IntegrationTest
  FRAME_IDS = %w[school_crm_stage school_crm_assistants school_crm_follow_ups school_crm_contacts school_crm_usage
                 school_crm_journal].freeze

  setup do
    @school = create_school
    @field = create_team_member(team_role: "field")
  end

  def follow_up_path = teams_school_follow_up_path(@school.public_id)

  test "CA-01: a field member opens the block, with its six lazy sub-block frames in the documented order" do
    sign_in_as @field

    get follow_up_path, headers: { "Turbo-Frame" => "school_crm" }

    assert_response :success
    assert_select "turbo-frame#school_crm" do
      assert_select "h2#school_crm_title"
      assert_select "turbo-frame[loading=lazy]", count: 6
      assert_equal FRAME_IDS, css_select("turbo-frame[loading=lazy]").map { it["id"] }
      FRAME_IDS.each { assert_select "turbo-frame##{it}[src]" }
    end
  end

  test "an admin opens the block too" do
    sign_in_as create_team_member(team_role: "admin")

    get follow_up_path, headers: { "Turbo-Frame" => "school_crm" }

    assert_response :success
  end

  test "every sub-block frame points at its own address under the school" do
    sign_in_as @field

    get follow_up_path, headers: { "Turbo-Frame" => "school_crm" }

    sources = FRAME_IDS.to_h { [ it, css_select("turbo-frame##{it}").first["src"] ] }
    assert_equal({ "school_crm_stage" => teams_school_stage_path(@school.public_id),
                   "school_crm_assistants" => teams_school_assistant_path(@school.public_id),
                   "school_crm_follow_ups" => teams_school_open_follow_ups_path(@school.public_id),
                   "school_crm_contacts" => teams_school_contacts_path(@school.public_id),
                   "school_crm_usage" => teams_school_usage_path(@school.public_id),
                   "school_crm_journal" => teams_school_interactions_path(@school.public_id) }, sources)
  end

  test "an unknown school is a 404" do
    sign_in_as @field

    get teams_school_follow_up_path("unknown-public"), headers: { "Turbo-Frame" => "school_crm" }

    assert_response :not_found
  end

  test "CA-01: a content member receives 403 on the block" do
    sign_in_as create_team_member(team_role: "content")

    get follow_up_path

    assert_response :forbidden
  end

  test "CA-02: a teacher, a student and a school admin receive 403" do
    [ create_teacher, create_student, create_school_admin ].each do |user|
      sign_in_as user
      get follow_up_path
      assert_response :forbidden, user.role
      sign_out
    end
  end

  test "a visitor is sent to the sign-in" do
    get follow_up_path

    assert_redirected_to new_session_path
  end

  test "the school page hosts the lazy block for a field member" do
    sign_in_as @field

    get school_path(@school.public_id)

    assert_select "turbo-frame#school_crm[loading=lazy][src=?]", follow_up_path
  end

  test "CA-01: the school page of a content member has no « Suivi » block" do
    sign_in_as create_team_member(team_role: "content")

    get school_path(@school.public_id)

    assert_response :success
    assert_select "turbo-frame#school_crm", count: 0
  end

  test "the team home hosts the lazy follow-ups card for a field member, not for a content member" do
    sign_in_as @field
    get team_home_path
    assert_select "turbo-frame#team_home_follow_ups[loading=lazy][src=?]", teams_home_follow_up_path
    sign_out

    sign_in_as create_team_member(team_role: "content")
    get team_home_path
    assert_select "turbo-frame#team_home_follow_ups", count: 0
  end

  test "the « Relances » entry is in the « Plus » menu of an admin and a field member, not of a content member" do
    sign_in_as @field
    get team_home_path
    assert_select "a[href=?]", teams_follow_ups_path

    sign_in_as create_team_member(team_role: "content")
    get team_home_path
    assert_select "a[href=?]", teams_follow_ups_path, count: 0
  end

  # The controllers of the lots do not exist yet: the table of routes is read, no path is recognised (which loads the controller).
  def declared_routes
    Rails.application.routes.routes.map do |route|
      [ route.verb, route.path.spec.to_s.delete_suffix("(.:format)"), "#{route.defaults[:controller]}##{route.defaults[:action]}" ]
    end
  end

  test "CA-12: no address edits or deletes an interaction" do
    interactions = declared_routes.select { |_, path, _| path.include?("/interactions") }

    assert_equal [ %w[GET /teams/schools/:school_public_id/interactions teams/crm/interactions#index],
                   %w[POST /teams/schools/:school_public_id/interactions teams/crm/interactions#create],
                   %w[GET /teams/schools/:school_public_id/interactions/new teams/crm/interactions#new] ].sort, interactions.sort
  end

  test "every address of the follow-up is routed to its controller, frozen by the Lot 0" do
    school = "/teams/schools/:school_public_id"
    expected = [
      [ "GET", "#{school}/follow-up", "teams/crm/accounts#show" ],
      [ "GET", "#{school}/stage", "teams/crm/stages#show" ], [ "PATCH", "#{school}/stage", "teams/crm/stages#update" ],
      [ "GET", "#{school}/owner/edit", "teams/crm/owners#edit" ], [ "PATCH", "#{school}/owner", "teams/crm/owners#update" ],
      [ "GET", "#{school}/usage", "teams/crm/usages#show" ],
      [ "GET", "#{school}/contacts", "teams/crm/contacts#index" ], [ "GET", "#{school}/contacts/new", "teams/crm/contacts#new" ],
      [ "POST", "#{school}/contacts", "teams/crm/contacts#create" ],
      [ "GET", "#{school}/contacts/:public_id/archive", "teams/crm/contacts#archive" ],
      [ "DELETE", "#{school}/contacts/:public_id", "teams/crm/contacts#destroy" ],
      [ "GET", "#{school}/follow-ups", "teams/crm/follow_ups#school" ], [ "GET", "#{school}/follow-ups/new", "teams/crm/follow_ups#new" ],
      [ "POST", "#{school}/follow-ups", "teams/crm/follow_ups#create" ],
      [ "GET", "#{school}/assistant", "teams/crm/assistants#show" ], [ "POST", "#{school}/briefing", "teams/crm/briefings#create" ],
      [ "GET", "#{school}/dictation/new", "teams/crm/dictations#new" ], [ "POST", "#{school}/dictation", "teams/crm/dictations#create" ],
      [ "POST", "#{school}/pedagogy-reports", "teams/crm/pedagogy_reports#create" ],
      [ "GET", "/teams/follow-ups", "teams/crm/follow_ups#index" ],
      [ "PATCH", "/teams/follow-ups/:follow_up_public_id/completion", "teams/crm/follow_up_completions#update" ],
      [ "GET", "/teams/follow-ups/:follow_up_public_id/assignee/edit", "teams/crm/follow_up_assignees#edit" ],
      [ "PATCH", "/teams/follow-ups/:follow_up_public_id/assignee", "teams/crm/follow_up_assignees#update" ],
      [ "GET", "/teams/follow-ups/:follow_up_public_id/whatsapp-draft/new", "teams/crm/whatsapp_drafts#new" ],
      [ "POST", "/teams/follow-ups/:follow_up_public_id/whatsapp-draft", "teams/crm/whatsapp_drafts#create" ],
      [ "GET", "/teams/home-follow-ups", "teams/crm/home_follow_ups#show" ],
      [ "GET", "/teams/generations/:public_id", "teams/crm/generations#show" ],
      [ "GET", "/teams/pedagogy-reports/:public_id", "teams/crm/pedagogy_reports#show" ]
    ]

    assert_empty expected - declared_routes
  end
end
