require "test_helper"

module UseCases
  module Identity
    # EPM-04 to EPM-10 (ADR-0103 §4.4, UDR-0125 §3.3): the teacher replaces, as a whole, the list of his subjects in his
    # current school; 1 to 3, known subjects only; an identical list writes nothing; each change is audited.
    class UpdateTeacherMaterialsTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 16, 9)
      Clock = Data.define(:now)
      Material = Entities::Catalog::Material

      class FakeTaxonomy
        include Ports::Catalog::TaxonomyRepositoryPort

        attr_reader :lookups

        def initialize(*materials)
          @materials = materials
          @lookups = []
        end

        def find_material(slug:)
          @lookups << slug
          @materials.find { it.slug == slug }
        end
      end

      setup do
        @taxonomy = FakeTaxonomy.new(Material.new(id: 5, slug: "physique-chimie", name: "Physique-Chimie", shortname: "PC", category: "science"),
                                     Material.new(id: 6, slug: "svt", name: "SVT", shortname: "SVT", category: "science"),
                                     Material.new(id: 7, slug: "mathematiques", name: "Mathématiques", shortname: "Maths", category: "science"),
                                     Material.new(id: 8, slug: "francais", name: "Français", shortname: "Fr", category: "literature"))
        @materials = FakeTeacherMaterials.new({ [ 50, 31 ] => [ 5, 6 ], [ 50, 32 ] => [ 6 ] })
        @audit = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @teacher = Entities::Identity::Actor.new(user_id: 50, role: :teacher, school_id: 31)
      end

      def update(*slugs, actor: @teacher)
        UpdateTeacherMaterials.new(teacher_materials: @materials, taxonomy: @taxonomy, audit_log: @audit, transaction: @transaction,
                                   policy: Policies::Identity::ManageOwnMaterialsPolicy.new, clock: Clock.new(NOW))
                              .call(actor:, dto: Dtos::Identity::TeacherMaterialsInput.new(material_slugs: slugs), ip: "1.2.3.4")
      end

      def assert_nothing_written
        assert_empty @materials.calls
        assert_empty @audit.events
        assert_equal 0, @transaction.calls
      end

      test "EPM-04: a third subject is added after the others, in the current school only, and audited" do
        assert update("physique-chimie", "svt", "mathematiques").success?

        assert_equal [ [ :replace, 50, 31, [ 5, 6, 7 ], NOW ] ], @materials.calls
        assert_equal [ 6 ], @materials.material_ids_for(teacher_id: 50, school_id: 32), "sa liste de l'autre établissement ne bouge pas"
        assert_equal [ { action: "profile.materials_changed", actor_id: 50, at: NOW, subject_type: "User", subject_id: 50,
                         metadata: { school_id: 31, from: [ 5, 6 ], to: [ 5, 6, 7 ] }, ip: "1.2.3.4" } ], @audit.events
        assert_equal 1, @transaction.calls
      end

      test "EPM-05: no subject is refused as blank, nothing is written" do
        result = update

        assert_equal [ :invalid, { material_slugs: [ :blank ] } ], [ result.code, result.errors ]
        assert_nothing_written
      end

      test "EPM-05: four subjects are refused as too many, before any lookup" do
        result = update("physique-chimie", "svt", "mathematiques", "francais")

        assert_equal [ :invalid, { material_slugs: [ :too_many ] } ], [ result.code, result.errors ]
        assert_empty @taxonomy.lookups
        assert_nothing_written
      end

      test "a subject deleted meanwhile, or forged, is refused as unknown, nothing is written" do
        result = update("svt", "latin")

        assert_equal [ :invalid, { material_slugs: [ :inclusion ] } ], [ result.code, result.errors ]
        assert_nothing_written
      end

      test "the same list writes nothing and succeeds, without audit" do
        assert update("physique-chimie", "svt").success?
        assert_nothing_written
      end

      test "EPM-08 to EPM-10: a student, a direction, the team and a teacher without school are refused" do
        [ Entities::Identity::Actor.new(user_id: 2, role: :student),
          Entities::Identity::Actor.new(user_id: 3, role: :school_admin, school_id: 31),
          Entities::Identity::Actor.new(user_id: 4, role: :team, team_role: "admin"),
          Entities::Identity::Actor.new(user_id: 50, role: :teacher) ].each do |actor|
          assert_equal :forbidden, update("svt", actor:).code, actor.role
        end
        assert_empty @taxonomy.lookups
        assert_nothing_written
      end

      test "the form keeps strings in the slug format only, without duplicate, four at most" do
        dto = Dtos::Identity::TeacherMaterialsInput.new(material_slugs: [ "svt", "", "svt", { "a" => "b" }, "SVT!", "pc", "a", "b", "c" ])

        assert_equal %w[svt pc a b], dto.material_slugs
        assert_equal [], Dtos::Identity::TeacherMaterialsInput.new(material_slugs: nil).material_slugs
      end
    end
  end
end
