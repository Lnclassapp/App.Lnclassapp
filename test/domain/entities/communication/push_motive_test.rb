require "test_helper"

module Entities
  module Communication
    class PushMotiveTest < ActiveSupport::TestCase
      test "la priorité : interro, devoir, nouveaux exercices, annonce, commencé, résultat, inactif" do
        assert_equal %w[quiz_prep assignment_due assignment_new announcement unfinished result inactive], PushMotive::PRIORITY
        assert_equal PushMotive::PRIORITY.sort, PushMotive::ALL.sort
      end

      test "le rang suit la priorité" do
        assert_equal 0, PushMotive.rank("quiz_prep")
        assert_equal 2, PushMotive.rank("assignment_new")
        assert_equal 6, PushMotive.rank("inactive")
      end

      # ADR-0147, amendement du 2026-11-27 (II) : une case pour chaque motif ; trois événements, quatre rappels.
      test "chaque motif a sa case ; trois événements, quatre rappels ; l'annonce ne se validait pas" do
        assert_equal PushMotive::PRIORITY, PushMotive::AUTOMATABLE
        assert PushMotive.automatable?("inactive")
        assert_not PushMotive.automatable?("promo")
        assert_equal %w[assignment_new announcement result], PushMotive::EVENTS
        assert_equal PushMotive::PRIORITY - %w[announcement], PushMotive::PLANNABLE
        assert_equal %w[quiz_prep assignment_due unfinished inactive], PushMotive::REMINDERS
        assert PushMotive.event?("result")
        assert_not PushMotive.event?("assignment_due")
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
        assert_equal 6, candidate.priority
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

    class PushMotiveSettingTest < ActiveSupport::TestCase
      test "un réglage ne porte que le motif, la case et son auteur" do
        at = Time.utc(2026, 11, 25, 9)
        setting = PushMotiveSetting.new(motive: "assignment_due", automatic: true, updated_by_id: 4, updated_at: at)

        assert setting.automatic
        assert_equal 4, setting.updated_by_id
      end

      test "un motif inconnu est refusé ; une relance a sa case" do
        assert_raises(ArgumentError) { PushMotiveSetting.new(motive: "promo", automatic: true, updated_by_id: 4, updated_at: Time.utc(2026, 11, 25)) }
        assert PushMotiveSetting.new(motive: "inactive", automatic: true, updated_by_id: 4, updated_at: Time.utc(2026, 11, 25)).automatic
      end
    end

    class PushApprovalTest < ActiveSupport::TestCase
      test "une validation garde le jour, le motif, l'auteur et le nombre d'élèves" do
        approval = PushApproval.new(on_date: Date.new(2026, 11, 25), motive: "inactive", approved_by_id: 4, approved_at: Time.utc(2026, 11, 25, 10), recipients_count: 42)

        assert_nil approval.id
        assert_equal 42, approval.recipients_count
      end

      test "une annonce ou un motif inconnu ne se valide pas" do
        %w[announcement promo].each do |motive|
          assert_raises(ArgumentError) { PushApproval.new(on_date: Date.new(2026, 11, 25), motive:, approved_by_id: 4, approved_at: Time.utc(2026, 11, 25), recipients_count: 1) }
        end
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
