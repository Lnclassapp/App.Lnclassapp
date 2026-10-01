require "test_helper"

module UseCases
  module School
    # GD-23, GD-24, GD-26, GD-27 (ADR-0071 §4.3): a teacher without a school joins an active school by its code; the
    # school that detached them, an unknown code and a school not active give the very same error.
    class JoinSchoolWithCodeTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 1, 9)
      Clock = Data.define(:now)
      Status = Data.define(:school_name, :status)

      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        attr_reader :attached

        def initialize(*schools, refuse_attach: false)
          @schools = schools.index_by(&:school_code)
          @refuse_attach = refuse_attach
          @attached = []
        end

        def find_by_school_code(school_code:) = @schools[school_code]

        def attach_teacher(teacher_id:, school_id:, primary:, at:)
          return Shared::Result.failure(:conflict) if @refuse_attach

          @attached << { teacher_id:, school_id:, primary:, at: }
          Shared::Result.success
        end
      end

      class FakeDepartures
        include Ports::School::TeacherDepartureRepositoryPort

        def initialize(*departures) = @departures = departures

        def open_for(teacher_id:, school_id:)
          @departures.find { it.teacher_id == teacher_id && it.school_id == school_id && it.open? }
        end
      end

      # The reader of the teacher's request (Queries::School::JoinRequestsQuery#status_for): a Status of any state.
      class FakeJoinRequests
        attr_reader :asked

        def initialize(status) = @status = status

        def status_for(teacher_id:)
          @asked = teacher_id
          @status && Status.new(school_name: "Lycée Classique", status: @status)
        end
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :events

        def initialize = @events = []
        def record(**event) = (@events << event) && true
      end

      setup do
        @a = school(31, "k7m4qz", "active")
        @b = school(32, "abc234", "active")
        @inactive = school(33, "zzz999", "inactive")
        @draft = school(34, "hhh222", "draft")
        @teacher = Entities::Identity::Actor.new(user_id: 50, role: :teacher)
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
      end

      def school(id, school_code, status)
        Entities::School::School.new(id:, public_id: "sch-#{id}", drena_id: 1, name: "Lycée #{id}", school_type: "public",
                                     cycle: "both", status:, school_code:)
      end

      def departure(school_id:, reinstated_at: nil)
        Entities::School::TeacherDeparture.new(id: school_id, teacher_id: 50, school_id:, detached_by_id: 7, detached_at: NOW - 86_400,
                                               reinstated_by_id: (7 if reinstated_at), reinstated_at:)
      end

      def join(code, actor: @teacher, departures: [ departure(school_id: 31) ], request: nil, refuse_attach: false)
        @schools = FakeSchools.new(@a, @b, @inactive, @draft, refuse_attach:)
        @join_requests = FakeJoinRequests.new(request)
        JoinSchoolWithCode.new(schools: @schools, departures: FakeDepartures.new(*departures), join_requests: @join_requests,
                               audit_log: @audit, policy: Policies::School::JoinSchoolWithCodePolicy.new,
                               transaction: @transaction, clock: Clock.new(NOW))
                          .call(actor:, dto: Dtos::School::SchoolJoinInput.new(school_code: code))
      end

      test "GD-23 : rattaché à B en école principale, journal school.changed teacher_joined" do
        result = join("ABC-234")

        assert result.success?
        assert_equal @b, result.value
        assert_equal [ { teacher_id: 50, school_id: 32, primary: true, at: NOW } ], @schools.attached
        assert_equal [ { action: "school.changed", actor_id: 50, at: NOW, subject_type: "School", subject_id: 32,
                         metadata: { change: "teacher_joined" } } ], @audit.events
      end

      test "GD-24 : le code de A, un code inconnu, un établissement inactif ou en brouillon : la même erreur" do
        [ "k7m4qz", "xyz789", "zzz999", "hhh222" ].each do |code|
          result = join(code)

          assert_equal :invalid, result.code, code
          assert_equal({ school_code: [ :inclusion ] }, result.errors, code)
          assert_empty @schools.attached
        end
        assert_empty @audit.events
      end

      test "GD-27 : réintégré puis retiré de nouveau, le code de A est refusé ; un départ clos n'empêche pas" do
        assert_equal :invalid, join("k7m4qz", departures: [ departure(school_id: 31, reinstated_at: NOW - 3600),
                                                            departure(school_id: 31) ]).code
        assert join("k7m4qz", departures: [ departure(school_id: 31, reinstated_at: NOW - 3600) ]).success?
      end

      test "GD-26 : une demande en attente : forbidden, sans lire le code" do
        result = join("abc234", request: "pending")

        assert_equal :forbidden, result.code
        assert_equal 50, @join_requests.asked
        assert_empty @schools.attached
      end

      test "une demande refusée ou approuvée n'empêche pas" do
        assert join("abc234", request: "rejected").success?
        assert join("abc234", request: "approved").success?
      end

      test "forbidden : enseignant déjà rattaché, autre rôle, visiteur" do
        assert_equal :forbidden, join("abc234", actor: Entities::Identity::Actor.new(user_id: 50, role: :teacher, school_id: 31)).code
        assert_equal :forbidden, join("abc234", actor: Entities::Identity::Actor.new(user_id: 8, role: :school_admin, school_id: 32)).code
        assert_equal :forbidden, join("abc234", actor: nil).code
        assert_nil @join_requests.asked
        assert_empty @schools.attached
      end

      test "une saisie mal formée : invalid avec le motif du DTO" do
        result = join("")

        assert_equal :invalid, result.code
        assert_equal({ school_code: [ "Saisissez le code de votre établissement." ] }, result.errors)
        assert_empty @schools.attached
      end

      test "un rattachement refusé par la base : conflict, aucun journal" do
        assert_equal :conflict, join("abc234", refuse_attach: true).code
        assert_empty @audit.events
      end
    end
  end
end
