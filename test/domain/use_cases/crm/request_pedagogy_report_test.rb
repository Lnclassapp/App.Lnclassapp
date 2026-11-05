require "test_helper"

# CA-29, CA-30 (ADR-XXXX modèles de langage) : sans activité sur 30 jours, aucune génération et aucun appel au modèle ; avec activité,
# la synthèse est mise en file, ou réaffichée si les chiffres n'ont pas changé.
module UseCases
  module Crm
    class RequestPedagogyReportTest < ActiveSupport::TestCase
      class FakeGenerations
        include Ports::Crm::GenerationRepositoryPort

        attr_reader :rows

        def initialize = @rows = []

        def create_pending(generation:)
          return Shared::Result.failure(:conflict) if pending_for(school_id: generation.school_id, kind: generation.kind)

          row = generation.with(public_id: "gen-#{@rows.size + 1}")
          @rows << row
          Shared::Result.success(row)
        end

        def find_by_public_id(public_id:) = @rows.find { it.public_id == public_id }
        def pending_for(school_id:, kind:) = @rows.find { it.school_id == school_id && it.kind == kind && it.pending? }

        def latest_done(school_id:, kind:, input_fingerprint:)
          @rows.reverse.find { it.done? && it.school_id == school_id && it.kind == kind && it.input_fingerprint == input_fingerprint }
        end

        def complete(public_id:, content:, **) = update(public_id, status: "done", content:)
        def mark_failed(public_id:, error_code:, duration_ms:) = update(public_id, status: "failed", error_code:)

        private

        def update(public_id, **changes)
          index = @rows.index { it.public_id == public_id }
          @rows[index] = @rows[index].with(**changes)
          Shared::Result.success(@rows[index])
        end
      end

      class FakeInputs
        attr_accessor :prompt
        attr_reader :calls

        def initialize(prompt) = (@prompt = prompt; @calls = 0)

        def call(public_id:)
          @calls += 1
          prompt if public_id == "school-pub"
        end
      end

      def build_prompt(students: 5, assignments: 2)
        Entities::Crm::PedagogyReportPrompt.new(school_id: 7, active_students_count: students, assignments_count: assignments, submission_rate: 50,
                                                average_percent: 70, subjects: [], gaps: [])
      end

      def actor(team_role = "field") = Entities::Identity::Actor.new(user_id: 4, role: :team, team_role:)

      setup do
        @generations = FakeGenerations.new
        @inputs = FakeInputs.new(build_prompt)
        @enqueued = []
        @accepting = true
        @use_case = RequestPedagogyReport.new(generations: @generations, inputs: @inputs, policy: Policies::Crm::ManageCrmPolicy.new,
                                              enqueue: ->(public_id) { @enqueued << public_id; @accepting })
      end

      def request(actor: self.actor) = @use_case.call(actor:, school_public_id: "school-pub")

      test "CA-29: a pending report is created with the fingerprint of the figures and its job is enqueued" do
        result = request

        assert result.success?
        assert_not result.value.reused
        generation = result.value.generation
        assert_equal [ "pedagogy_report", "pending", 4, 7, @inputs.prompt.fingerprint ],
                     generation.to_h.values_at(:kind, :status, :requested_by_id, :school_id, :input_fingerprint)
        assert_equal [ generation.public_id ], @enqueued
      end

      test "CA-30: a school without activity creates nothing and never calls the model" do
        @inputs.prompt = build_prompt(students: 0, assignments: 0)

        result = request

        assert result.success?
        assert result.value.no_activity?
        assert_nil result.value.generation
        assert_empty @generations.rows
        assert_empty @enqueued
      end

      test "a second request with the same figures shows the last synthesis and enqueues nothing" do
        first = request.value.generation
        @generations.complete(public_id: first.public_id, content: "Synthèse")
        @enqueued.clear

        second = request

        assert second.value.reused
        assert_equal first.public_id, second.value.generation.public_id
        assert_empty @enqueued
      end

      test "a changed figure makes a new synthesis" do
        first = request.value.generation
        @generations.complete(public_id: first.public_id, content: "Synthèse")
        @inputs.prompt = build_prompt(students: 6)

        second = request

        assert_not second.value.reused
        assert_not_equal first.public_id, second.value.generation.public_id
      end

      test "a failed synthesis is not reused" do
        first = request.value.generation
        @generations.mark_failed(public_id: first.public_id, error_code: "timeout", duration_ms: 1)

        assert_not request.value.reused
        assert_equal 2, @enqueued.size
      end

      test "a synthesis already running is shown, not started twice" do
        first = request.value.generation

        second = request

        assert_equal first.public_id, second.value.generation.public_id
        assert_equal 1, @enqueued.size
      end

      test "when the queue refuses the job the generation is marked failed" do
        @accepting = false

        assert_equal "provider_error", request.value.generation.error_code
      end

      test "content and the visitor are forbidden before anything is read" do
        [ actor("content"), nil ].each { |someone| assert_equal :forbidden, request(actor: someone).code }
        assert_equal 0, @inputs.calls
        assert_empty @generations.rows
      end

      test "an unknown school is :not_found" do
        assert_equal :not_found, @use_case.call(actor:, school_public_id: "nope").code
      end
    end
  end
end
