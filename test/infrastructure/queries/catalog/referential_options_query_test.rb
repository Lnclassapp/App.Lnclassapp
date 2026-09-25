require "test_helper"

module Queries
  module Catalog
    class ReferentialOptionsQueryTest < ActiveSupport::TestCase
      test "niveaux par position, séries permises par niveau triées par nom, matières par nom avec leur catégorie" do
        referential = seed_referential
        tle = referential[:levels].fetch("tle")

        row = ReferentialOptionsQuery.new.call

        assert_equal Orm::Level.order(:position).pluck(:name), row.levels.map(&:name)
        assert_equal ReferentialOptionsQuery::LevelRow.new(id: tle.id, slug: "tle", name: tle.name, cycle: "second"),
                     row.levels.find { it.slug == "tle" }
        assert_equal Orm::Series.joins(:level_series).where(level_series: { level_id: tle.id }).order(:name).pluck(:name),
                     row.series_by_level.fetch(tle.id).map(&:name)
        assert_not row.series_by_level.key?(referential[:levels].fetch("6eme").id)
        assert_equal Orm::Material.order(:name).pluck(:name), row.materials.map(&:name)
        assert row.materials.all? { %w[literature science other].include?(it.category) }
      end
    end
  end
end
