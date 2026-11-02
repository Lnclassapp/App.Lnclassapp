require "test_helper"

module Entities
  module Catalog
    # ADR-0123 §8 : le référentiel de base, le même que celui des semis de développement (ADR-0034).
    class BaseReferentialTest < ActiveSupport::TestCase
      test "seven levels in program order with their cycle, the series of the lycée and six materials" do
        assert_equal [ [ "6ème", "first", 1 ], [ "5ème", "first", 2 ], [ "4ème", "first", 3 ], [ "3ème", "first", 4 ],
                       [ "2nde", "second", 5 ], [ "1ère", "second", 6 ], [ "Tle", "second", 7 ] ],
                     BaseReferential::LEVELS.map { [ it.name, it.cycle, it.position ] }
        assert_equal({ "2nde" => %w[A C], "1ère" => %w[A1 A2 C D], "Tle" => %w[A1 A2 C D] }, BaseReferential::SERIES_BY_LEVEL)
        assert_equal %w[Mathématiques Physique-Chimie SVT Français Histoire-Géographie Philosophie], BaseReferential::MATERIALS.map(&:name)
        assert_equal [ "Maths", "science" ], BaseReferential::MATERIALS.first.then { [ it.shortname, it.category ] }
      end
    end
  end
end
