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

    test "an unexpected error marks the generation failed, is logged without the prompt, and is re-raised" do
      generation = pending
      @fake.define_singleton_method(:complete) { |**| raise "boom" }
      logged = capture_log { assert_raises(RuntimeError) { TestJob.perform_now(generation.public_id) } }

      failed = @repository.find_by_public_id(public_id: generation.public_id)
      assert failed.failed?
      assert_equal "provider_error", failed.error_code
      assert_includes logged, "RuntimeError"
      assert_includes logged, "boom"
      assert_not_includes logged, "Dis bonjour"
    end

    test "a bug in the inputs query is a failed generation and the exception reaches the queue" do
      buggy = Class.new(TestJob) { def messages(_generation) = nil.unknown_method }
      generation = pending

      assert_raises(NoMethodError) { buggy.perform_now(generation.public_id) }

      assert_equal "provider_error", @repository.find_by_public_id(public_id: generation.public_id).error_code
    end

    test "a bug in content_for is not an invalid_response: failed as provider_error and re-raised" do
      buggy = Class.new(TestJob) { def content_for(_text) = nil.unknown_method }
      generation = pending

      assert_raises(NoMethodError) { buggy.perform_now(generation.public_id) }

      assert_equal "provider_error", @repository.find_by_public_id(public_id: generation.public_id).error_code
    end

    test "an ArgumentError from messages (a school without activity) is an invalid_response and is not re-raised" do
      quiet = Class.new(TestJob) { def messages(_generation) = raise(ArgumentError, "école sans activité") }
      generation = pending

      assert_nothing_raised { quiet.perform_now(generation.public_id) }

      assert_equal "invalid_response", @repository.find_by_public_id(public_id: generation.public_id).error_code
      assert_empty @fake.calls
    end

    test "a second job on a finished generation does not overwrite it, and still purges the audio" do
      generation = pending(kind: "dictation")
      attach_audio(generation)
      @repository.complete(public_id: generation.public_id, content: "Déjà", model: "m", input_tokens: 1, output_tokens: 1, duration_ms: 1)

      TestJob.perform_now(generation.public_id)

      assert_empty @fake.calls
      assert_equal "Déjà", @repository.find_by_public_id(public_id: generation.public_id).content
      assert_not Orm::CrmGeneration.find_by(public_id: generation.public_id).audio.attached?
    end

    test "a result arriving after the generation was closed is ignored" do
      generation = pending
      repository = @repository
      @fake.define_singleton_method(:complete) do |**|
        repository.mark_failed(public_id: generation.public_id, error_code: "timeout", duration_ms: 1)
        Shared::Result.success({ text: "Tard", model: "m", input_tokens: 1, output_tokens: 1, duration_ms: 1 })
      end

      TestJob.perform_now(generation.public_id)

      assert_equal "timeout", @repository.find_by_public_id(public_id: generation.public_id).error_code
    end

    test "a failing purge is logged with the public id and raised" do
      generation = pending(kind: "dictation")
      attach_audio(generation)

      logged = capture_log { with_failing_purge(generation) { assert_raises(IOError) { TestJob.perform_now(generation.public_id) } } }

      assert_includes logged, generation.public_id
      assert @repository.find_by_public_id(public_id: generation.public_id).done?
    end

    test "a failing purge never hides the original exception" do
      generation = pending(kind: "dictation")
      attach_audio(generation)
      @fake.define_singleton_method(:complete) { |**| raise ArgumentError, "origine" }

      logged = capture_log do
        with_failing_purge(generation) do
          error = assert_raises(ArgumentError) { TestJob.perform_now(generation.public_id) }
          assert_equal "origine", error.message
        end
      end

      assert_includes logged, generation.public_id
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

    def capture_log
      io = StringIO.new
      original = Rails.logger
      Rails.logger = ActiveSupport::Logger.new(io)
      yield
      io.string
    ensure
      Rails.logger = original
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

    def with_failing_purge(generation, &block)
      record = Orm::CrmGeneration.find_by(public_id: generation.public_id)
      audio = Object.new
      audio.define_singleton_method(:attached?) { true }
      audio.define_singleton_method(:content_type) { "audio/webm" }
      audio.define_singleton_method(:download) { "OCTETS" }
      audio.define_singleton_method(:purge) { raise IOError, "disque" }
      with_replaced(record, :audio, audio) { with_replaced(Orm::CrmGeneration, :find_by, record, &block) }
    end

    test "audio_for is nil for an unknown generation or one without a recording" do
      job = TestJob.new

      assert_nil job.send(:audio_for, "inconnue")
      assert_nil job.send(:audio_for, pending.public_id)
    end

    test "log_bug writes the class and message even for an error that has no backtrace" do
      io = StringIO.new
      sink = Logger.new(io)
      Rails.logger.broadcast_to(sink)
      TestJob.new.send(:log_bug, "gen-1", RuntimeError.new("boom"))
      Rails.logger.stop_broadcasting_to(sink)

      assert_includes io.string, "gen-1 : RuntimeError: boom ()"
    end

    test "when the failure itself cannot be written, close_as_failed logs the class and does not raise" do
      job = TestJob.new
      broken = Object.new
      broken.define_singleton_method(:mark_failed) { |**| raise IOError, "base coupée" }
      job.define_singleton_method(:repository) { broken }
      io = StringIO.new
      sink = Logger.new(io)
      Rails.logger.broadcast_to(sink)
      job.send(:close_as_failed, "gen-1", 5)
      Rails.logger.stop_broadcasting_to(sink)

      assert_includes io.string, "gen-1 : mark_failed impossible (IOError)"
    end

    def attach_audio(generation)
      Orm::CrmGeneration.find_by(public_id: generation.public_id).audio.attach(io: StringIO.new("OCTETS"), filename: "dictee.webm", content_type: "audio/webm")
    end
  end
end
