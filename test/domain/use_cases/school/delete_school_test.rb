require "test_helper"

module UseCases
  module School
    class DeleteSchoolTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      SchoolEntity = Entities::School::School

      # `referenced` : ids d'écoles dont une classe a un élève, un enseignant ou une assignation.
      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        attr_reader :schools

        def initialize(schools, referenced: [])
          @schools = schools
          @referenced = referenced
        end

        def find_by_public_id(public_id:) = @schools.find { it.public_id == public_id }

        def delete_if_unreferenced(id:)
          return Shared::Result.failure(:conflict, errors: { base: [ :referenced ] }) if @referenced.include?(id)

          @schools.reject! { it.id == id }
          Shared::Result.success
        end
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
          [ SchoolEntity.new(id: 31, public_id: "sch-vide", drena_id: 1, name: "Lycée sans élève", school_type: "public",
                             cycle: "both", status: "active"),
            SchoolEntity.new(id: 32, public_id: "sch-used", drena_id: 1, name: "Lycée Classique", school_type: "public",
                             cycle: "both", status: "active") ],
          referenced: [ 32 ]
        )
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "admin")
      end

      def delete(public_id, actor: @team)
        DeleteSchool.new(schools: @schools, audit_log: @audit, policy: Policies::School::ManageSchoolPolicy.new,
                         transaction: @transaction, clock: Clock.new(NOW)).call(actor:, public_id:)
      end

      test "supprime une école inutilisée, ses classes avec elle, et l'inscrit au journal" do
        result = delete("sch-vide")

        assert result.success?
        assert_equal %w[sch-used], @schools.schools.map(&:public_id)
        assert_equal 1, @transaction.calls
        assert_equal [ { action: "school.changed", actor_id: 7, at: NOW, subject_type: "School", subject_id: 31,
                         metadata: { change: "deleted", public_id: "sch-vide", name: "Lycée sans élève" } } ], @audit.events
      end

      test "une école utilisée : :conflict avec la raison, rien n'est supprimé ni journalisé" do
        result = delete("sch-used")

        assert_equal [ :conflict, { base: [ :referenced ] } ], [ result.code, result.errors ]
        assert_equal %w[sch-vide sch-used], @schools.schools.map(&:public_id)
        assert_empty @audit.events
      end

      test "hors de l'équipe : refus, rien n'est supprimé" do
        result = delete("sch-vide", actor: Entities::Identity::Actor.new(user_id: 8, role: :student))

        assert_equal :forbidden, result.code
        assert_equal 2, @schools.schools.size
        assert_equal 0, @transaction.calls
      end

      test "un établissement inconnu : :not_found" do
        assert_equal :not_found, delete("sch-inconnue").code
        assert_equal 0, @transaction.calls
      end
    end
  end
end
