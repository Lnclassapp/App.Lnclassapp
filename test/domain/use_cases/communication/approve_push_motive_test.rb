require "test_helper"

# ADR XXXX (envois de notifications) §3.2, §4.4 : la validation recalcule la liste du motif au moment de valider et fige
# élève × objet ; refus après la dernière fenêtre (20 h) ; la seconde validation du jour répond « déjà validé ».
module UseCases
  module Communication
    class ApprovePushMotiveTest < ActiveSupport::TestCase
      Candidate = Entities::Communication::PushCandidate
      NOW = Time.utc(2026, 11, 25, 10, 12)
      Clock = Data.define(:now)

      class FakeCandidates
        include Ports::Communication::PushCandidatesPort

        attr_accessor :list

        def initialize(list) = @list = list
        def for(now:, user_ids: nil) = @list
      end

      class FakeDeliveries
        include Ports::Communication::PushDeliveryRepositoryPort

        def initialize(sent = []) = @sent = sent
        def sent?(user_id:, motive:, object_key:) = @sent.include?([ user_id, motive, object_key ])
      end

      class FakeSettings
        include Ports::Communication::PushMotiveSettingRepositoryPort

        def initialize(automatic = Set.new) = @automatic = automatic
        def automatic_motives = @automatic
      end

      class FakeApprovals
        include Ports::Communication::PushApprovalRepositoryPort

        attr_reader :created

        def initialize(existing: [])
          @existing = existing
          @created = []
        end
        def for_date(on_date:) = @existing
        def create(on_date:, motive:, by:, at:, recipients:)
          @created << { on_date:, motive:, by:, at:, recipients: }
          :created
        end
      end

      class RacingApprovals < FakeApprovals
        def create(**) = :already_approved
      end

      def candidate(user_id, motive: "inactive", key: "inactive:7", valid_until: nil)
        Candidate.new(user_id:, motive:, object_key: key, url: "/eleve", valid_until:)
      end

      setup do
        @candidates = FakeCandidates.new([ candidate(1), candidate(2), candidate(3, motive: "result", key: "result:1") ])
        @approvals = FakeApprovals.new
        @team = Entities::Identity::Actor.new(user_id: 9, role: :team, team_role: "content")
      end

      def approve(motive = "inactive", actor: @team, now: NOW, approvals: @approvals, deliveries: FakeDeliveries.new, settings: FakeSettings.new)
        ApprovePushMotive.new(candidates: @candidates, deliveries:, settings:, approvals:, policy: Policies::Communication::ApprovePushPolicy.new,
                              clock: Clock.new(now)).call(actor:, motive:)
      end

      test "freezes the students x objects of the motive as recomputed now, nothing else" do
        result = approve

        assert_predicate result, :success?
        assert_equal [ [ 1, "inactive:7" ], [ 2, "inactive:7" ] ], @approvals.created.sole[:recipients]
        assert_equal [ Date.new(2026, 11, 25), "inactive", 9, NOW ], @approvals.created.sole.values_at(:on_date, :motive, :by, :at)
        assert_equal [ "inactive", 2, 9 ], result.value.then { [ it.motive, it.recipients_count, it.approved_by_id ] }
      end

      test "ignores students who already received it, expired candidates, and recomputes from the ports, not from the browser" do
        @candidates.list = [ candidate(1), candidate(2), candidate(3, valid_until: NOW - 1), candidate(4) ]

        approve(deliveries: FakeDeliveries.new([ [ 1, "inactive", "inactive:7" ] ]))

        assert_equal [ 2, 4 ], @approvals.created.sole[:recipients].map(&:first)
      end

      test "refuses after the last window of the day, on a weekday and on a Sunday" do
        [ Time.utc(2026, 11, 25, 20, 20), Time.utc(2026, 11, 25, 23, 59), Time.utc(2026, 11, 29, 20, 0) ].each do |late|
          assert_equal :expired, approve(now: late).code
        end
        assert_empty @approvals.created
      end

      test "accepts between two windows and before the first one of the day" do
        [ Time.utc(2026, 11, 25, 8), Time.utc(2026, 11, 25, 15), Time.utc(2026, 11, 25, 20, 19), Time.utc(2026, 11, 29, 19, 59) ].each do |early|
          assert_predicate approve(now: early), :success?
        end
      end

      test "a second approval of the day answers conflict without writing" do
        existing = Entities::Communication::PushApproval.new(on_date: Date.new(2026, 11, 25), motive: "inactive", approved_by_id: 4, approved_at: NOW - 1.hour,
                                                              recipients_count: 2)

        assert_equal :conflict, approve(approvals: FakeApprovals.new(existing: [ existing ])).code
      end

      test "a concurrent approval lost on the unique index answers conflict" do
        assert_equal :conflict, approve(approvals: RacingApprovals.new).code
      end

      test "an automatic motive, an announcement, an unknown motive and an empty list are refused, nothing written" do
        assert_equal :invalid, approve("quiz_prep", settings: FakeSettings.new(Set["quiz_prep"])).code
        assert_equal :not_found, approve("announcement").code
        assert_equal :not_found, approve("nope").code
        assert_equal :invalid, approve("unfinished").code
        assert_empty @approvals.created
      end

      test "a teacher, a school admin or a visitor is forbidden" do
        [ Entities::Identity::Actor.new(user_id: 1, role: :teacher), Entities::Identity::Actor.new(user_id: 1, role: :school_admin), nil ].each do |someone|
          assert_equal :forbidden, approve(actor: someone).code
        end
        assert_empty @approvals.created
      end

      test "the approvals port refuses every method its adapter does not define" do
        bare = Class.new { include Ports::Communication::PushApprovalRepositoryPort }.new

        assert_raises(NotImplementedError) { bare.for_date(on_date: nil) }
        assert_raises(NotImplementedError) { bare.create(on_date: nil, motive: nil, by: nil, at: nil, recipients: []) }
        assert_raises(NotImplementedError) { bare.history(since: nil) }
        assert_raises(NotImplementedError) { bare.purge_before(before: nil) }
      end
    end
  end
end
