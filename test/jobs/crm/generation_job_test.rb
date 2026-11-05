require "test_helper"

# ADR-XXXX (modèles de langage) §7: the base job calls the model, stores the result (model, tokens, duration), marks the
# generation failed with its error code, and purges the audio in both cases. Subclasses (Lots H-K) only supply the inputs.
module Crm
  class GenerationJobTest < ActiveSupport::TestCase
    class TestJob < Crm::GenerationJob
      cattr_accessor :model_double

      private

      def language_model = model_double
      def messages(_generation) = [ { role: "user", content: "Dis bonjour" } ]
      def max_tokens = 200
      def model_name = "fake/text"
    end

    setup do
      @repository = Repositories::Crm::GenerationRepository.new
      @school = create_school
      @user = create_team_member(team_role: "field")
      @fake = FakeLanguageModel.new("Bonjour", model: "fake/text", input_tokens: 7, output_tokens: 9)
      TestJob.model_double = @fake
    end

    def pending(kind: "briefing")
      @repository.create_pending(generation: Entities::Crm::Generation.new(
        public_id: nil, school_id: @school.id, kind:, status: "pending", requested_by_id: @user.id, follow_up_id: nil,
        input_fingerprint: nil, content: nil, error_code: nil, model: nil, input_tokens: nil, output_tokens: nil, duration_ms: nil
      )).value
    end

    test "success completes the generation with the text, model, tokens and duration" do
      generation = pending

      TestJob.perform_now(generation.public_id)

      done = @repository.find_by_public_id(public_id: generation.public_id)
      assert done.done?
      assert_equal [ "Bonjour", "fake/text", 7, 9, 5 ], done.to_h.values_at(:content, :model, :input_tokens, :output_tokens, :duration_ms)
      assert_equal [ { role: "user", content: "Dis bonjour" } ], @fake.calls.last[:messages]
      assert_equal [ "fake/text", 200 ], @fake.calls.last.values_at(:model, :max_tokens)
    end

    test "each failure reason marks the generation failed with that error code" do
      %i[not_configured timeout provider_error invalid_response].each do |reason|
        generation = pending
        @fake.fail_with(reason)

        TestJob.perform_now(generation.public_id)

        failed = @repository.find_by_public_id(public_id: generation.public_id)
        assert failed.failed?, reason
        assert_equal reason.to_s, failed.error_code
        assert_kind_of Integer, failed.duration_ms
      end
    end

    test "an empty or unreadable text from the model is recorded invalid_response, not provider_error" do
      generation = pending
      TestJob.model_double = FakeLanguageModel.new("   ", model: "fake/text", input_tokens: 1, output_tokens: 0)

      TestJob.perform_now(generation.public_id)

      assert_equal "invalid_response", @repository.find_by_public_id(public_id: generation.public_id).error_code
    end

    test "a text the subclass cannot read is recorded invalid_response" do
      picky = Class.new(TestJob) { def content_for(_text) = raise(ArgumentError, "illisible") }
      generation = pending

      picky.perform_now(generation.public_id)

      failed = @repository.find_by_public_id(public_id: generation.public_id)
      assert failed.failed?
      assert_equal "invalid_response", failed.error_code
    end

    test "an unexpected error marks the generation failed instead of leaving it pending" do
      generation = pending
      @fake.define_singleton_method(:complete) { |**| raise "boom" }

      TestJob.perform_now(generation.public_id)

      failed = @repository.find_by_public_id(public_id: generation.public_id)
      assert failed.failed?
      assert_equal "provider_error", failed.error_code
    end

    test "a generation that is no longer pending is left alone" do
      generation = pending
      @repository.complete(public_id: generation.public_id, content: "Déjà", model: "m", input_tokens: 1, output_tokens: 1, duration_ms: 1)

      TestJob.perform_now(generation.public_id)

      assert_empty @fake.calls
      assert_equal "Déjà", @repository.find_by_public_id(public_id: generation.public_id).content
    end

    test "an unknown generation is ignored" do
      assert_nothing_raised { TestJob.perform_now("unknown-public") }
      assert_empty @fake.calls
    end

    test "the audio is sent to the model then purged, on success" do
      generation = pending(kind: "dictation")
      attach_audio(generation)

      TestJob.perform_now(generation.public_id)

      assert_equal({ data: "OCTETS".b, format: "webm" }, @fake.calls.last[:audio])
      assert_not Orm::CrmGeneration.find_by(public_id: generation.public_id).audio.attached?
    end

    test "the audio is purged on failure too" do
      generation = pending(kind: "dictation")
      attach_audio(generation)
      @fake.fail_with(:timeout)

      TestJob.perform_now(generation.public_id)

      assert_not Orm::CrmGeneration.find_by(public_id: generation.public_id).audio.attached?
      assert @repository.find_by_public_id(public_id: generation.public_id).failed?
    end

    test "an unknown failure reason is stored as a provider error" do
      generation = pending
      @fake.fail_with(:something_else)

      TestJob.perform_now(generation.public_id)

      assert_equal "provider_error", @repository.find_by_public_id(public_id: generation.public_id).error_code
    end

    test "a subclass must supply messages, model and max tokens" do
      bare = Class.new(Crm::GenerationJob)
      job = bare.new

      assert_raises(NotImplementedError) { job.send(:messages, nil) }
      assert_raises(NotImplementedError) { job.send(:model_name) }
      assert_raises(NotImplementedError) { job.send(:max_tokens) }
      assert_not job.send(:json?)
      assert_kind_of Crm::OpenRouterLanguageModel, job.send(:language_model)
    end

    private

    def attach_audio(generation)
      Orm::CrmGeneration.find_by(public_id: generation.public_id).audio.attach(io: StringIO.new("OCTETS"), filename: "dictee.webm", content_type: "audio/webm")
    end
  end
end
