require "test_helper"

# CA-23 (UDR-XXXX assistants du suivi): without an OpenRouter key the card shows « Assistant non configuré » and no button;
# with a key it shows the three assistant buttons. Also the polling endpoint of a generation (ADR-XXXX modèles de langage §4).
class Teams::Crm::AssistantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school
    @field = create_team_member(team_role: "field")
    @config = Rails.configuration.x.language_models
    @original_key = @config.api_key
  end

  teardown { @config.api_key = @original_key }

  def open_card = get teams_school_assistant_path(@school.public_id), headers: { "Turbo-Frame" => "school_crm_assistants" }

  test "CA-23: without a key the card says the assistant is not configured, with no button" do
    @config.api_key = nil
    sign_in_as @field

    open_card

    assert_response :success
    assert_select "turbo-frame#school_crm_assistants" do
      assert_select "span", text: "Assistant non configuré"
      assert_select "button", count: 0
      assert_select "a[href=?]", teams_school_briefing_path(@school.public_id), count: 0
    end
  end

  test "with a key the card shows the three assistants and the briefing frame" do
    @config.api_key = "sk-test"
    sign_in_as @field

    open_card

    assert_response :success
    assert_select "turbo-frame#school_crm_assistants" do
      assert_select "a[href=?][data-turbo-method=post]", teams_school_briefing_path(@school.public_id)
      assert_select "a[href=?]", new_teams_school_dictation_path(@school.public_id)
      assert_select "a[href=?][data-turbo-method=post]", teams_school_pedagogy_reports_path(@school.public_id)
      assert_select "turbo-frame#school_crm_briefing"
      assert_select "span", text: "Assistant non configuré", count: 0
    end
  end

  test "an unknown school is a 404" do
    sign_in_as @field

    get teams_school_assistant_path("unknown-public")

    assert_response :not_found
  end

  test "a content member and a teacher receive 403" do
    [ create_team_member(team_role: "content"), create_teacher ].each do |user|
      sign_in_as user
      open_card
      assert_response :forbidden
    end
  end
end
