require "test_helper"

module Entities
  module Billing
    # ADR cartes-activation §4.5 : gratuit 7 jours à partir du plus tard du compte et de la mise en ligne, puis bloqué.
    class AccessTest < ActiveSupport::TestCase
      def access(created:, today:, until_date: nil)
        Access.for(account_created_on: Date.parse(created), today: Date.parse(today), subscribed_until: until_date && Date.parse(until_date))
      end

      test "le 7e jour est encore gratuit, avec un jour restant" do
        result = access(created: "2026-11-09", today: "2026-11-15")

        assert_equal :free, result.status
        assert_equal 1, result.days_left
        assert_not result.blocked?
      end

      test "le jour de la création il reste 7 jours" do
        assert_equal 7, access(created: "2026-11-09", today: "2026-11-09").days_left
      end

      test "le 8e jour est bloqué" do
        result = access(created: "2026-11-09", today: "2026-11-16")

        assert_equal :blocked, result.status
        assert_equal 0, result.days_left
        assert_predicate result, :blocked?
      end

      test "un compte antérieur à la mise en ligne est gratuit jusqu'au 15 novembre, bloqué le 16" do
        assert_equal :free, access(created: "2026-10-01", today: "2026-11-15").status
        assert_equal :blocked, access(created: "2026-10-01", today: "2026-11-16").status
      end

      test "un abonné jusqu'à aujourd'hui inclus est abonné, quelle que soit l'ancienneté du compte" do
        result = access(created: "2026-10-01", today: "2027-07-31", until_date: "2027-07-31")

        assert_equal :subscribed, result.status
        assert_equal Date.new(2027, 7, 31), result.subscribed_until
        assert_nil result.days_left
      end

      test "un abonnement échu ne protège plus" do
        assert_predicate access(created: "2026-10-01", today: "2027-08-01", until_date: "2027-07-31"), :blocked?
      end

      test "l'accès sans restriction ne bloque jamais" do
        assert_not Access.unrestricted.blocked?
        assert_equal :subscribed, Access.unrestricted.status
      end
    end
  end
end
