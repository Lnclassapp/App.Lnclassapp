require "test_helper"

# CA-25, CA-27 (ADR-XXXX modèles de langage) : le job envoie l'audio et la consigne fixe au modèle audio, garde le brouillon sous
# schéma fermé ; l'enregistrement est purgé du stockage en succès, en échec du modèle et même si l'appel lève une exception.
module Crm
  class DictationJobTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    class TestJob < Crm::DictationJob
      cattr_accessor :model_double

      private

      def language_model = model_double
    end

    class ExplodingModel
      def complete(**) = raise(IOError, "connexion coupée")
    end

    ANSWER = { kind: "visit", outcome: "positive", contact_name: "Mme Kouassi", next_step: "Revenir avec la plaquette", note: "Visite réussie.",
               follow_up_in_days: 7 }.to_json

    setup do
      @repository = Repositories::Crm::GenerationRepository.new
      @school = create_school
      @user = create_team_member(team_role: "field")
      @fake = FakeLanguageModel.new(ANSWER, model: "fake/audio")
      TestJob.model_double = @fake
    end

    # Remplace une méthode d'un objet le temps du bloc, puis la restaure (le projet n'utilise pas minitest/mock).
    def with_replaced(target, name, value)
      own = target.singleton_class.instance_method(name) if target.singleton_class.method_defined?(name, false)
      target.define_singleton_method(name) { |*, **, &| value }
      yield
    ensure
      target.singleton_class.send(:remove_method, name)
      target.singleton_class.send(:define_method, name, own) if own
    end

    def with_raising(target, name, &)
      with_replaced(target, name, nil) { raise_in(target, name, &) }
    end

    def raise_in(target, name)
      target.define_singleton_method(name) { |*, **, &| raise IOError, "indisponible" }
      yield
    end

    def pending
      @repository.create_pending(generation: Entities::Crm::Generation.new(
        public_id: nil, school_id: @school.id, kind: "dictation", status: "pending", requested_by_id: @user.id, follow_up_id: nil,
        input_fingerprint: nil, content: nil, error_code: nil, model: nil, input_tokens: nil, output_tokens: nil, duration_ms: nil
      )).value
    end

    def attach_audio(generation, bytes: "WEBM-bytes", type: "audio/webm")
      Orm::CrmGeneration.find_by!(public_id: generation.public_id).audio.attach(io: StringIO.new(bytes), filename: "dictation", content_type: type, identify: false)
    end

    def audio_attached?(generation) = Orm::CrmGeneration.find_by!(public_id: generation.public_id).audio.attached?

    test "the model gets the audio, the fixed prompt and no school data, and the answer is stored as a structured draft" do
      generation = pending
      attach_audio(generation, bytes: "WEBM-bytes", type: "audio/webm")

      TestJob.perform_now(generation.public_id)

      done = @repository.find_by_public_id(public_id: generation.public_id)
      assert done.done?
      draft = Entities::Crm::DictationDraft.from_content(done.content)
      assert draft.structured
      assert_equal "visit", draft.kind
      assert_equal 7, draft.follow_up_in_days
      call = @fake.calls.last
      assert_equal Rails.configuration.x.language_models.model_audio, call[:model]
      assert call[:json]
      assert_equal({ data: "WEBM-bytes", format: "webm" }, call[:audio])
      assert_not_includes call[:messages].map { it[:content] }.join, @school.name
    end

    test "an ogg or mp4 recording is sent under its format" do
      { "audio/ogg" => "ogg", "audio/mp4" => "mp4" }.each do |type, format|
        TestJob.model_double = FakeLanguageModel.new(ANSWER)
        generation = pending
        attach_audio(generation, type:)

        TestJob.perform_now(generation.public_id)

        assert_equal format, TestJob.model_double.calls.last[:audio][:format]
        Orm::CrmGeneration.find_by!(public_id: generation.public_id).update!(status: "done")
      end
    end

    test "CA-27: an unstructured answer is kept as the raw transcription in the note" do
      generation = pending
      attach_audio(generation)
      @fake.respond_with("J'ai vu la directrice, elle veut une démo.")

      TestJob.perform_now(generation.public_id)

      done = @repository.find_by_public_id(public_id: generation.public_id)
      assert done.done?
      draft = Entities::Crm::DictationDraft.from_content(done.content)
      assert_not draft.structured
      assert_equal "J'ai vu la directrice, elle veut une démo.", draft.note
    end

    test "CA-25: the audio is gone from the storage after a successful run" do
      generation = pending
      attach_audio(generation)
      assert_difference -> { ActiveStorage::Blob.count }, -1 do
        TestJob.perform_now(generation.public_id)
      end

      assert_not audio_attached?(generation)
    end

    test "CA-25: the audio is gone after a model failure" do
      generation = pending
      attach_audio(generation)
      @fake.fail_with(:timeout)

      TestJob.perform_now(generation.public_id)

      assert @repository.find_by_public_id(public_id: generation.public_id).failed?
      assert_not audio_attached?(generation)
      assert_equal 0, ActiveStorage::Blob.count
    end

    test "CA-25: the audio is gone even when the call raises" do
      generation = pending
      attach_audio(generation)
      TestJob.model_double = ExplodingModel.new

      assert_raises(IOError) { TestJob.perform_now(generation.public_id) }

      failed = @repository.find_by_public_id(public_id: generation.public_id)
      assert failed.failed?
      assert_equal "provider_error", failed.error_code
      assert_not audio_attached?(generation)
    end

    test "submit attaches the recording under a fixed name and enqueues the job" do
      generation = pending
      upload = UseCases::Crm::SubmitDictation::Upload.new(io: StringIO.new("OggS-bytes"), byte_size: 10, content_type: "audio/ogg")

      assert_enqueued_with(job: Crm::DictationJob, args: [ generation.public_id ]) do
        assert_equal true, Crm::DictationJob.submit(generation.public_id, upload)
      end

      attachment = Orm::CrmGeneration.find_by!(public_id: generation.public_id).audio
      assert_equal "audio/ogg", attachment.content_type
      assert_equal "OggS-bytes", attachment.download
      assert_equal "dictation.ogg", attachment.filename.to_s
      # Le serveur ne décode jamais l'audio : la pièce est marquée « déjà analysée », Active Storage ne lance donc ni ffprobe ni analyse.
      assert attachment.blob.analyzed?
    end

    test "submit keeps nothing when the queue refuses" do
      generation = pending
      upload = UseCases::Crm::SubmitDictation::Upload.new(io: StringIO.new("OggS-bytes"), byte_size: 10, content_type: "audio/ogg")

      refusing = Class.new(Crm::DictationJob) { def self.perform_later(*) = false }

      assert_equal false, refusing.submit(generation.public_id, upload)

      assert_not audio_attached?(generation)
      assert_equal 0, ActiveStorage::Blob.count
    end

    test "submit purges the blob it created when attaching it raises" do
      generation = pending
      upload = UseCases::Crm::SubmitDictation::Upload.new(io: StringIO.new("OggS-bytes"), byte_size: 10, content_type: "audio/ogg")
      record = Orm::CrmGeneration.find_by!(public_id: generation.public_id)
      audio = Object.new
      audio.define_singleton_method(:attach) { |_blob| raise IOError, "disque plein" }
      audio.define_singleton_method(:attached?) { false }
      before = ActiveStorage::Blob.count

      with_replaced(record, :audio, audio) do
        with_replaced(Orm::CrmGeneration, :find_by!, record) do
          assert_equal false, Crm::DictationJob.submit(generation.public_id, upload)
        end
      end

      assert_equal before, ActiveStorage::Blob.count
      assert_no_enqueued_jobs
    end

    test "submit logs the blob key when even the purge of the blob fails" do
      generation = pending
      upload = UseCases::Crm::SubmitDictation::Upload.new(io: StringIO.new("OggS-bytes"), byte_size: 10, content_type: "audio/ogg")
      record = Orm::CrmGeneration.find_by!(public_id: generation.public_id)
      audio = Object.new
      audio.define_singleton_method(:attach) { |_blob| raise IOError, "disque plein" }
      audio.define_singleton_method(:attached?) { false }
      io = StringIO.new
      original = Rails.logger
      Rails.logger = ActiveSupport::Logger.new(io)

      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("x"), filename: "d.ogg", content_type: "audio/ogg", identify: false)
      blob.define_singleton_method(:purge) { raise IOError, "stockage coupé" }
      with_replaced(ActiveStorage::Blob, :create_and_upload!, blob) do
        with_replaced(record, :audio, audio) do
          with_replaced(Orm::CrmGeneration, :find_by!, record) { Crm::DictationJob.submit(generation.public_id, upload) }
        end
      end

      assert_includes io.string, blob.key
    ensure
      Rails.logger = original
    end

    test "submit purges the attached recording when enqueuing raises" do
      generation = pending
      upload = UseCases::Crm::SubmitDictation::Upload.new(io: StringIO.new("OggS-bytes"), byte_size: 10, content_type: "audio/ogg")

      with_raising(Crm::DictationJob, :perform_later) do
        assert_equal false, Crm::DictationJob.submit(generation.public_id, upload)
      end

      assert_not audio_attached?(generation)
      assert_equal 0, ActiveStorage::Blob.count
    end

    test "submit logs an empty key when no blob exists and the purge of the attachment fails" do
      generation = pending
      upload = UseCases::Crm::SubmitDictation::Upload.new(io: StringIO.new("OggS-bytes"), byte_size: 10, content_type: "audio/ogg")
      record = Orm::CrmGeneration.find_by!(public_id: generation.public_id)
      audio = Object.new
      audio.define_singleton_method(:attached?) { true }
      audio.define_singleton_method(:purge) { raise IOError, "stockage coupé" }
      io = StringIO.new
      original = Rails.logger
      Rails.logger = ActiveSupport::Logger.new(io)

      with_raising(ActiveStorage::Blob, :create_and_upload!) do
        with_replaced(record, :audio, audio) do
          with_replaced(Orm::CrmGeneration, :find_by!, record) { assert_equal false, Crm::DictationJob.submit(generation.public_id, upload) }
        end
      end

      assert_includes io.string, "purge impossible, blob  : IOError"
    ensure
      Rails.logger = original
    end

    test "submit keeps nothing and says no for an unknown generation or a type it does not store" do
      generation = pending
      wav = UseCases::Crm::SubmitDictation::Upload.new(io: StringIO.new("RIFF"), byte_size: 4, content_type: "audio/wav")
      ogg = UseCases::Crm::SubmitDictation::Upload.new(io: StringIO.new("OggS"), byte_size: 4, content_type: "audio/ogg")

      assert_equal false, Crm::DictationJob.submit(generation.public_id, wav)
      assert_equal false, Crm::DictationJob.submit("inconnue", ogg)

      assert_not audio_attached?(generation)
      assert_equal 0, ActiveStorage::Blob.count
      assert_no_enqueued_jobs
    end
  end
end
