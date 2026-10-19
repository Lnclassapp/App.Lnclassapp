require "test_helper"

module UseCases
  module School
    # GD-19, GD-20 (ADR-0071 §4.3): the direction reinstates a teacher it detached: attached again to its school, no
    # classroom and no assignment given back, the open departure closed. Never a teacher of another school.
    # ME-21, ME-22 (ADR-0094 §4.4): a teacher who has joined another school since is reinstated as a secondary school,
    # within the cap of 3; at the cap, nothing is written and the refusal says why.
    class ReinstateTeacherTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 1, 9)
      Clock = Data.define(:now)

      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        attr_reader :attached

        def initialize(*schools, elsewhere: {}, refuse_attach: nil)
          @schools = schools.index_by(&:id)
          @elsewhere = elsewhere
          @refuse_attach = refuse_attach
          @attached = []
        end

        def find_by_id(id:) = @schools[id]
        def school_ids_for(teacher_id:) = @elsewhere.fetch(teacher_id, [])

        # Le principal se décide ici, sous le verrou (ADR-0094 §4.5) : aucun autre établissement.
        def attach_teacher_within_cap(teacher_id:, school_id:, cap:, at:)
          return Shared::Result.failure(:conflict, errors: { base: [ @refuse_attach ] }) if @refuse_attach

          primary = school_ids_for(teacher_id:).empty?
          @attached << { teacher_id:, school_id:, primary:, cap:, at: }
          Shared::Result.success(primary)
        end
      end

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def initialize(*users) = @users = users.index_by(&:public_id)
        def find_by_public_id(public_id:) = @users[public_id]
      end

      class FakeDepartures
        include Ports::School::TeacherDepartureRepositoryPort

        attr_reader :closed

        def initialize(*departures)
          @departures = departures
          @closed = []
        end

        def open_for(teacher_id:, school_id:)
          @departures.find { it.teacher_id == teacher_id && it.school_id == school_id && it.open? }
        end

        def close(id:, reinstated_by_id:, at:) = (@closed << { id:, reinstated_by_id:, at: }) && true
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :events

        def initialize = @events = []
        def record(**event) = (@events << event) && true
      end

      setup do
        @school = school(31, "active")
        @other = school(32, "active")
        @teacher = user(id: 50, public_id: "usr-awa")
        @admin = Entities::Identity::Actor.new(user_id: 7, role: :school_admin, school_id: 31)
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
      end

      def school(id, status)
        Entities::School::School.new(id:, public_id: "sch-#{id}", drena_id: 1, name: "Lycée #{id}", school_type: "public",
                                     cycle: "both", status:)
      end

      def user(id:, public_id:, role: "teacher", anonymized_at: nil)
        Entities::Identity::User.new(id:, public_id:, role:, first_name: "Awa", last_name: "Koné", gender: "female", anonymized_at:)
      end

      def departure(teacher_id: 50, school_id: 31, reinstated_at: nil)
        Entities::School::TeacherDeparture.new(id: 9, teacher_id:, school_id:, detached_by_id: 7, detached_at: NOW - 86_400,
                                               reinstated_by_id: (7 if reinstated_at), reinstated_at:)
      end

      def reinstate(actor: @admin, school_id: 31, teacher_public_id: "usr-awa", departures: [ departure ], users: [ @teacher ],
                    elsewhere: {}, refuse_attach: nil, schools: [ @school, @other ])
        @schools = FakeSchools.new(*schools, elsewhere:, refuse_attach:)
        @departures = FakeDepartures.new(*departures)
        ReinstateTeacher.new(users: FakeUsers.new(*users), schools: @schools, departures: @departures, audit_log: @audit,
                             policy: Policies::School::ManageSchoolTeachersPolicy.new, transaction: @transaction,
                             clock: Clock.new(NOW)).call(actor:, school_id:, teacher_public_id:)
      end

      test "GD-19 : réattaché à l'établissement en école principale, départ clos, journal teacher.reinstated" do
        result = reinstate

        assert result.success?
        assert_equal @teacher, result.value
        assert_equal [ { teacher_id: 50, school_id: 31, primary: true, cap: 3, at: NOW } ], @schools.attached
        assert_equal [ { id: 9, reinstated_by_id: 7, at: NOW } ], @departures.closed
        assert_equal [ { action: "teacher.reinstated", actor_id: 7, at: NOW, subject_type: "User", subject_id: 50,
                         metadata: { school_id: 31 } } ], @audit.events
        assert_equal 1, @transaction.calls
      end

      test "GD-20 : la direction de A sur l'établissement B : forbidden, rien n'est écrit" do
        result = reinstate(school_id: 32, departures: [ departure(school_id: 32) ])

        assert_equal :forbidden, result.code
        assert_nothing_written
      end

      test "établissement inactif, établissement inconnu, équipe, enseignant : forbidden" do
        assert_equal :forbidden, reinstate(schools: [ school(31, "inactive") ]).code
        assert_equal :forbidden, reinstate(schools: [ school(31, "draft") ]).code
        assert_equal :forbidden, reinstate(schools: []).code
        assert_equal :forbidden, reinstate(actor: Entities::Identity::Actor.new(user_id: 8, role: :team, team_role: "admin")).code
        assert_equal :forbidden, reinstate(actor: Entities::Identity::Actor.new(user_id: 8, role: :teacher, school_id: 31)).code
        assert_equal :forbidden, reinstate(actor: nil).code
        assert_nothing_written
      end

      test "not_found : compte inconnu, non enseignant, anonymisé" do
        assert_equal :not_found, reinstate(teacher_public_id: "usr-x").code
        assert_equal :not_found, reinstate(users: [ user(id: 50, public_id: "usr-awa", role: "school_admin") ]).code
        assert_equal :not_found, reinstate(users: [ user(id: 50, public_id: "usr-awa", anonymized_at: NOW) ]).code
        assert_nothing_written
      end

      test "not_found : aucun départ ouvert de cet établissement (jamais retiré, déjà réintégré, retiré d'ailleurs)" do
        assert_equal :not_found, reinstate(departures: []).code
        assert_equal :not_found, reinstate(departures: [ departure(reinstated_at: NOW - 3600) ]).code
        assert_equal :not_found, reinstate(departures: [ departure(school_id: 32) ]).code
        assert_nothing_written
      end

      test "ME-21 : il a rejoint un autre établissement entre-temps : réintégré en secondaire, départ clos" do
        assert reinstate(elsewhere: { 50 => [ 32 ] }).success?

        assert_equal [ [ 31, false ] ], @schools.attached.map { it.values_at(:school_id, :primary) }
        assert_equal 1, @departures.closed.size
      end

      test "ME-22 : au plafond, sous verrou : conflict schools_limit, départ ouvert, aucun journal" do
        result = reinstate(elsewhere: { 50 => [ 32, 33, 34 ] }, refuse_attach: :schools_limit)

        assert_equal [ :conflict, { base: [ :schools_limit ] } ], [ result.code, result.errors ]
        assert_empty @departures.closed
        assert_empty @audit.events
      end

      test "un rattachement refusé par la base : conflict, départ ouvert, aucun journal" do
        result = reinstate(refuse_attach: :already_attached)

        assert_equal :conflict, result.code
        assert_empty @departures.closed
        assert_empty @audit.events
      end

      private

      def assert_nothing_written
        assert_empty @schools.attached
        assert_empty @departures.closed
        assert_empty @audit.events
      end
    end
  end
end
