require "test_helper"

# CA-28, CA-24, CA-01 (ADR-XXXX modèles de langage, UDR-XXXX assistants du suivi) : « Rédiger un message » sur une relance ouvre la modale,
# POST met un brouillon en file, le brouillon prêt est modifiable, se copie et s'ouvre dans WhatsApp (l'application n'envoie rien) ;
# content reçoit 403, une relance inconnue ou faite 404.
class Teams::Crm::WhatsappDraftsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @school = create_school(name: "Lycée Classique")
    @field = create_team_member(team_role: "field")
    @follow_up = Orm::CrmFollowUp.create!(school: @school, assignee: @field, due_on: Date.current + 1, reason: "Rappeler pour le devis", created_by: @field)
    @repository = Repositories::Crm::GenerationRepository.new
    @config = Rails.configuration.x.language_models
    @original_key = @config.api_key
    @config.api_key = "test-key"
  end

  teardown do
    @config.api_key = @original_key
  end

  def contact(name, phone) = Orm::CrmContact.create!(school_id: @school.id, full_name: name, position: "director", phone:, created_by_id: @field.id)
  def new_path(follow_up = @follow_up) = new_teams_follow_up_whatsapp_draft_path(follow_up.public_id)
  def create_path(follow_up = @follow_up) = teams_follow_up_whatsapp_draft_path(follow_up.public_id)
  def post_draft = post create_path, as: :turbo_stream
  def modal = { "Turbo-Frame" => "modal" }

  def done_draft(content: "Bonjour, je reviens vers vous.")
    post_draft
    generation = @repository.pending_for(school_id: @school.id, kind: "whatsapp_draft")
    @repository.complete(public_id: generation.public_id, content:, model: "m", input_tokens: 1, output_tokens: 1, duration_ms: 1)
    generation
  end

  test "the modal opens in the modal frame with a form that posts to the draft route" do
    sign_in_as @field

    get new_path, headers: modal

    assert_response :success
    assert_select "turbo-frame#modal"
    assert_select "dialog, [role=dialog]", minimum: 1
    assert_select "turbo-frame#whatsapp_draft form[action=?][method=post]", create_path
    assert_select "form[action=?] button[type=submit]", create_path, text: /Rédiger le message/
  end

  test "without an API key the modal says the assistant is not configured and offers no form" do
    @config.api_key = nil
    sign_in_as @field

    get new_path, headers: modal

    assert_response :success
    assert_includes response.body, "Assistant non configuré"
    assert_select "form[action=?]", create_path, count: 0
  end

  test "CA-28: a post enqueues the job and renders the waiting state in the draft frame, bound to the follow-up" do
    sign_in_as @field

    assert_enqueued_with(job: Crm::WhatsappDraftJob) { post_draft }

    assert_response :success
    generation = @repository.pending_for(school_id: @school.id, kind: "whatsapp_draft")
    assert_equal @follow_up.id, generation.follow_up_id
    assert_select "turbo-stream[action=update][target=whatsapp_draft]"
    assert_includes response.body, "generation_#{generation.public_id}"
    assert_includes response.body, "generation-poll"
  end

  test "CA-28: the ready draft is an editable textarea with a counter, Copier and, per contact with a phone, Ouvrir dans WhatsApp" do
    contact("Awa Koné", "0701020304")
    contact("Sans numéro", nil)
    sign_in_as @field
    generation = done_draft(content: "Bonjour & bienvenue <b>à tous</b>")
    clear_enqueued_jobs

    assert_no_enqueued_jobs { post_draft }

    assert_response :success
    assert_select "textarea[maxlength=600][data-whatsapp-link-target=text]", text: /Bonjour & bienvenue/
    assert_select "[data-controller~=whatsapp-link][data-whatsapp-link-prefix-value='225']"
    assert_select "[data-whatsapp-link-target=counter]"
    assert_select "textarea[aria-describedby]"
    assert_select "[data-controller=clipboard] button", text: /Copier/
    assert_select "select[data-whatsapp-link-target=recipient] option", count: 1
    assert_select "a[data-whatsapp-link-target=link][target=_blank][rel~=noopener]" do |links|
      assert_equal "https://wa.me/2250701020304?text=#{ERB::Util.url_encode('Bonjour & bienvenue <b>à tous</b>')}", links.first["href"]
    end
    assert_not_includes response.body, "<b>à tous</b>"
    assert_select "turbo-frame#generation_#{generation.public_id}"
  end

  test "the ready draft with no contact phone offers Copier alone and says how to open WhatsApp" do
    contact("Sans numéro", nil)
    sign_in_as @field
    done_draft

    post_draft

    assert_select "[data-controller=clipboard] button", text: /Copier/
    assert_select "a[data-whatsapp-link-target=link]", count: 0
    assert_select "select[data-whatsapp-link-target=recipient]", count: 0
    assert_includes response.body, "Ajoutez un contact avec un numéro pour ouvrir WhatsApp."
  end

  test "the poll route renders the ready draft of a whatsapp_draft generation" do
    contact("Awa Koné", "0701020304")
    sign_in_as @field
    generation = done_draft

    get teams_generation_path(generation.public_id), headers: { "Turbo-Frame" => "generation_#{generation.public_id}" }

    assert_response :success
    assert_select "textarea[data-whatsapp-link-target=text]"
    assert_select "a[href^='https://wa.me/2250701020304']"
  end

  test "CA-24: a failed draft offers Réessayer towards the follow-up route, in POST" do
    config_key = @config.api_key
    @config.api_key = nil # le vrai adaptateur répond :not_configured sans toucher le réseau
    sign_in_as @field
    perform_enqueued_jobs { post_draft }
    generation = Orm::CrmGeneration.find_by!(kind: "whatsapp_draft")

    get teams_generation_path(generation.public_id), headers: { "Turbo-Frame" => "generation_#{generation.public_id}" }

    assert_select "[role=alert]", text: /L'assistant n'a pas répondu/
    assert_select "a[href=?][data-turbo-method=post]", create_path, text: /Réessayer/
    assert_equal "test-key", config_key
  end

  test "a draft running for another follow-up of the school is not doubled" do
    other = Orm::CrmFollowUp.create!(school: @school, assignee: @field, due_on: Date.current + 2, reason: "Autre", created_by: @field)
    sign_in_as @field
    post create_path(other), as: :turbo_stream

    assert_no_enqueued_jobs { post_draft }

    assert_response :success
    assert_equal 1, Orm::CrmGeneration.where(kind: "whatsapp_draft").count
  end

  test "CA-01: content is refused on both addresses and nothing is created" do
    sign_in_as create_team_member(team_role: "content")

    get new_path
    assert_response :forbidden
    assert_no_enqueued_jobs { post_draft }
    assert_response :forbidden
    assert_equal 0, Orm::CrmGeneration.count
  end

  test "an unknown follow-up is a 404 and so is a follow-up already done" do
    sign_in_as @field
    get new_teams_follow_up_whatsapp_draft_path("unknown")
    assert_response :not_found
    post teams_follow_up_whatsapp_draft_path("unknown"), as: :turbo_stream
    assert_response :not_found

    @follow_up.update!(status: "done", done_at: Time.current, done_by: @field)
    get new_path
    assert_response :not_found
    post_draft
    assert_response :not_found
  end

  test "the menu of an open follow-up offers Rédiger un message in the modal frame" do
    sign_in_as @field

    get teams_follow_ups_path(tab: "mine")

    assert_select "a[href=?][data-turbo-frame=modal]", new_path, text: /Rédiger un message/
  end
end
