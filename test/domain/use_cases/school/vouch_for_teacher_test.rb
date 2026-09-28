require "test_helper"

module UseCases
  module School
    # CP-13 (ADR-0063): an active teacher of the same school vouches for a pending colleague: the colleague is attached at
    # once, and the sponsor becomes their referrer — unless they already have one.
    class VouchForTeacherTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 28, 12)
      Clock = Data.define(:now)
      Request = Entities::School::JoinRequest

      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        def initialize(*schools) = @schools = schools
        def find_by_id(id:) = @schools.find { it.id == id }
      end

      class FakeReferrals
        include Ports::Identity::ReferralRepositoryPort

        attr_reader :referrals

        def initialize(taken: false)
          @taken = taken
          @referrals = []
        end

        def record_referral(referrer_id:, referee_id:, school_id:, source:, at:)
          return Shared::Result.failure(:conflict) if @taken

          @referrals << [ referrer_id, referee_id, school_id, source, at ]
          Shared::Result.success
        end
      end

      setup do
        @requests = FakeJoinRequests.new(Request.new(id: 5, public_id: "req-5", teacher_id: 41, school_id: 31, status: "pending", teacher_name: "Awa Koné"),
                                         Request.new(id: 6, public_id: "req-6", teacher_id: 42, school_id: 31, status: "approved", teacher_name: "Yao"))
        @schools = FakeSchools.new(Entities::School::School.new(id: 31, status: "active"))
        @audit = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @sponsor = Entities::Identity::Actor.new(user_id: 7, role: :teacher, school_id: 31)
      end

      def vouch(public_id: "req-5", actor: @sponsor, referrals: (@referrals = FakeReferrals.new))
        VouchForTeacher.new(join_requests: @requests, schools: @schools, referrals:, audit_log: @audit,
                            policy: Policies::School::VouchPolicy.new, transaction: @transaction, clock: Clock.new(NOW))
                       .call(actor:, public_id:)
      end

      test "the colleague is attached by the sponsor, who becomes their referrer, audited, in one transaction" do
        result = vouch

        assert result.success?
        assert_equal "Awa Koné", result.value.teacher_name
        assert_equal [ [ :approve, 5, 7, "sponsor", NOW ] ], @requests.writes
        assert_equal [ [ 7, 41, 31, "sponsor", NOW ] ], @referrals.referrals
        assert_equal [ { action: "school.changed", actor_id: 7, at: NOW, subject_type: "School", subject_id: 31,
                         metadata: { change: "join_request_vouched", join_request: "req-5", teacher_id: 41 } } ], @audit.events
        assert_equal 1, @transaction.calls
      end

      test "a colleague who already has a referrer keeps them; the approval stands" do
        assert vouch(referrals: FakeReferrals.new(taken: true)).success?
        assert_equal [ [ :approve, 5, 7, "sponsor", NOW ] ], @requests.writes
      end

      test "a request approved meanwhile by the team: the conflict of the repository, no referral, no audit" do
        requests = @requests
        requests.define_singleton_method(:find_by_public_id) { |public_id:| super(public_id:)&.with(status: "pending") }
        requests.approve(id: 5, decided_by_id: 1, via: "team", at: NOW)
        requests.writes.clear

        assert_equal :conflict, vouch.code
        assert_empty @referrals.referrals
        assert_empty @audit.events
      end

      test "m5: a teacher of another school, or the team, reads not found — the request is not confirmed to exist" do
        [ Entities::Identity::Actor.new(user_id: 8, role: :teacher, school_id: 32),
          Entities::Identity::Actor.new(user_id: 9, role: :team, team_role: "admin") ].each do |actor|
          assert_equal :not_found, vouch(actor:).code
        end
        assert_empty @requests.writes
      end

      test "ED-23: the principal of the school is no sponsor: refused as not found, the request stays pending" do
        principal = Entities::Identity::Actor.new(user_id: 9, role: :school_admin, school_id: 31, position: "principal")

        assert_equal :not_found, vouch(actor: principal).code
        assert_empty @requests.writes
        assert_empty @audit.events
        assert @requests.find_by_public_id(public_id: "req-5").pending?
      end

      test "an unknown request is not found; a request already decided is a conflict" do
        assert_equal :not_found, vouch(public_id: "req-0").code
        assert_equal [ :conflict, { base: [ :already_decided ] } ], vouch(public_id: "req-6").then { [ it.code, it.errors ] }
        assert_empty @requests.writes
        assert_empty @audit.events
      end
    end
  end
end
