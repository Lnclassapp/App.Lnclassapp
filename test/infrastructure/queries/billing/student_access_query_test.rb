require "test_helper"

module Queries
  module Billing
    class StudentAccessQueryTest < ActiveSupport::TestCase
      # acces-beta : la règle d'après-bêta, bêta fermée par Offer::BETA_ENDS_ON (BillingBetaHelper), sauf le dernier test.
      setup do
        close_beta_for_this_test
        @query = StudentAccessQuery.new
      end

      def access(user, on) = @query.call(student_id: user.id, at: Time.utc(*on.split("-").map(&:to_i), 12))

      test "un élève créé le 9 novembre est gratuit le 15 et bloqué le 16" do
        student = create_student
        student.update_columns(created_at: Time.utc(2026, 11, 9, 8)) # rubocop:disable Rails/SkipsModelValidations

        assert_equal [ :free, 1 ], access(student, "2026-11-15").then { [ it.status, it.days_left ] }
        assert_predicate access(student, "2026-11-16"), :blocked?
      end

      test "un compte antérieur à la mise en ligne compte ses 7 jours depuis le 9 novembre" do
        student = create_student
        student.update_columns(created_at: Time.utc(2026, 10, 1, 8)) # rubocop:disable Rails/SkipsModelValidations

        assert_equal :free, access(student, "2026-11-15").status
        assert_predicate access(student, "2026-11-16"), :blocked?
      end

      test "une carte activée abonne l'élève jusqu'à la fin de l'offre" do
        student = create_student
        student.update_columns(created_at: Time.utc(2026, 10, 1, 8)) # rubocop:disable Rails/SkipsModelValidations
        relay_point = Orm::Billing::RelayPoint.create!(name: "Awa", location: "Marché", phone: "07 00 00 00 00")
        batch = Repositories::Billing::CardRepository.new.create_batch(relay_point_id: relay_point.id, quantity: 1, unit_price_xof: 0,
                                                                       valid_until: Date.new(2027, 7, 31), created_by_id: nil, at: Time.current)
        Repositories::Billing::CardRepository.new.activate(card_id: batch.cards.first.id, student_id: student.id, school_id: nil, at: Time.current)

        result = access(student, "2026-12-01")

        assert_equal [ :subscribed, Date.new(2027, 7, 31) ], [ result.status, result.subscribed_until ]
        assert_equal :subscribed, access(student, "2027-07-31").status
        assert_predicate access(student, "2027-08-01"), :blocked?
      end

      test "un enseignant, une direction ou un compte inconnu ne sont jamais bloqués" do
        [ create_teacher, create_team_member ].each do |user|
          user.update_columns(created_at: Time.utc(2025, 1, 1)) # rubocop:disable Rails/SkipsModelValidations

          assert_not access(user, "2027-01-01").blocked?
        end
        assert_not @query.call(student_id: 0, at: Time.utc(2027, 1, 1)).blocked?
        assert_not @query.call(student_id: nil, at: Time.utc(2027, 1, 1)).blocked?
      end

      test "bêta ouverte : un élève ancien n'est pas bloqué, un enseignant reste sans restriction" do
        set_beta_ends_on(nil)
        student = create_student
        student.update_columns(created_at: Time.utc(2026, 10, 1, 8)) # rubocop:disable Rails/SkipsModelValidations

        assert_equal :beta, access(student, "2027-01-16").status
        assert_equal :subscribed, access(create_teacher, "2027-01-16").status
      end
    end
  end
end
