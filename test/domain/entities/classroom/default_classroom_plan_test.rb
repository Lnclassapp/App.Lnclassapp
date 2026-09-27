require "test_helper"
require_relative "../../../support/domain/taxonomy_fixture"

module Entities
  module Classroom
    class DefaultClassroomPlanTest < ActiveSupport::TestCase
      School = Data.define(:school_type, :cycle)

      def rows_for(school_type, cycle = "both", lookup: Catalog::TaxonomyFixture.lookup)
        DefaultClassroomPlan.rows_for(school: School.new(school_type:, cycle:), lookup:)
      end

      test "un lycée public reçoit 77 classes avec le référentiel de développement" do
        generation = rows_for("public")

        assert_equal 77, generation.rows.size
        assert_equal({ levels: [], series: [] }, generation.skipped)
        assert_equal 6, generation.rows.count { it[:name].start_with?("Tle D ") }
        assert_equal 12, generation.rows.count { it[:name].start_with?("2nde ") }
      end

      test "un établissement privé ou mixte suit le barème privé : 38 classes" do
        assert_equal 38, rows_for("private").rows.size
        assert_equal 38, rows_for("mixed").rows.size
        assert_same DefaultClassroomPlan::PLAN["private"], DefaultClassroomPlan.for("mixed")
      end

      test "un collège public reçoit 28 classes, aucune de second cycle" do
        generation = rows_for("public", "first")

        assert_equal 28, generation.rows.size
        assert generation.rows.all? { it[:series_id].nil? && it[:level_id] <= 4 }
      end

      test "noms toujours espacés, rattachés au niveau et à la série" do
        rows = rows_for("public").rows

        assert_includes rows, { name: "6ème 1", level_id: 1, series_id: nil }
        assert_includes rows, { name: "Tle D 3", level_id: 7, series_id: 105 }
        assert_includes rows, { name: "1ère A1 2", level_id: 6, series_id: 102 }
        assert_equal rows.size, rows.map { it[:name] }.uniq.size
      end

      test "un niveau, un niveau sans série ou un couple absent est sauté et compté" do
        levels = Catalog::TaxonomyFixture::LEVELS.reject { |(_, slug)| slug == "5eme" }
        pairs = { "2nde" => %w[a c], "tle" => %w[a1 a2 d] }
        generation = rows_for("public", lookup: Catalog::TaxonomyFixture.lookup(levels:, pairs:))

        assert_equal({ levels: %w[5eme 1ere], series: %w[tle/c] }, generation.skipped)
        assert_equal 77 - 4 - 24 - 2, generation.rows.size
      end
    end
  end
end
