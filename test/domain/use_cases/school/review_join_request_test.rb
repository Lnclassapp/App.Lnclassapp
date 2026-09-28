require "test_helper"

module UseCases
  module School
    # CP-12 (ADR-0063): the team approves or rejects, from the school page, a teacher who signed up without code.
    class ReviewJoinRequestTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 28, 12)
      Clock = Data.define(:now)
      Request = Entities::School::JoinRequest

      setup do
        @requests = FakeJoinRequests.new(Request.new(id: 5, public_id: "req-5", teacher_id: 41, school_id: 31, status: "pending", teacher_name: "Awa Koné"),
                                         Request.new(id: 6, public_id: "req-6", teacher_id: 42, school_id: 31, status: "rejected", teacher_name: "Yao"))
        @audit = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "field")
      end

      def review(public_id: "req-5", decision: "approve", actor: @team)
        ReviewJoinRequest.new(join_requests: @requests, audit_log: @audit, policy: Policies::School::ManageSchoolPolicy.new,
                              transaction: @transaction, clock: Clock.new(NOW)).call(actor:, public_id:, decision:)
      end

      def audited(change) = { action: "school.changed", actor_id: 7, at: NOW, subject_type: "School", subject_id: 31,
                              metadata: { change:, join_request: "req-5", teacher_id: 41 } }

      test "approve: the teacher is attached by the decision, in one transaction, and audited" do
        result = review

        assert result.success?
        assert_equal "Awa Koné", result.value.teacher_name
        assert_equal [ [ :approve, 5, 7, "team", NOW ] ], @requests.writes
        assert_equal [ audited("join_request_approved") ], @audit.events
        assert_equal 1, @transaction.calls
      end

      test "reject: refused and audited" do
        assert review(decision: "reject").success?
        assert_equal [ [ :reject, 5, 7, NOW ] ], @requests.writes
        assert_equal [ audited("join_request_rejected") ], @audit.events
      end

      test "a request already decided is a conflict, nothing is written" do
        result = review(public_id: "req-6")

        assert_equal [ :conflict, { base: [ :already_decided ] } ], [ result.code, result.errors ]
        assert_empty @requests.writes
        assert_empty @audit.events
      end

      test "a decision decided meanwhile by a sponsor: the conflict of the repository, without audit" do
        requests = @requests
        requests.define_singleton_method(:find_by_public_id) { |public_id:| super(public_id:)&.with(status: "pending") }
        requests.approve(id: 5, decided_by_id: 9, via: "sponsor", at: NOW)
        requests.writes.clear

        assert_equal :conflict, review.code
        assert_empty @audit.events
      end

      test "an unknown decision is invalid; an unknown request is not found" do
        assert_equal [ :invalid, { decision: [ :inclusion ] } ], review(decision: "maybe").then { [ it.code, it.errors ] }
        assert_equal :not_found, review(public_id: "req-0").code
        assert_empty @requests.writes
      end

      test "outside the team: forbidden before any read" do
        [ Entities::Identity::Actor.new(user_id: 8, role: :teacher, school_id: 31), nil ].each do |actor|
          assert_equal :forbidden, review(actor:).code
        end
        assert_empty @requests.writes
      end

      test "ED-23: the principal of the school does not decide a pending teacher (ADR-0066 §4.3, Q1)" do
        principal = Entities::Identity::Actor.new(user_id: 9, role: :school_admin, school_id: 31, position: "principal")

        %w[approve reject].each { assert_equal :forbidden, review(actor: principal, decision: it).code, it }
        assert_empty @requests.writes
        assert_empty @audit.events
        assert @requests.find_by_public_id(public_id: "req-5").pending?
      end
    end
  end
end
