require "test_helper"

module Entities
  module Catalog
    class LevelTest < ActiveSupport::TestCase
      def build(**overrides) = Level.new(id: 1, slug: "tle", name: " Tle ", position: 6, cycle: "second", **overrides)

      test "un niveau complet est valide" do
        assert build.valid?
        assert_equal "Tle", build.name
        assert_not build.first_cycle?
        assert build(cycle: "first").first_cycle?
      end

      test "nom obligatoire et borné, position entière, cycle fermé" do
        assert build(name: nil).invalid?
        assert build(name: "a" * 21).invalid?
        assert build(position: 1.5).invalid?
        assert build(position: -1).invalid?
        assert build(cycle: "both").invalid?
      end

      test "les slugs figés de la génération des classes" do
        assert_equal %w[6eme 5eme 4eme 3eme 2nde 1ere tle], Level::SLUGS
        assert_equal %w[a a1 a2 c d], Series::SLUGS
      end
    end
  end
end
