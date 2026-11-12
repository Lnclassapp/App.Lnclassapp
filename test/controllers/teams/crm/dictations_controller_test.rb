require "test_helper"

# CA-25, CA-26, CA-27 (ADR-XXXX modèles de langage, menace du Lot K, UDR-XXXX assistants du suivi) : la modale d'enregistrement,
# la réception de l'audio (refusé par ses octets, sa taille, avant tout stockage et tout appel), le formulaire pré-rempli sans rien
# enregistrer, l'audio purgé après traitement ; content reçoit 403, une école inconnue 404.
class Teams::Crm::DictationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  # Le faux modèle remplace le client OpenRouter dans le job réel (jamais le réseau) : le remplacement est posé au setup et retiré au teardown.
  module ModelDouble
    mattr_accessor :double
  end

  WEBM = [ "1A45DFA39F4286" ].pack("H*") + "webm" + ("\0" * 200)
  ANSWER = { kind: "call", outcome: "positive", contact_name: "Mme Kouassi", next_step: "Envoyer la plaquette",
             note: "Directrice intéressée <script>alert(1)</script>", follow_up_in_days: 5 }.to_json

  setup do
    @school = create_school
    @field = create_team_member(team_role: "field")
    @repository = Repositories::Crm::GenerationRepository.new
    sign_in_as @field
    Crm::DictationJob.send(:define_method, :language_model) { ModelDouble.double || Crm::OpenRouterLanguageModel.new }
    Crm::DictationJob.send(:private, :language_model)
  end

  teardown do
    ModelDouble.double = nil
    Crm::DictationJob.send(:remove_method, :language_model)
  end

  def dictation_path = teams_school_dictation_path(@school.public_id)

  def recording(bytes = WEBM, type = "audio/webm", name: "dictation.webm")
    Rack::Test::UploadedFile.new(StringIO.new(bytes), type, original_filename: name)
  end

  def send_audio(file = recording) = post dictation_path, params: { audio: file }

  def audio_fixture(name, type) = fixture_file_upload("audio/#{name}", type)

  def no_trace_of_the_upload!
    assert_nil @repository.pending_for(school_id: @school.id, kind: "dictation")
    assert_equal 0, Orm::CrmGeneration.count
    assert_equal 0, ActiveStorage::Blob.count
    assert_no_enqueued_jobs
  end

  def finished_generation(content, school: @school)
    created = @repository.create_pending(generation: Entities::Crm::Generation.new(
      public_id: nil, school_id: school.id, kind: "dictation", status: "pending", requested_by_id: @field.id, follow_up_id: nil,
      input_fingerprint: nil, content: nil, error_code: nil, model: nil, input_tokens: nil, output_tokens: nil, duration_ms: nil
    )).value
    @repository.complete(public_id: created.public_id, content:, model: "m", input_tokens: 1, output_tokens: 1, duration_ms: 1).value
  end

  test "when the queue refuses and the failure cannot be written, the recorder says the assistant is unavailable" do
    refusing = Class.new(Repositories::Crm::GenerationRepository) { def mark_failed(**) = Shared::Result.failure(:not_found) }.new
    Repositories::Crm::GenerationRepository.define_singleton_method(:new) { |*| refusing }
    Crm::DictationJob.define_singleton_method(:perform_later) { |*| false }

    send_audio

    assert_response :service_unavailable
    assert_includes response.body, "L&#39;assistant est indisponible"
  ensure
    Repositories::Crm::GenerationRepository.singleton_class.send(:remove_method, :new)
    Crm::DictationJob.singleton_class.send(:remove_method, :perform_later)
  end

  test "new: the recorder modal, inside the modal frame" do
    get new_teams_school_dictation_path(@school.public_id), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal dialog[open]"
    assert_select "form[action='#{dictation_path}'][enctype='multipart/form-data'][data-controller='voice-recorder'][data-voice-recorder-max-seconds-value='180']"
    assert_select "input[type=file][name=audio][accept='audio/*']"
    assert_select "[data-voice-recorder-target=timer][role=timer]"
    assert_select "a[href='#{teams_school_interactions_path(@school.public_id)}/new'][data-turbo-frame=modal]", text: /Saisir à la main/
  end

  test "CA-01: content gets 403 on every action, nothing is stored" do
    sign_in_as create_team_member(team_role: "content")

    get new_teams_school_dictation_path(@school.public_id)
    assert_response :forbidden
    send_audio
    assert_response :forbidden

    no_trace_of_the_upload!
  end

  test "an unknown school is a 404" do
    get new_teams_school_dictation_path("inconnue")
    assert_response :not_found
    post teams_school_dictation_path("inconnue"), params: { audio: recording }
    assert_response :not_found
  end

  test "CA-25: a valid recording is stored privately, the dictation waits, nothing is noted" do
    assert_no_difference -> { Orm::CrmInteraction.count } do
      assert_enqueued_with(job: Crm::DictationJob) { send_audio }
    end

    assert_response :success
    generation = @repository.pending_for(school_id: @school.id, kind: "dictation")
    assert_not_nil generation
    assert_equal @field.id, generation.requested_by_id
    attachment = Orm::CrmGeneration.find_by!(public_id: generation.public_id).audio
    assert_equal "audio/webm", attachment.content_type
    assert_equal WEBM, attachment.download
    assert_select "turbo-stream[action=update][target=modal]"
    assert_includes response.body, "generation_#{generation.public_id}"
    assert_includes response.body, "generation-poll"
    assert_includes response.body, "Écoute du compte rendu"
  end

  test "the type is read from the bytes: ogg and mp4 recordings are accepted" do
    send_audio(audio_fixture("enregistrement.ogg", "application/octet-stream"))
    assert_response :success
    assert_equal "audio/ogg", Orm::CrmGeneration.last.audio.content_type

    Orm::CrmGeneration.last.update!(status: "done")
    send_audio(audio_fixture("marque-m4a.m4a", "text/plain"))
    assert_response :success
    assert_equal "audio/mp4", Orm::CrmGeneration.last.audio.content_type
  end

  test "the announced type and the extension do not count: webm bytes named wav pass" do
    send_audio(recording(WEBM, "audio/wav", name: "voix.wav"))

    assert_response :success
    assert_equal "audio/webm", Orm::CrmGeneration.last.audio.content_type
  end

  test "CA-26: audio/wav is refused with no generation, no file kept and no job" do
    send_audio(audio_fixture("enregistrement.wav", "audio/wav"))

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=update][target=modal]"
    assert_includes response.body, "format non pris en charge (3 min, 10 Mo, webm/ogg/mp4)"
    no_trace_of_the_upload!
  end

  test "CA-26: wav bytes announced as webm are refused too" do
    send_audio(audio_fixture("enregistrement.wav", "audio/webm"))

    assert_response :unprocessable_entity
    no_trace_of_the_upload!
  end

  test "CA-26: a request announcing more than 11 Mo (Content-Length) is refused with a 422 for the interface, and nothing is stored" do
    send_audio(recording(WEBM + ("\0" * (12 * 1024 * 1024))))

    assert_response :unprocessable_entity
    assert_includes response.body, "format non pris en charge (3 min, 10 Mo, webm/ogg/mp4)"
    no_trace_of_the_upload!
  end

  test "CA-26: a file above 10 Mo but within the request margin is refused by its real size" do
    send_audio(recording(WEBM + ("\0" * (10 * 1024 * 1024 + 4096))))

    assert_response :unprocessable_entity
    assert_includes response.body, "format non pris en charge"
    no_trace_of_the_upload!
  end

  test "an empty file and a non-file value are refused" do
    send_audio(recording(""))
    assert_response :unprocessable_entity
    assert_includes response.body, "Aucun enregistrement reçu"

    post dictation_path, params: { audio: "pas un fichier" }
    assert_response :unprocessable_entity
    no_trace_of_the_upload!
  end

  test "without any file (the retry of a failed dictation) the recorder comes back, nothing is created" do
    post dictation_path

    assert_response :success
    assert_select "turbo-stream[action=update][target=modal]"
    assert_includes response.body, "voice-recorder"
    assert_not_includes response.body, "role=\"alert\" data-voice-recorder-target=\"error\" class"
    no_trace_of_the_upload!
  end

  test "a second dictation while one is running is a 409 and its audio is not kept" do
    send_audio
    assert_equal 1, ActiveStorage::Blob.count

    send_audio

    assert_response :conflict
    assert_includes response.body, "déjà en cours"
    assert_equal 1, Orm::CrmGeneration.count
    assert_equal 1, ActiveStorage::Blob.count
  end

  test "CA-25: with the fake model the dictation ends done, the audio is gone and nothing is noted" do
    fake = FakeLanguageModel.new(ANSWER)
    ModelDouble.double = fake

    assert_no_difference -> { Orm::CrmInteraction.count } do
      perform_enqueued_jobs { send_audio }
    end

    assert_response :success
    assert_equal "done", Orm::CrmGeneration.last.status
    assert_equal 0, ActiveStorage::Blob.count
    assert_not Orm::CrmGeneration.last.audio.attached?
    assert_equal({ data: WEBM, format: "webm" }, fake.calls.last[:audio])
    assert_includes response.body, "dictation_prefill_#{Orm::CrmGeneration.last.public_id}"
  end

  test "CA-25: when the model fails the audio is gone too and the retry points back to the recorder" do
    ModelDouble.double = FakeLanguageModel.new.fail_with(:timeout)

    perform_enqueued_jobs { send_audio }

    assert_response :success
    assert_equal "failed", Orm::CrmGeneration.last.status
    assert_equal 0, ActiveStorage::Blob.count
    assert_includes response.body, "L&#39;assistant n&#39;a pas répondu"
    assert_includes response.body, %(href="#{dictation_path}")
    assert_includes response.body, %(data-turbo-method="post")
  end

  test "without a configured model the dictation fails cleanly and the audio is gone" do
    perform_enqueued_jobs { send_audio }

    assert_equal "failed", Orm::CrmGeneration.last.status
    assert_equal "not_configured", Orm::CrmGeneration.last.error_code
    assert_equal 0, ActiveStorage::Blob.count
  end

  test "the polled generation shows the prefilled form frame once done" do
    done = finished_generation(Entities::Crm::DictationDraft.parse(ANSWER).to_content)

    get teams_generation_path(done.public_id), headers: { "Turbo-Frame" => "generation_#{done.public_id}" }

    assert_response :success
    assert_select "turbo-frame#generation_#{done.public_id} turbo-frame#dictation_prefill_#{done.public_id}[target=modal][src*='/dictation/new?generation=#{done.public_id}']"
  end

  test "the polled generation shows a retry once failed" do
    failed = finished_generation(nil)
    Orm::CrmGeneration.where(public_id: failed.public_id).update_all(status: "failed", error_code: "timeout", content: nil)

    get teams_generation_path(failed.public_id), headers: { "Turbo-Frame" => "generation_#{failed.public_id}" }

    assert_response :success
    assert_select "[role=alert]", text: /L'assistant n'a pas répondu/
    assert_select "a[href=?][data-turbo-method=post]", dictation_path, text: /Réessayer/
    assert_select "turbo-frame[id^=dictation_prefill_]", count: 0
  end

  test "CA-25: the prefilled form carries the dictation, escaped, with the source, and nothing is noted" do
    done = finished_generation(Entities::Crm::DictationDraft.parse(ANSWER).to_content)
    contact = Orm::CrmContact.create!(school_id: @school.id, full_name: "Mme Kouassi", position: "director", created_by: @field)

    assert_no_difference -> { Orm::CrmInteraction.count } do
      get new_teams_school_dictation_path(@school.public_id, generation: done.public_id), headers: { "Turbo-Frame" => "dictation_prefill_#{done.public_id}" }
    end

    assert_response :success
    assert_select "turbo-frame#dictation_prefill_#{done.public_id}[target=modal][data-prefilled]"
    assert_select "form#interaction-form[action='#{teams_school_interactions_path(@school.public_id)}']"
    assert_select "input[name='interaction[source]'][value=dictation]"
    assert_select "input[name='interaction[kind]'][value=call][checked]"
    assert_select "input[name='interaction[outcome]'][value=positive][checked]"
    assert_select "select[name='interaction[contact_public_id]'] option[value='#{contact.public_id}']", text: "Mme Kouassi"
    assert_select "input[name='interaction[contact_name]'][value='Mme Kouassi']"
    assert_select "input[name='interaction[next_step]'][value='Envoyer la plaquette']"
    assert_select "input[name='interaction[create_follow_up]'][checked]"
    assert_select "input[name='interaction[follow_up_due_on]'][value='#{Time.zone.today + 5}']"
    assert_select "textarea[name='interaction[note]']", text: /Directrice intéressée/
    assert_not_includes response.body, "<script>alert(1)"
    assert_select "p.bg-info-soft", text: /Pré-rempli par l'assistant : vérifiez avant d'enregistrer\./
    assert_select "button[type=submit][form=interaction-form]"
  end

  test "CA-27: an unstructured answer pre-fills the note only, with the warning" do
    done = finished_generation(Entities::Crm::DictationDraft.parse("J'ai vu la directrice, démo prévue.").to_content)

    get new_teams_school_dictation_path(@school.public_id, generation: done.public_id)

    assert_response :success
    assert_select "textarea[name='interaction[note]']", text: /J'ai vu la directrice, démo prévue\./
    assert_select "input[name='interaction[kind]'][checked]", count: 0
    assert_select "input[name='interaction[outcome]'][checked]", count: 0
    assert_select "input[name='interaction[create_follow_up]'][checked]", count: 0
    assert_select "p.bg-warning-soft", text: /L'assistant n'a pas su structurer : la transcription est dans la note\./
  end

  test "a generation of another school, a pending one or another kind is a 404" do
    other = finished_generation("{}", school: create_school)
    pending = @repository.create_pending(generation: Entities::Crm::Generation.new(
      public_id: nil, school_id: @school.id, kind: "dictation", status: "pending", requested_by_id: @field.id, follow_up_id: nil,
      input_fingerprint: nil, content: nil, error_code: nil, model: nil, input_tokens: nil, output_tokens: nil, duration_ms: nil
    )).value
    briefing = @repository.create_pending(generation: Entities::Crm::Generation.new(
      public_id: nil, school_id: @school.id, kind: "briefing", status: "pending", requested_by_id: @field.id, follow_up_id: nil,
      input_fingerprint: "a" * 64, content: nil, error_code: nil, model: nil, input_tokens: nil, output_tokens: nil, duration_ms: nil
    )).value
    @repository.complete(public_id: briefing.public_id, content: "x", model: "m", input_tokens: 1, output_tokens: 1, duration_ms: 1)

    [ other.public_id, pending.public_id, briefing.public_id, "inconnue" ].each do |id|
      get new_teams_school_dictation_path(@school.public_id, generation: id)
      assert_response :not_found, "generation #{id}"
    end
  end

  test "the card's dictation button opens the modal frame" do
    config = Rails.configuration.x.language_models
    original = config.api_key
    config.api_key = "sk-test"

    get teams_school_assistant_path(@school.public_id), headers: { "Turbo-Frame" => "school_crm_assistants" }

    assert_response :success
    assert_select "a[href='#{new_teams_school_dictation_path(@school.public_id)}'][data-turbo-frame=modal]"
  ensure
    config.api_key = original
  end
end
