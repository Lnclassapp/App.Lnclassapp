require "test_helper"

# UDR-XXXX (assistants du suivi) §3 « Cycle d'une génération »: one frame per generation, polled until done or failed;
# the model's output is shown as escaped text.
class Teams::Crm::GenerationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school
    @field = create_team_member(team_role: "field")
    @repository = Repositories::Crm::GenerationRepository.new
    sign_in_as @field
  end

  def pending(kind: "briefing")
    @repository.create_pending(generation: Entities::Crm::Generation.new(
      public_id: nil, school_id: @school.id, kind:, status: "pending", requested_by_id: @field.id, follow_up_id: nil,
      input_fingerprint: nil, content: nil, error_code: nil, model: nil, input_tokens: nil, output_tokens: nil, duration_ms: nil
    )).value
  end

  def show(generation) = get teams_generation_path(generation.public_id), headers: { "Turbo-Frame" => "generation_#{generation.public_id}" }

  test "a pending generation renders the loading state and the poll wiring" do
    generation = pending
    show generation

    assert_response :success
    assert_select "turbo-frame#generation_#{generation.public_id}[aria-live=polite][aria-busy=true]"
    assert_select "[data-controller=generation-poll][data-generation-poll-url-value=?]", teams_generation_path(generation.public_id)
    assert_select "[data-generation-poll-interval-value=2000][data-generation-poll-timeout-value=45000]"
    assert_select "[role=status]", text: /Préparation de la fiche/
  end

  test "the waiting label follows the kind" do
    { "dictation" => "Écoute du compte rendu", "whatsapp_draft" => "Rédaction du message", "pedagogy_report" => "Rédaction de la synthèse" }.each do |kind, label|
      show pending(kind:)
      assert_select "[role=status]", text: /#{label}/
    end
  end

  test "a done generation of a kind with no partial of its own shows its text escaped, with no poll" do
    generation = pending(kind: "pedagogy_report")
    @repository.complete(public_id: generation.public_id, content: "<script>alert(1)</script>\nLigne 2", model: "m", input_tokens: 1, output_tokens: 1, duration_ms: 1)

    show generation

    assert_response :success
    assert_select "script", count: 0
    assert_select "[data-controller=generation-poll]", count: 0
    assert_select "p.whitespace-pre-line", text: /alert\(1\)/
    assert_select "turbo-frame[aria-busy=true]", count: 0
  end

  test "a failed generation shows the error state with the message of its error code" do
    { "timeout" => "Il a mis trop de temps.", "provider_error" => "Réessayez dans un instant.", "invalid_response" => "Réessayez dans un instant." }.each do |code, message|
      generation = pending
      @repository.mark_failed(public_id: generation.public_id, error_code: code, duration_ms: 10)

      show generation

      assert_select "[role=alert]", text: /L'assistant n'a pas répondu/
      assert_select "[role=alert]", text: /#{Regexp.escape(message)}/
      assert_select "[data-controller=generation-poll]", count: 0
    end
  end

  test "a failed briefing offers a retry that really starts a new generation" do
    generation = pending
    @repository.mark_failed(public_id: generation.public_id, error_code: "timeout", duration_ms: 10)

    show generation

    assert_select "a[href=?][data-turbo-method=post]", teams_school_briefing_path(@school.public_id), text: /Réessayer/
    post teams_school_briefing_path(@school.public_id), as: :turbo_stream
    assert_response :success
    assert_not_nil @repository.pending_for(school_id: @school.id, kind: "briefing")
  end

  test "a failed generation of a kind whose route is not served yet offers no retry" do
    generation = pending(kind: "dictation")
    @repository.mark_failed(public_id: generation.public_id, error_code: "timeout", duration_ms: 10)

    show generation

    assert_select "[role=alert]"
    assert_select "[role=alert] a", count: 0
  end

  test "a failed whatsapp draft that is linked to no follow-up offers no retry" do
    generation = pending(kind: "whatsapp_draft")
    @repository.mark_failed(public_id: generation.public_id, error_code: "timeout", duration_ms: 10)

    show generation

    assert_select "[role=alert]"
    assert_select "[role=alert] a", count: 0
  end

  test "a timed-out poll of a briefing offers the same retry" do
    show pending
    assert_select "[data-generation-poll-target=timedOut] a[href=?][data-turbo-method=post]", teams_school_briefing_path(@school.public_id)
  end

  test "a done briefing found by the poll renders the briefing list with its regenerate button" do
    generation = pending
    @repository.complete(public_id: generation.public_id, content: "- Ligne un\n- Ligne deux", model: "m", input_tokens: 1, output_tokens: 1, duration_ms: 1)

    show generation

    assert_select "turbo-frame#generation_#{generation.public_id} ul[role=list] li", 2
    assert_select "a[href=?][data-turbo-method=post]", teams_school_briefing_path(@school.public_id), text: /Régénérer/
    assert_select "p.whitespace-pre-line", count: 0
    assert_select "p.text-mute", text: /Préparée il y a/
  end

  test "an unknown generation is a 404, a content member is a 403" do
    get teams_generation_path("unknown-public")
    assert_response :not_found

    generation = pending
    sign_in_as create_team_member(team_role: "content")
    get teams_generation_path(generation.public_id)
    assert_response :forbidden
  end
end
