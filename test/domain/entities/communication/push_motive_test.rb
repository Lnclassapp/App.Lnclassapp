require "test_helper"

module Entities
  module Communication
    class PushMotiveTest < ActiveSupport::TestCase
      test "la priorité : interro, devoir, annonce, commencé, résultat, inactif" do
        assert_equal %w[quiz_prep assignment_due announcement unfinished result inactive], PushMotive::PRIORITY
        assert_equal PushMotive::PRIORITY.sort, PushMotive::ALL.sort
      end

      test "le rang suit la priorité" do
        assert_equal 0, PushMotive.rank("quiz_prep")
        assert_equal 5, PushMotive.rank("inactive")
      end

      test "un motif inconnu lève" do
        assert_raises(ArgumentError) { PushMotive.rank("promo") }
        assert_not PushMotive.valid?("promo")
        assert PushMotive.valid?("result")
      end
    end

    class PushCandidateTest < ActiveSupport::TestCase
      def candidate(**attributes) = PushCandidate.new(user_id: 1, motive: "inactive", object_key: "inactive:2026-11-13:3", url: "/", **attributes)

      test "un candidat valide connaît sa priorité" do
        assert_equal 5, candidate.priority
        assert_equal({}, candidate.variables)
      end

      test "un motif inconnu est refusé" do
        assert_raises(ArgumentError) { candidate(motive: "promo") }
      end

      test "expire à valid_until, jamais sans" do
        now = Time.utc(2026, 11, 16, 12)
        assert_not candidate.expired?(now)
        assert_not candidate(valid_until: now + 1.minute).expired?(now)
        assert candidate(valid_until: now).expired?(now)
      end
    end

    class PushSubscriptionTest < ActiveSupport::TestCase
      test "un abonnement ne porte que l'adresse et deux clés" do
        subscription = PushSubscription.new(user_id: 1, endpoint: "https://push.example.test/x", p256dh: "k", auth: "a")

        assert_nil subscription.session_id
        assert_equal 0, subscription.failure_count
      end
    end
  end
end
