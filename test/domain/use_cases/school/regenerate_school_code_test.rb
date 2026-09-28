require "test_helper"

module UseCases
  module School
    # ADR-0057 (CE-07, CE-08): the team replaces a school's code; the old one stops working at once, the teachers
    # already attached are not touched (no port method would touch them).
    class RegenerateSchoolCodeTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 28, 12)
      Clock = Data.define(:now)

      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        attr_reader :attempts

        # conflicts : number of drawn codes refused as already taken, before one is accepted.
        def initialize(*schools, conflicts: 0)
          @schools = schools.index_by(&:id)
          @conflicts = conflicts
          @attempts = []
        end

        def find_by_public_id(public_id:) = @schools.values.find { it.public_id == public_id }&.dup

        def replace_school_code(id:, school_code:, at:)
          @attempts << [ id, school_code, at ]
          return Shared::Result.failure(:conflict) if @attempts.size <= @conflicts

          school = @schools.fetch(id)
          school.school_code = school_code
          Shared::Result.success(school.dup)
        end

        def stored(id) = @schools.fetch(id)
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :events

        def initialize
          @events = []
        end

        def record(**event) = (@events << event) && true
      end

      setup do
        @school = Entities::School::School.new(id: 31, public_id: "sch-lca", drena_id: 1, name: "Lycée Classique",
                                               school_type: "public", cycle: "both", status: "active", school_code: "k7m4qz")
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "field")
      end

      def regenerate(public_id: "sch-lca", actor: @team, conflicts: 0)
        @schools = FakeSchools.new(@school, conflicts:)
        RegenerateSchoolCode.new(schools: @schools, audit_log: @audit, policy: Policies::School::ManageSchoolPolicy.new,
                                 transaction: @transaction, clock: Clock.new(NOW)).call(actor:, public_id:)
      end

      test "CE-07: tire un nouveau code valide, l'écrit daté et trace la régénération, en une transaction" do
        result = regenerate

        assert result.success?
        code = result.value.school_code
        assert Entities::School::SchoolCode.valid?(code)
        assert_not_equal "k7m4qz", code
        assert_equal [ [ 31, code, NOW ] ], @schools.attempts
        assert_equal code, @schools.stored(31).school_code
        assert_equal 1, @transaction.calls
        assert_equal [ { action: "school.changed", actor_id: 7, at: NOW, subject_type: "School", subject_id: 31,
                         metadata: { change: "code_regenerated", public_id: "sch-lca" } } ], @audit.events
      end

      test "un code déjà pris est retiré au sort, jusqu'à cinq fois" do
        result = regenerate(conflicts: 4)

        assert result.success?
        assert_equal 5, @schools.attempts.size
        assert_equal 5, @schools.attempts.map { it[1] }.uniq.size
        assert_equal @schools.attempts.last[1], result.value.school_code
        assert_equal 1, @audit.events.size
      end

      test "au-delà de cinq refus : :conflict, rien n'est tracé" do
        result = regenerate(conflicts: 5)

        assert_equal :conflict, result.code
        assert_equal RegenerateSchoolCode::ATTEMPTS, @schools.attempts.size
        assert_equal "k7m4qz", @schools.stored(31).school_code
        assert_empty @audit.events
      end

      test "CE-08: hors de l'équipe, refusé avant toute lecture" do
        teacher = Entities::Identity::Actor.new(user_id: 9, role: :teacher, school_id: 31)

        assert_equal :forbidden, regenerate(actor: teacher).code
        assert_equal :forbidden, regenerate(actor: nil).code
        assert_empty @schools.attempts
        assert_equal 0, @transaction.calls
      end

      test "un établissement inconnu : :not_found" do
        assert_equal :not_found, regenerate(public_id: "inconnu").code
        assert_empty @schools.attempts
      end
    end
  end
end
