require "test_helper"

module Entities
  module Billing
    # ADR 0126 §4.5 : gratuit 7 jours à partir du plus tard du compte et de la mise en ligne, puis bloqué.
    class AccessTest < ActiveSupport::TestCase
      # Bêta fermée au jour de la mise en ligne : exactement la règle de l'offre de lancement (ADR-0126).
      def access(created:, today:, until_date: nil, beta_ends_on: Offer::LAUNCH_ON)
        Access.for(account_created_on: Date.parse(created), today: Date.parse(today), subscribed_until: until_date && Date.parse(until_date),
                   beta_ends_on: beta_ends_on && Date.parse(beta_ends_on.to_s))
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

      # acces-beta : pendant la bêta, aucun élève n'est bloqué ni invité à s'abonner ; un abonné garde sa date.
      test "en bêta, un compte dont les 7 jours sont passés n'est pas bloqué et n'a pas de jours comptés" do
        result = access(created: "2026-10-01", today: "2027-01-16", beta_ends_on: nil)

        assert_equal :beta, result.status
        assert_nil result.days_left
        assert_not result.blocked?
        assert_not result.subscription_pending?
      end

      test "en bêta, un abonné reste abonné, avec sa date" do
        result = access(created: "2026-10-01", today: "2027-01-16", until_date: "2027-07-31", beta_ends_on: nil)

        assert_equal :subscribed, result.status
        assert_equal Date.new(2027, 7, 31), result.subscribed_until
      end

      test "sans argument, le réglage de l'offre décide : la bêta est ouverte" do
        assert_nil Offer::BETA_ENDS_ON, "poser une date ferme la bêta (ADR acces-beta)"
        assert_equal :beta, Access.for(account_created_on: Date.new(2026, 10, 1), today: Date.new(2027, 1, 16), subscribed_until: nil).status
      end

      # Décision du porteur (2026-11-12) : à la fin de la bêta, chaque élève reçoit ses 7 jours à partir de la fin de bêta.
      test "avant la date de fin, la bêta est ouverte" do
        assert_equal :beta, access(created: "2026-10-01", today: "2027-02-28", beta_ends_on: "2027-03-01").status
      end

      test "fin de bêta : un compte ancien ou créé pendant la bêta est gratuit 7 jours à partir de la fin, puis bloqué" do
        [ "2026-10-01", "2027-02-20" ].each do |created|
          assert_equal [ :free, 7 ], access(created:, today: "2027-03-01", beta_ends_on: "2027-03-01").then { [ it.status, it.days_left ] }
          assert_equal [ :free, 1 ], access(created:, today: "2027-03-07", beta_ends_on: "2027-03-01").then { [ it.status, it.days_left ] }
          assert_predicate access(created:, today: "2027-03-08", beta_ends_on: "2027-03-01"), :blocked?
        end
      end

      test "fin de bêta : un compte créé après la fin compte ses 7 jours depuis sa création" do
        assert_equal 7, access(created: "2027-03-05", today: "2027-03-05", beta_ends_on: "2027-03-01").days_left
      end

      test "hors bêta, gratuit et bloqué invitent à s'abonner ; abonné non" do
        assert_predicate access(created: "2026-11-09", today: "2026-11-10"), :subscription_pending?
        assert_predicate access(created: "2026-11-09", today: "2026-11-16"), :subscription_pending?
        assert_not Access.unrestricted.subscription_pending?
      end

      test "l'accès sans restriction ne bloque jamais" do
        assert_not Access.unrestricted.blocked?
        assert_equal :subscribed, Access.unrestricted.status
      end
    end
  end
end
