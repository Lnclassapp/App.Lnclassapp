require "test_helper"

module UseCases
  module School
    class DeactivateSchoolTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      SchoolEntity = Entities::School::School

      # Aucune méthode de suppression : désactiver n'efface rien, ni l'école ni ses classes.
      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        attr_reader :updates

        def initialize(*schools, refuse: false)
          @schools = schools.index_by(&:id)
          @updates = 0
          @refuse = refuse
        end

        def find_by_public_id(public_id:) = @schools.values.find { it.public_id == public_id }&.dup

        def update(school:)
          @updates += 1
          return Shared::Result.failure(:conflict, errors: { name: [ :taken ] }) if @refuse

          @schools[school.id] = school
          Shared::Result.success(school)
        end

        def stored(public_id) = @schools.values.find { it.public_id == public_id }
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
        @schools = FakeSchools.new(
          SchoolEntity.new(id: 31, public_id: "sch-lca", drena_id: 1, name: "Lycée Classique", sigle: "LCA",
                           school_type: "public", cycle: "both", status: "active"),
          SchoolEntity.new(id: 32, public_id: "sch-old", drena_id: 1, name: "Ancien lycée", school_type: "private",
                           cycle: "both", status: "inactive")
        )
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "field")
      end

      def deactivate(public_id, actor: @team)
        DeactivateSchool.new(schools: @schools, audit_log: @audit, policy: Policies::School::ManageSchoolPolicy.new,
                             transaction: @transaction, clock: Clock.new(NOW)).call(actor:, public_id:)
      end

      test "passe l'école au statut inactive, sans rien toucher d'autre, et l'inscrit au journal" do
        result = deactivate("sch-lca")

        assert result.success?
        stored = @schools.stored("sch-lca")
        assert_equal [ "inactive", "Lycée Classique", "LCA", 1, "public", "both" ],
                     [ stored.status, stored.name, stored.sigle, stored.drena_id, stored.school_type, stored.cycle ]
        assert_not stored.active?
        assert_equal stored, result.value
        assert_equal 1, @transaction.calls
        assert_equal [ { action: "school.changed", actor_id: 7, at: NOW, subject_type: "School", subject_id: 31,
                         metadata: { change: "deactivated", public_id: "sch-lca" } } ], @audit.events
      end

      test "une école déjà inactive : succès sans écriture ni journal" do
        result = deactivate("sch-old")

        assert result.success?
        assert_equal "inactive", result.value.status
        assert_equal 0, @schools.updates
        assert_empty @audit.events
      end

      test "une écriture refusée par le dépôt remonte telle quelle, sans journal" do
        @schools = FakeSchools.new(SchoolEntity.new(id: 31, public_id: "sch-lca", drena_id: 1, name: "Lycée Classique",
                                                    school_type: "public", cycle: "both", status: "active"), refuse: true)

        assert_equal :conflict, deactivate("sch-lca").code
        assert_empty @audit.events
      end

      test "hors de l'équipe : refus, l'école reste active" do
        result = deactivate("sch-lca", actor: Entities::Identity::Actor.new(user_id: 8, role: :school_admin, school_id: 31))

        assert_equal :forbidden, result.code
        assert_equal "active", @schools.stored("sch-lca").status
        assert_equal 0, @transaction.calls
      end

      test "un établissement inconnu : :not_found" do
        assert_equal :not_found, deactivate("sch-inconnue").code
        assert_equal 0, @schools.updates
      end
    end
  end
end
