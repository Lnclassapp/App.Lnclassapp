require "test_helper"

module UseCases
  module School
    class UpdateSchoolTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      Drena = Entities::School::Drena
      SchoolEntity = Entities::School::School

      # `writes` trace chaque écriture reçue : la modification n'en fait qu'une, `update`, et aucune sur les classes.
      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        attr_reader :writes

        def initialize(*schools)
          @schools = schools.index_by(&:id)
          @writes = []
        end

        def find_by_public_id(public_id:) = @schools.values.find { it.public_id == public_id }&.dup

        def update(school:)
          @writes << :update
          taken = @schools.values.any? { it.id != school.id && it.drena_id == school.drena_id && it.name == school.name }
          return Shared::Result.failure(:conflict, errors: { name: [ :taken ] }) if taken

          @schools[school.id] = school
          Shared::Result.success(school)
        end

        def stored(public_id) = @schools.values.find { it.public_id == public_id }
      end

      class FakeDrenas
        include Ports::School::DrenaRepositoryPort

        def initialize(*drenas)
          @drenas = drenas
        end

        def find_by_public_id(public_id:) = @drenas.find { it.public_id == public_id }
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
          SchoolEntity.new(id: 32, public_id: "sch-lmc", drena_id: 1, name: "Lycée Moderne", sigle: nil,
                           school_type: "private", cycle: "both", status: "active")
        )
        @drenas = FakeDrenas.new(Drena.new(id: 1, public_id: "drn-abj1", slug: "abidjan-1", name: "Abidjan 1"),
                                 Drena.new(id: 2, public_id: "drn-abj2", slug: "abidjan-2", name: "Abidjan 2"))
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "field")
      end

      def update(public_id: "sch-lca", actor: @team, **attributes)
        dto = Dtos::School::SchoolInput.new(drena_public_id: "drn-abj1", name: "Lycée Classique", sigle: "LCA",
                                            school_type: "public", status: "active", cycle: "both", **attributes)
        UpdateSchool.new(schools: @schools, drenas: @drenas, audit_log: @audit, policy: Policies::School::ManageSchoolPolicy.new,
                         transaction: @transaction, clock: Clock.new(NOW)).call(actor:, public_id:, dto:)
      end

      test "modifie le nom, le sigle, la DRENA, le type, le statut et le cycle ; l'identité de l'école reste" do
        result = update(name: "Lycée Classique d'Abidjan", sigle: "LCAb", drena_public_id: "drn-abj2", school_type: "mixed",
                        status: "draft", cycle: "first")

        assert result.success?
        stored = @schools.stored("sch-lca")
        assert_equal [ 31, "sch-lca", 2, "Lycée Classique d'Abidjan", "LCAb", "mixed", "draft", "first" ],
                     [ stored.id, stored.public_id, stored.drena_id, stored.name, stored.sigle, stored.school_type, stored.status, stored.cycle ]
        assert_equal stored, result.value
        assert_equal 1, @transaction.calls
        assert_equal [ { action: "school.changed", actor_id: 7, at: NOW, subject_type: "School", subject_id: 31,
                         metadata: { change: "updated", public_id: "sch-lca",
                                     changes: { "drena_id" => [ 1, 2 ], "name" => [ "Lycée Classique", "Lycée Classique d'Abidjan" ],
                                                "sigle" => %w[LCA LCAb], "school_type" => %w[public mixed],
                                                "status" => %w[active draft], "cycle" => %w[both first] } } } ],
                     @audit.events
      end

      test "changer le cycle ou le type ne crée ni ne supprime de classe : seule l'école est écrite" do
        update(cycle: "first", school_type: "private")

        assert_equal [ :update ], @schools.writes
        assert_equal %i[schools drenas audit_log policy transaction clock],
                     UpdateSchool.instance_method(:initialize).parameters.map(&:last)
        assert_equal({ "school_type" => %w[public private], "cycle" => %w[both first] }, @audit.events.sole[:metadata][:changes])
      end

      test "hors de l'équipe : refus avant toute lecture, rien n'est écrit" do
        result = update(actor: Entities::Identity::Actor.new(user_id: 8, role: :teacher), name: "Autre")

        assert_equal :forbidden, result.code
        assert_empty @schools.writes
        assert_equal 0, @transaction.calls
      end

      test "un établissement inconnu : :not_found" do
        assert_equal :not_found, update(public_id: "new").code
        assert_empty @schools.writes
      end

      test "une saisie invalide : :invalid, l'école est intacte" do
        result = update(name: "", cycle: "second")

        assert_equal :invalid, result.code
        assert_equal %i[name cycle], result.errors.keys
        assert_equal "Lycée Classique", @schools.stored("sch-lca").name
        assert_equal 0, @transaction.calls
      end

      test "une DRENA inconnue : :invalid sur la DRENA, rien n'est écrit" do
        result = update(drena_public_id: "drn-inconnue")

        assert_equal [ :invalid, { drena_public_id: [ :inclusion ] } ], [ result.code, result.errors ]
        assert_empty @schools.writes
      end

      test "le nom d'une autre école de la même DRENA : :conflict sur le nom, sans journal" do
        result = update(name: "Lycée Moderne")

        assert_equal [ :conflict, { name: [ :taken ] } ], [ result.code, result.errors ]
        assert_equal "Lycée Classique", @schools.stored("sch-lca").name
        assert_empty @audit.events
      end
    end
  end
end
