require "test_helper"

# CA-11 (ADR-XXXX contexte crm, UDR-XXXX bloc « Suivi ») : noter un échange, avec en option la relance proposée,
# créée dans la même transaction. Domaine pur : dépôts factices, horloge fixe.
module UseCases
  module Crm
    class RecordInteractionTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 11, 5, 10)
      Clock = Data.define(:now)
      Actor = Data.define(:user_id, :team_role) do
        def team? = true
      end

      class FakeInteractions
        include Ports::Crm::InteractionRepositoryPort

        attr_reader :created, :contact_public_ids

        def initialize
          @created = []
          @contact_public_ids = []
        end

        def create(interaction:, contact_public_id: nil)
          stored = interaction.with(public_id: "int-#{@created.size + 1}")
          @created << stored
          @contact_public_ids << contact_public_id
          Shared::Result.success(stored)
        end
      end

      class FakeFollowUps
        include Ports::Crm::FollowUpRepositoryPort

        attr_reader :created, :interaction_public_ids

        def initialize
          @created = []
          @interaction_public_ids = []
        end

        def create(follow_up:, interaction_public_id: nil)
          @created << follow_up
          @interaction_public_ids << interaction_public_id
          Shared::Result.success(follow_up.with(public_id: "fup-#{@created.size}"))
        end
      end

      class FakeTransaction
        include Ports::Shared::TransactionPort

        attr_reader :rolled_back

        def call = yield

        # Comme la vraie : une exception qui n'est pas un refus de la base annule tout et remonte.
        def attempt
          Shared::Result.success(yield)
        rescue StandardError
          @rolled_back = true
          raise
        end
      end

      class RefusingFollowUps
        include Ports::Crm::FollowUpRepositoryPort

        def create(follow_up:, interaction_public_id: nil) = Shared::Result.failure(:not_found)
      end

      class RefusingInteractions
        include Ports::Crm::InteractionRepositoryPort

        def create(interaction:, contact_public_id: nil) = Shared::Result.failure(:not_found)
      end

      class ConflictingTransaction
        include Ports::Shared::TransactionPort

        def attempt = Shared::Result.failure(:conflict)
      end

      setup do
        @interactions = FakeInteractions.new
        @follow_ups = FakeFollowUps.new
        @transaction = FakeTransaction.new
        @use_case = RecordInteraction.new(interactions: @interactions, follow_ups: @follow_ups,
                                          policy: Policies::Crm::ManageCrmPolicy.new, transaction: @transaction,
                                          clock: Clock.new(now: NOW))
        @actor = Actor.new(user_id: 7, team_role: "field")
      end

      def call(**overrides)
        @use_case.call(actor: @actor, school_id: 31, kind: "call", outcome: "positive", note: "Directrice intéressée", **overrides)
      end

      test "CA-11: a positive call is recorded with its author, a default date of now and the manual source" do
        result = call

        assert result.success?
        interaction = result.value.interaction
        assert_nil result.value.follow_up
        assert_equal [ 31, 7, "call", "positive", "Directrice intéressée", "manual", NOW ],
                     [ interaction.school_id, interaction.author_id, interaction.kind, interaction.outcome, interaction.note,
                       interaction.source, interaction.occurred_at ]
        assert_equal [ interaction ], @interactions.created
        assert_empty @follow_ups.created
      end

      test "the interlocutor, next step and dictation source are kept, blanks become nil" do
        result = call(contact_public_id: "ctc-4", contact_name: "Mme Kouassi", next_step: " Envoyer la plaquette ", note: " ", source: "dictation")

        interaction = result.value.interaction
        assert_equal [ "Mme Kouassi", "Envoyer la plaquette", nil, "dictation" ],
                     [ interaction.contact_name, interaction.next_step, interaction.note, interaction.source ]
        assert_equal [ "ctc-4" ], @interactions.contact_public_ids
      end

      test "a follow-up is created open, for the same school, in the same call" do
        call(follow_up: { due_on: Date.new(2026, 11, 8), assignee_id: 7, reason: "Envoyer la plaquette" })

        follow_up = @follow_ups.created.sole
        assert_equal [ 31, 7, Date.new(2026, 11, 8), "Envoyer la plaquette", "open", 7, nil ],
                     [ follow_up.school_id, follow_up.assignee_id, follow_up.due_on, follow_up.reason, follow_up.status,
                       follow_up.created_by_id, follow_up.interaction_id ]
      end

      test "the follow-up proposed by an interaction is linked to it by the interaction's public id" do
        call(follow_up: { due_on: Date.new(2026, 11, 8), assignee_id: 7, reason: "Envoyer la plaquette" })

        assert_equal [ "int-1" ], @follow_ups.interaction_public_ids
      end

      test "a follow-up dated in the past is refused and nothing is written" do
        result = call(follow_up: { due_on: Date.new(2026, 11, 4), assignee_id: 7, reason: "x" })

        assert result.failure?
        assert_equal :invalid, result.code
        assert_equal [ :invalid ], result.errors[:follow_up_due_on]
        assert_empty @interactions.created
        assert_empty @follow_ups.created
      end

      test "unknown kind, outcome or source, an over-long note or next step, a future date are refused" do
        { kind: "email", outcome: "great", source: "import", note: "a" * 2001, next_step: "a" * 201,
          occurred_at: NOW + 2.days }.each do |field, value|
          result = call(field => value)

          assert_equal :invalid, result.code, field
          assert_equal [ :invalid ], result.errors[field], field
        end
        assert_empty @interactions.created
      end

      test "a follow-up the repository refuses rolls the interaction back and fails" do
        use_case = RecordInteraction.new(interactions: @interactions, follow_ups: RefusingFollowUps.new,
                                         policy: Policies::Crm::ManageCrmPolicy.new, transaction: @transaction, clock: Clock.new(now: NOW))

        result = use_case.call(actor: @actor, school_id: 31, kind: "call", outcome: "positive",
                               follow_up: { due_on: Date.new(2026, 11, 8), assignee_id: 7, reason: "x" })

        assert result.failure?
        assert_equal :not_found, result.code
        assert @transaction.rolled_back
      end

      test "an over-long interlocutor name, and an empty or over-long follow-up reason, are refused" do
        assert_equal [ :invalid ], call(contact_name: "a" * 201).errors[:contact_name]
        [ " ", "a" * 201 ].each do |reason|
          result = call(follow_up: { due_on: Date.new(2026, 11, 8), assignee_id: 7, reason: })

          assert_equal [ :invalid ], result.errors[:follow_up_reason], reason.length
        end
        assert_empty @interactions.created
      end

      test "an interaction the repository refuses (unknown contact) fails with its code and creates no follow-up" do
        use_case = RecordInteraction.new(interactions: RefusingInteractions.new, follow_ups: @follow_ups,
                                         policy: Policies::Crm::ManageCrmPolicy.new, transaction: @transaction, clock: Clock.new(now: NOW))

        result = use_case.call(actor: @actor, school_id: 31, kind: "call", outcome: "positive", contact_public_id: "nope")

        assert_equal :not_found, result.code
        assert_empty @follow_ups.created
      end

      test "a transaction the database refuses is returned as is (conflict)" do
        use_case = RecordInteraction.new(interactions: @interactions, follow_ups: @follow_ups,
                                         policy: Policies::Crm::ManageCrmPolicy.new, transaction: ConflictingTransaction.new, clock: Clock.new(now: NOW))

        assert_equal :conflict, use_case.call(actor: @actor, school_id: 31, kind: "call", outcome: "positive").code
      end

      test "a created follow-up is returned with the interaction" do
        result = call(follow_up: { due_on: Date.new(2026, 11, 8), assignee_id: 7, reason: "x" })

        assert_equal "fup-1", result.value.follow_up.public_id
      end

      test "a date older than a year is refused" do
        result = call(occurred_at: NOW - 367.days)

        assert_equal :invalid, result.code
        assert_equal [ :invalid ], result.errors[:occurred_at]
        assert_empty @interactions.created
      end

      test "a role outside admin and field is forbidden" do
        result = @use_case.call(actor: Actor.new(user_id: 9, team_role: "content"), school_id: 31, kind: "call", outcome: "neutral")

        assert_equal :forbidden, result.code
        assert_empty @interactions.created
      end
    end
  end
end
