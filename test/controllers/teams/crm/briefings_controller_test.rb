require "test_helper"

# CA-22, CA-24, CA-01 (ADR-XXXX modèles de langage, UDR-XXXX assistants du suivi) : POST /teams/schools/:id/briefing met un briefing
# en file et rend le frame school_crm_briefing ; un second POST sans nouvel échange réaffiche la fiche ; content reçoit 403.
class Teams::Crm::BriefingsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @school = create_school
    @field = create_team_member(team_role: "field")
    @repository = Repositories::Crm::GenerationRepository.new
  end

  def post_briefing = post teams_school_briefing_path(@school.public_id), as: :turbo_stream

  test "a field member gets the waiting state and the job is enqueued" do
    sign_in_as @field

    assert_enqueued_with(job: Crm::BriefingJob) { post_briefing }

    assert_response :success
    generation = @repository.pending_for(school_id: @school.id, kind: "briefing")
    assert_not_nil generation
    assert_select "turbo-stream[action=update][target=school_crm_briefing]"
    assert_includes response.body, "generation_#{generation.public_id}"
    assert_includes response.body, "generation-poll"
  end

  test "CA-22: after a done briefing, a second post shows it again and enqueues nothing" do
    sign_in_as @field
    post_briefing
    generation = @repository.pending_for(school_id: @school.id, kind: "briefing")
    @repository.complete(public_id: generation.public_id, content: "<b>Un</b>\nDeux", model: "m", input_tokens: 1, output_tokens: 1, duration_ms: 1)
    clear_enqueued_jobs

    assert_no_enqueued_jobs { post_briefing }

    assert_response :success
    assert_select "ul[role=list] li", count: 2
    assert_includes response.body, "&lt;b&gt;Un&lt;/b&gt;"
    assert_not_includes response.body, "<b>Un</b>"
  end

  test "CA-24: a failed generation offers Réessayer towards the briefing route" do
    config = Rails.configuration.x.language_models
    original = config.api_key
    config.api_key = nil # le vrai adaptateur répond :not_configured sans toucher le réseau
    sign_in_as @field

    perform_enqueued_jobs { post_briefing }

    assert_response :success
    assert_select "[role=alert]", text: /L'assistant n'a pas répondu/
    assert_select "a[href=?]", teams_school_briefing_path(@school.public_id), text: /Réessayer/
  ensure
    config.api_key = original
  end

  test "content, a teacher and a visitor are refused" do
    sign_in_as create_team_member(team_role: "content")
    assert_no_enqueued_jobs { post_briefing }
    assert_response :forbidden
  end

  test "an unknown school is a 404" do
    sign_in_as @field
    post teams_school_briefing_path("unknown-public"), as: :turbo_stream
    assert_response :not_found
  end
end
