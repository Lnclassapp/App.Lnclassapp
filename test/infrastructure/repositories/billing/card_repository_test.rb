require "test_helper"

module Repositories
  module Billing
    class CardRepositoryTest < ActiveSupport::TestCase
      AT = Time.utc(2026, 11, 12, 10, 0, 0)
      UNTIL = Date.new(2027, 7, 31)

      setup do
        @repository = CardRepository.new
        @team = create_team_member
        @relay_point = Orm::Billing::RelayPoint.create!(name: "Boutique Awa", location: "Près du marché", phone: "07 00 00 00 00")
      end

      def batch(quantity: 3, price: 10_000, valid_until: UNTIL)
        @repository.create_batch(relay_point_id: @relay_point.id, quantity:, unit_price_xof: price, valid_until:,
                                 created_by_id: @team.id, at: AT)
      end

      test "crée un lot avec ses cartes remises, numéros et codes uniques" do
        created = batch(quantity: 5)

        assert_instance_of Entities::Billing::CardBatch, created
        assert_equal [ 5, 10_000, UNTIL, @relay_point.id ], [ created.quantity, created.unit_price_xof, created.valid_until, created.relay_point_id ]
        assert_equal 14, created.public_id.length
        assert_equal 5, created.cards.size
        assert_equal 5, created.cards.map(&:serial).uniq.size
        assert_equal 5, created.cards.map(&:code).uniq.size
        assert(created.cards.all? { it.issued? && it.price_xof == 10_000 && it.valid_until == UNTIL })
        assert(created.cards.all? { Entities::Billing::ActivationCode.well_formed?(it.code) })
      end

      test "le code est chiffré en base" do
        card = batch(quantity: 1).cards.first
        raw = Orm::Billing::ActivationCard.connection.select_value("SELECT code FROM billing_activation_cards WHERE id = #{card.id}")

        assert_not_equal card.code, raw
        assert_not_includes raw, card.code
      end

      test "retire un code quand il entre en collision" do
        taken = batch(quantity: 1).cards.first.code
        codes = [ taken, "ABCDEFGHJKMN" ]
        original = Entities::Billing::ActivationCode.method(:generate)
        Entities::Billing::ActivationCode.define_singleton_method(:generate) { codes.shift || original.call }
        begin
          assert_equal [ "ABCDEFGHJKMN" ], batch(quantity: 1).cards.map(&:code)
        ensure
          Entities::Billing::ActivationCode.define_singleton_method(:generate, original)
        end
      end

      test "liste les cartes d'un lot par numéro, rien pour un lot inconnu" do
        created = batch(quantity: 3)

        assert_equal created.cards.map(&:serial).sort, @repository.cards_of_batch(batch_public_id: created.public_id).map(&:serial)
        assert_empty @repository.cards_of_batch(batch_public_id: "inconnu")
      end

      test "retrouve une carte par son code ou son numéro, nil sinon" do
        card = batch(quantity: 1).cards.first

        assert_equal card.id, @repository.lock_by_code(code: card.code).id
        assert_nil @repository.lock_by_code(code: "AAAAAAAAAAAA")
        assert_equal card.id, @repository.find_by_serial(serial: card.serial).id
        assert_nil @repository.find_by_serial(serial: 0)
      end

      test "la base refuse un code en double" do
        first, second = batch(quantity: 2).cards.map { Orm::Billing::ActivationCard.find(it.id) }

        assert_raises(ActiveRecord::RecordNotUnique) { second.update_columns(code: first.code) } # rubocop:disable Rails/SkipsModelValidations
      end

      test "la base refuse un état inconnu" do
        card = Orm::Billing::ActivationCard.find(batch(quantity: 1).cards.first.id)

        assert_raises(ActiveRecord::StatementInvalid) { card.update_columns(state: "stolen") } # rubocop:disable Rails/SkipsModelValidations
      end

      test "active une carte pour un élève et son école" do
        student = create_student
        school = create_school
        card = batch(quantity: 1).cards.first

        result = @repository.activate(card_id: card.id, student_id: student.id, school_id: school.id, at: AT)

        assert_predicate result, :success?
        assert_equal [ "activated", student.id, school.id, AT ],
                     [ result.value.state, result.value.student_id, result.value.school_id, result.value.activated_at ]
        assert_equal UNTIL, @repository.subscribed_until(student_id: student.id)
      end

      test "active sans école" do
        card = batch(quantity: 1).cards.first

        result = @repository.activate(card_id: card.id, student_id: create_student.id, school_id: nil, at: AT)

        assert_predicate result, :success?
        assert_nil result.value.school_id
      end

      test "refuse une carte déjà utilisée" do
        card = batch(quantity: 1).cards.first
        @repository.activate(card_id: card.id, student_id: create_student.id, school_id: nil, at: AT)

        result = @repository.activate(card_id: card.id, student_id: create_student.id, school_id: nil, at: AT)

        assert_equal [ :conflict, { base: [ :card_used ] } ], [ result.code, result.errors ]
      end

      test "refuse une carte annulée" do
        card = batch(quantity: 1).cards.first
        @repository.cancel(card_id: card.id, by_id: @team.id, reason: "perdue", at: AT)

        result = @repository.activate(card_id: card.id, student_id: create_student.id, school_id: nil, at: AT)

        assert_equal [ :invalid, { base: [ :card_cancelled ] } ], [ result.code, result.errors ]
      end

      test "refuse une 2e carte activée pour le même élève et la même année, la carte reste remise" do
        student = create_student
        first, second = batch(quantity: 2).cards
        @repository.activate(card_id: first.id, student_id: student.id, school_id: nil, at: AT)

        result = @repository.activate(card_id: second.id, student_id: student.id, school_id: nil, at: AT)

        assert_equal [ :conflict, { base: [ :already_subscribed ] } ], [ result.code, result.errors ]
        assert_equal "issued", Orm::Billing::ActivationCard.find(second.id).state
      end

      test "l'index unique partiel ne vise que les cartes activées" do
        student = create_student
        first, second = batch(quantity: 2).cards.map { Orm::Billing::ActivationCard.find(it.id) }
        first.update!(state: "activated", student_id: student.id, activated_at: AT)

        assert_raises(ActiveRecord::RecordNotUnique) { second.update!(state: "activated", student_id: student.id, activated_at: AT) }
      end

      test "subscribed_until rend la fin d'abonnement la plus tardive, nil sans carte activée" do
        student = create_student

        assert_nil @repository.subscribed_until(student_id: student.id)

        @repository.activate(card_id: batch(quantity: 1).cards.first.id, student_id: student.id, school_id: nil, at: AT)
        later = batch(quantity: 1, valid_until: Date.new(2028, 7, 31)).cards.first
        @repository.activate(card_id: later.id, student_id: student.id, school_id: nil, at: AT)

        assert_equal Date.new(2028, 7, 31), @repository.subscribed_until(student_id: student.id)
      end

      test "annule une carte remise avec l'auteur, la date et le motif" do
        card = batch(quantity: 1).cards.first

        result = @repository.cancel(card_id: card.id, by_id: @team.id, reason: "perdue", at: AT)

        assert_predicate result, :success?
        assert_equal [ "cancelled", @team.id, "perdue", AT ],
                     [ result.value.state, result.value.cancelled_by_id, result.value.cancel_reason, result.value.cancelled_at ]
      end

      test "refuse d'annuler une carte activée ou déjà annulée" do
        activated, cancelled = batch(quantity: 2).cards
        @repository.activate(card_id: activated.id, student_id: create_student.id, school_id: nil, at: AT)
        @repository.cancel(card_id: cancelled.id, by_id: @team.id, reason: "perdue", at: AT)

        assert_equal [ :conflict, { base: [ :card_activated ] } ],
                     @repository.cancel(card_id: activated.id, by_id: @team.id, reason: "x", at: AT).then { [ it.code, it.errors ] }
        assert_equal [ :conflict, { base: [ :card_cancelled ] } ],
                     @repository.cancel(card_id: cancelled.id, by_id: @team.id, reason: "x", at: AT).then { [ it.code, it.errors ] }
      end
    end
  end
end
