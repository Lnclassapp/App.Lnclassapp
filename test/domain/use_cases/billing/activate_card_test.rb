require "test_helper"

module UseCases
  module Billing
    class ActivateCardTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 11, 16, 10)
      Clock = Data.define(:now)
      STUDENT = Entities::Identity::Actor.new(user_id: 9, role: :student)
      TEACHER = Entities::Identity::Actor.new(user_id: 8, role: :teacher)
      UNTIL = Entities::Billing::Offer::VALID_UNTIL
      CODE = "K7QHM3XP9TRA".freeze

      class FakeCards
        include Ports::Billing::CardRepositoryPort

        attr_reader :activated

        def initialize(card:, subscribed_until: nil)
          @card = card
          @subscribed_until = subscribed_until
        end

        def lock_by_code(code:) = (@card if @card&.code == code)

        def subscribed_until(student_id:) = @subscribed_until

        def activate(card_id:, student_id:, school_id:, at:)
          @activated = { card_id:, student_id:, school_id:, at: }
          Shared::Result.success(@card.with(state: "activated", student_id:, school_id:, activated_at: at))
        end
      end

      class FakeSchools
        def initialize(school_id) = @school_id = school_id

        def school_id_of_student(student_id:) = @school_id
      end

      def card(state: "issued") = Entities::Billing::ActivationCard.new(id: 40, serial: 21, code: CODE, relay_point_id: 3, valid_until: UNTIL, state:)

      def activate(raw, state: "issued", subscribed_until: nil, actor: STUDENT, school_id: 12, no_card: false)
        @cards = FakeCards.new(card: (card(state:) unless no_card), subscribed_until:)
        @audit = FakeAuditLog.new
        @transaction = FakeTransaction.new
        ActivateCard.new(cards: @cards, schools: FakeSchools.new(school_id), audit_log: @audit, transaction: @transaction,
                         policy: Policies::Billing::ActivateCardPolicy.new, clock: Clock.new(NOW))
                    .call(actor:, raw_code: raw)
      end

      test "un code en minuscules avec des espaces et des tirets active la carte pour l'école de l'élève" do
        result = activate(" k7qh-m3xp 9tra ")

        assert result.success?
        assert_equal({ card_id: 40, student_id: 9, school_id: 12, at: NOW }, @cards.activated)
        assert_equal "activated", result.value.state
        event = @audit.events.sole
        assert_equal [ "billing.card_activated", 9, "ActivationCard", 40 ], event.values_at(:action, :actor_id, :subject_type, :subject_id)
        assert_equal({ serial: 21, relay_point_id: 3, school_id: 12 }, event[:metadata])
        assert_equal 1, @transaction.calls
      end

      test "un élève sans école active quand même ; la carte n'est rattachée à aucune école" do
        activate(CODE, school_id: nil)

        assert_nil @cards.activated[:school_id]
      end

      test "un code inconnu ou mal formé est refusé sans rien changer" do
        [ "ZZZZZZZZZZZZ", "abc", "" ].each do |raw|
          result = activate(raw)

          assert_equal [ :invalid, { code: [ :unknown ] } ], [ result.code, result.errors ]
        end
        assert_equal [ :invalid, { code: [ :unknown ] } ], activate(CODE, no_card: true).then { [ it.code, it.errors ] }
        assert_nil @cards.activated
        assert_empty @audit.events
      end

      test "une carte déjà activée est refusée" do
        result = activate(CODE, state: "activated")

        assert_equal [ :conflict, [ :card_used ] ], [ result.code, result.errors[:base] ]
        assert_nil @cards.activated
      end

      test "une carte annulée est refusée" do
        result = activate(CODE, state: "cancelled")

        assert_equal [ :invalid, [ :card_cancelled ] ], [ result.code, result.errors[:base] ]
      end

      test "un élève déjà abonné pour l'année est refusé et la carte reste remise" do
        result = activate(CODE, subscribed_until: UNTIL)

        assert_equal [ :conflict, [ :already_subscribed ], [ UNTIL ] ], [ result.code, result.errors[:base], result.errors[:subscribed_until] ]
        assert_nil @cards.activated
        assert_empty @audit.events
      end

      test "un enseignant est refusé" do
        result = activate(CODE, actor: TEACHER)

        assert_equal :forbidden, result.code
        assert_nil @cards.activated
      end

      test "un abonnement antérieur plus court que la carte n'empêche pas l'activation" do
        result = activate(CODE, subscribed_until: UNTIL - 1.year)

        assert result.success?
        assert_equal 40, @cards.activated[:card_id]
      end
    end
  end
end
