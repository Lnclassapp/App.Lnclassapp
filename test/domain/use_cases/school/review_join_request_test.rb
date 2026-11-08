require "test_helper"

module UseCases
  module School
    # CP-12 (ADR-0063): the team approves or rejects, from the school page, a teacher who signed up without code.
    class ReviewJoinRequestTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 28, 12)
      Clock = Data.define(:now)
      Request = Entities::School::JoinRequest

      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        def initialize(*schools) = @schools = schools
        def find_by_id(id:) = @schools.find { it.id == id }
      end

      class FakeDepartures
        include Ports::School::TeacherDepartureRepositoryPort

        def initialize(*departures) = @departures = departures
        def open_for(teacher_id:, school_id:) = @departures.find { it.teacher_id == teacher_id && it.school_id == school_id }
      end

      setup do
        @schools = FakeSchools.new(Entities::School::School.new(id: 31, status: "active"))
        @departures = FakeDepartures.new
        @requests = FakeJoinRequests.new(Request.new(id: 5, public_id: "req-5", teacher_id: 41, school_id: 31, status: "pending", teacher_name: "Awa Koné"),
                                         Request.new(id: 6, public_id: "req-6", teacher_id: 42, school_id: 31, status: "rejected", teacher_name: "Yao"))
        @audit = FakeAuditLog.new
        @materials = FakeTeacherMaterials.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "field")
      end

      def review(public_id: "req-5", decision: "approve", actor: @team)
        ReviewJoinRequest.new(join_requests: @requests, audit_log: @audit, policy: Policies::School::ManageSchoolPolicy.new,
                              transaction: @transaction, clock: Clock.new(NOW), teacher_materials: @materials,
                              schools: @schools, departures: @departures)
                         .call(actor:, public_id:, decision:)
      end

      def audited(change) = { action: "school.changed", actor_id: 7, at: NOW, subject_type: "School", subject_id: 31,
                              metadata: { change:, join_request: "req-5", teacher_id: 41 } }

      test "approve: the teacher is attached by the decision, in one transaction, and audited" do
        result = review

        assert result.success?
        assert_equal "Awa Koné", result.value.teacher_name
        assert_equal [ [ :approve, 5, 7, "team", NOW ] ], @requests.writes
        assert_equal [ audited("join_request_approved") ], @audit.events
        assert_equal [ [ :inherit, 41, 31, nil, NOW ] ], @materials.calls
        assert_equal 1, @transaction.calls
      end

      # Audit B-015: approving attaches, so it needs an active school and no open departure (as VouchPolicy and JoinSchoolWithCode).
      test "approve: an inactive or missing school is a conflict, nothing is written" do
        [ FakeSchools.new(Entities::School::School.new(id: 31, status: "inactive")), FakeSchools.new ].each do |schools|
          @schools = schools

          assert_equal [ :conflict, { base: [ :school_inactive ] } ], review.then { [ it.code, it.errors ] }
        end
        assert_empty @requests.writes
        assert_empty @audit.events
        assert_empty @materials.calls
      end

      test "approve: an open departure of the teacher from this school is a conflict, nothing is written" do
        @departures = FakeDepartures.new(Struct.new(:teacher_id, :school_id).new(41, 31))

        assert_equal [ :conflict, { base: [ :departure_open ] } ], review.then { [ it.code, it.errors ] }
        assert_empty @requests.writes
        assert_empty @audit.events
      end

      test "reject stays possible on an inactive school or with an open departure" do
        @schools = FakeSchools.new
        @departures = FakeDepartures.new(Struct.new(:teacher_id, :school_id).new(41, 31))

        assert review(decision: "reject").success?
      end

      test "reject: refused and audited" do
        assert review(decision: "reject").success?
        assert_equal [ [ :reject, 5, 7, NOW ] ], @requests.writes
        assert_equal [ audited("join_request_rejected") ], @audit.events
        assert_empty @materials.calls
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
        assert_empty @materials.calls
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
    end
  end
end
