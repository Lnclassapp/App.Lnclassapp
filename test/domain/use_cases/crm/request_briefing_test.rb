require "test_helper"

# CA-22 (ADR-XXXX modèles de langage) : « Préparer l'appel » crée une génération et met le job en file ; un second clic sans nouvel
# échange (même empreinte) réaffiche la dernière fiche sans rappeler le modèle ; une génération déjà en cours n'en lance pas une autre.
module UseCases
  module Crm
    class RequestBriefingTest < ActiveSupport::TestCase
      class FakeGenerations
        include Ports::Crm::GenerationRepositoryPort

        attr_reader :rows

        def initialize = @rows = []

        def create_pending(generation:)
          return Shared::Result.failure(:conflict) if conflict_only
          return Shared::Result.failure(:conflict) if pending_for(school_id: generation.school_id, kind: generation.kind)

          row = generation.with(public_id: "gen-#{@rows.size + 1}")
          @rows << row
          Shared::Result.success(row)
        end

        def find_by_public_id(public_id:) = @rows.find { it.public_id == public_id }
        def pending_for(school_id:, kind:) = conflict_only ? nil : @rows.find { it.school_id == school_id && it.kind == kind && it.pending? }

        def latest_done(school_id:, kind:, input_fingerprint:)
          return nil if input_fingerprint.blank?

          @rows.reverse.find { it.done? && it.school_id == school_id && it.kind == kind && it.input_fingerprint == input_fingerprint }
        end

        def complete(public_id:, content:, **) = update(public_id, status: "done", content:)
        attr_accessor :unwritable, :conflict_only

        def fail_stale(school_id:, kind:, before:)
          stale = @rows.select { it.pending? && it.school_id == school_id && it.kind == kind && it.created_at && it.created_at < before }
          stale.each { |row| @rows[@rows.index(row)] = row.with(status: "failed", error_code: "timeout") }
          stale.size
        end

        def mark_failed(public_id:, error_code:, duration_ms:)
          return Shared::Result.failure(:not_found) if unwritable

          update(public_id, status: "failed", error_code:)
        end

        private

        def update(public_id, **changes)
          index = @rows.index { it.public_id == public_id }
          @rows[index] = @rows[index].with(**changes)
          Shared::Result.success(@rows[index])
        end
      end

      class FakeInputs
        attr_accessor :prompt

        def initialize(prompt) = @prompt = prompt
        def call(public_id:) = (prompt if public_id == "school-pub")
      end

      def build_prompt(students: 5)
        Entities::Crm::BriefingPrompt.new(school_id: 7, school_name: "Lycée", drena_name: "Abidjan 1", stage: "prospect", accounts_count: 1,
                                          active_students_count: students, last_activity_on: nil, contact_positions: [], interactions: [], follow_ups: [])
      end

      def actor(team_role = "field") = Entities::Identity::Actor.new(user_id: 4, role: :team, team_role:)

      setup do
        @generations = FakeGenerations.new
        @inputs = FakeInputs.new(build_prompt)
        @enqueued = []
        @accepting = true
        @use_case = RequestBriefing.new(generations: @generations, inputs: @inputs, policy: Policies::Crm::ManageCrmPolicy.new,
                                        enqueue: ->(public_id) { @enqueued << public_id; @accepting }, logger: Logger.new(@log = StringIO.new))
      end

      def request(actor: self.actor) = @use_case.call(actor:, school_public_id: "school-pub")

      test "a pending briefing is created with the fingerprint of the inputs and its job is enqueued" do
        result = request

        assert result.success?
        assert_not result.value.reused
        generation = result.value.generation
        assert_equal [ "briefing", "pending", 4, 7, @inputs.prompt.fingerprint ],
                     generation.to_h.values_at(:kind, :status, :requested_by_id, :school_id, :input_fingerprint)
        assert_equal [ generation.public_id ], @enqueued
      end

      test "CA-22: a second request without any new exchange shows the last briefing and does not call the model again" do
        first = request.value.generation
        @generations.complete(public_id: first.public_id, content: "Ligne 1", model: "m", input_tokens: 1, output_tokens: 1, duration_ms: 1)
        @enqueued.clear

        second = request

        assert second.value.reused
        assert_equal first.public_id, second.value.generation.public_id
        assert_empty @enqueued
        assert_equal 1, @generations.rows.size
      end

      test "a changed fact makes a new briefing" do
        first = request.value.generation
        @generations.complete(public_id: first.public_id, content: "Ligne 1", model: "m", input_tokens: 1, output_tokens: 1, duration_ms: 1)
        @inputs.prompt = build_prompt(students: 6)

        second = request

        assert_not second.value.reused
        assert_not_equal first.public_id, second.value.generation.public_id
        assert_equal 2, @enqueued.size
      end

      test "a failed briefing is not reused: the user retries and the model is called" do
        first = request.value.generation
        @generations.mark_failed(public_id: first.public_id, error_code: "timeout", duration_ms: 1)

        assert_not request.value.reused
        assert_equal 2, @enqueued.size
      end

      test "a briefing already running is shown, not started twice" do
        first = request.value.generation

        second = request

        assert second.success?
        assert_equal first.public_id, second.value.generation.public_id
        assert_equal 1, @enqueued.size
      end

      test "when the queue refuses the job the generation is marked failed" do
        @accepting = false

        result = request

        assert result.success?
        assert_equal "provider_error", @generations.find_by_public_id(public_id: result.value.generation.public_id).error_code
      end

      test "content, teacher and the visitor are forbidden and nothing is created" do
        [ actor("content"), nil ].each do |someone|
          assert_equal :forbidden, request(actor: someone).code
        end
        assert_empty @generations.rows
        assert_empty @enqueued
      end

      test "an unknown school is :not_found" do
        assert_equal :not_found, @use_case.call(actor:, school_public_id: "nope").code
      end

      test "a stale pending generation is closed and a new request goes through" do
        first = request.value.generation
        index = @generations.rows.index { it.public_id == first.public_id }
        @generations.rows[index] = first.with(created_at: 10.minutes.ago)
        @enqueued.clear

        result = request

        assert result.success?
        assert_not_equal first.public_id, result.value.generation.public_id
        assert_equal "timeout", @generations.find_by_public_id(public_id: first.public_id).error_code
        assert_equal [ result.value.generation.public_id ], @enqueued
      end

      test "when the queue refuses and the failure cannot be written, the request is unavailable and the ids are logged" do
        @accepting = false
        @generations.unwritable = true

        result = request

        assert_equal :unavailable, result.code
        assert_equal :provider_error, result.errors[:reason]
        assert_includes @log.string, "gen-1"
        assert_includes @log.string, "provider_error"
      end

      test "without a logger, an unwritable refusal is still unavailable" do
        @use_case.instance_variable_set(:@logger, nil)
        @accepting = false
        @generations.unwritable = true

        assert_equal :unavailable, request.code
      end

      test "a conflict with no pending row to show is a :conflict" do
        @generations.conflict_only = true

        assert_equal :conflict, request.code
      end
    end
  end
end
