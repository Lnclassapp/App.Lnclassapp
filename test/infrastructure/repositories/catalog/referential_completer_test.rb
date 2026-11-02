require "test_helper"

module Repositories
  module Catalog
    # ADR-0123 §8 : sur Develop, le référentiel manquant est créé ; rien d'existant n'est modifié ni supprimé.
    class ReferentialCompleterTest < ActiveSupport::TestCase
      def complete = ReferentialCompleter.new.complete

      test "on an empty referential it creates the base: levels, series, level/series pairs and materials, and says what" do
        created = complete

        assert_equal %w[6ème 5ème 4ème 3ème 2nde 1ère Tle], created.fetch(:levels)
        assert_equal %w[A C A1 A2 D], created.fetch(:series)
        assert_equal 10, created.fetch(:pairs).size
        assert_includes created.fetch(:pairs), "Tle C"
        assert_equal 6, created.fetch(:materials).size
        assert_equal [ 7, "second" ], Orm::Level.find_by!(slug: "tle").then { [ it.position, it.cycle ] }
        assert_equal Repositories::Catalog::ProgramOrder.rank("philosophie"), Orm::Material.find_by!(slug: "philosophie").position
        assert_empty created.fetch(:conflicts)
      end

      test "run again it creates nothing" do
        complete

        assert_no_difference [ "Orm::Level.count", "Orm::Series.count", "Orm::LevelSeries.count", "Orm::Material.count" ] do
          assert(complete.values_at(:levels, :series, :pairs, :materials, :conflicts).all?(&:empty?))
        end
      end

      test "an existing level, series or material is found by its slug and left exactly as it is" do
        level = create_level(name: "Tle", position: 2, cycle: "second")
        material = create_material(name: "Mathématiques", shortname: "Mat", category: "other")
        before = [ level.reload.attributes, material.reload.attributes ]

        created = complete

        assert_not_includes created.fetch(:levels), "Tle"
        assert_not_includes created.fetch(:materials), "Mathématiques"
        assert_equal before, [ level.reload.attributes, material.reload.attributes ]
        assert Orm::LevelSeries.exists?(level:, series: Orm::Series.find_by!(slug: "c"))
      end

      test "a position already held takes the next free one; a name or short name already held by another record is a conflict, never an error" do
        create_level(name: "Terminale", position: 6, cycle: "second")
        create_material(name: "Maths appliquées", shortname: "Maths", category: "science")

        created = complete

        assert_equal [ 6, 7, 8 ], [ "terminale", "1ere", "tle" ].map { Orm::Level.find_by!(slug: it).position }
        assert_includes created.fetch(:conflicts), "matière Mathématiques"
        assert_not Orm::Material.exists?(slug: "mathematiques")
        assert_equal 5, created.fetch(:materials).size
      end
      test "a level or a series whose name is held under another slug is a conflict, and its pairs are skipped" do
        create_level(name: "Terminale", cycle: "second").update_columns(name: "Tle")
        create_series(name: "X").update_columns(name: "C")

        created = complete

        assert_equal [ "niveau Tle", "série C" ], created.fetch(:conflicts)
        assert_not(created.fetch(:pairs).any? { it.start_with?("Tle") || it.end_with?(" C") })
        assert_includes created.fetch(:pairs), "1ère A1"
      end
    end
  end
end
